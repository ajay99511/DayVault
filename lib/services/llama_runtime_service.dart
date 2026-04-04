import 'dart:async';
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import '../config/ai_constants.dart';

/// Single-flight Llama runtime manager.
///
/// Uses one engine instance at a time to avoid peak RAM spikes from
/// simultaneously loaded embedding + generation models.
class LlamaRuntimeService {
  LlamaRuntimeService._();
  static final LlamaRuntimeService instance = LlamaRuntimeService._();

  LlamaEngine? _engine;
  String? _loadedModelPath;
  Timer? _idleDisposeTimer;
  Future<void> _lock = Future.value();

  Future<Directory> _getModelDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<String> getChatModelPath() async {
    final modelDir = await _getModelDir();
    return '${modelDir.path}/${AiConstants.chatModelId}.gguf';
  }

  Future<String> getEmbeddingModelPath() async {
    final modelDir = await _getModelDir();
    return '${modelDir.path}/${AiConstants.embeddingModelId}.gguf';
  }

  Future<bool> hasAnyModel() async {
    final chat = File(await getChatModelPath());
    final embed = File(await getEmbeddingModelPath());
    return await chat.exists() || await embed.exists();
  }

  Future<void> ensureModelLoaded({required bool forEmbedding}) async {
    return _exclusive(() async {
      final preferred = forEmbedding
          ? File(await getEmbeddingModelPath())
          : File(await getChatModelPath());
      final fallback = forEmbedding
          ? File(await getChatModelPath())
          : File(await getEmbeddingModelPath());

      final modelFile = await preferred.exists() ? preferred : fallback;
      if (!await modelFile.exists()) {
        throw StateError(
          'No local GGUF models found. Expected:\n'
          '- ${await getChatModelPath()}\n'
          '- ${await getEmbeddingModelPath()}',
        );
      }

      if (_engine != null && _loadedModelPath == modelFile.path) {
        _touchIdleTimer();
        return;
      }

      await _disposeInternal();
      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(modelFile.path);
      _loadedModelPath = modelFile.path;
      _touchIdleTimer();
    });
  }

  Future<List<double>> embed(String text) async {
    await ensureModelLoaded(forEmbedding: true);
    final vector = await _engine!.embed(text);
    _touchIdleTimer();
    return vector;
  }

  Stream<String> generate(
    String prompt, {
    int? maxOutputTokens,
  }) async* {
    await ensureModelLoaded(forEmbedding: false);

    await for (final token in _engine!.generate(prompt)) {
      yield token;
    }

    _touchIdleTimer();
  }

  Future<void> dispose() async {
    await _exclusive(_disposeInternal);
  }

  Future<void> _disposeInternal() async {
    _idleDisposeTimer?.cancel();
    _idleDisposeTimer = null;

    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _loadedModelPath = null;
    }
  }

  void _touchIdleTimer() {
    _idleDisposeTimer?.cancel();
    _idleDisposeTimer = Timer(
      AiConstants.modelIdleDisposeAfter,
      () => dispose(),
    );
  }

  Future<void> _exclusive(Future<void> Function() action) {
    _lock = _lock.then((_) => action());
    return _lock;
  }
}
