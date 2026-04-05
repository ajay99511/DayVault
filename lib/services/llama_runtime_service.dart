import 'dart:async';
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import '../config/ai_constants.dart';
import 'ai_runtime_policy_service.dart';

class LlamaRuntimeDiagnostics {
  final bool isLoaded;
  final String? modelPath;
  final String? backendName;
  final int? resolvedGpuLayers;
  final String? policySignature;

  const LlamaRuntimeDiagnostics({
    required this.isLoaded,
    this.modelPath,
    this.backendName,
    this.resolvedGpuLayers,
    this.policySignature,
  });
}

/// Single-flight Llama runtime manager.
///
/// Uses one engine instance at a time to avoid peak RAM spikes from
/// simultaneously loaded embedding + generation models.
class LlamaRuntimeService {
  LlamaRuntimeService._();
  static final LlamaRuntimeService instance = LlamaRuntimeService._();

  LlamaEngine? _engine;
  String? _loadedModelPath;
  String? _loadedPolicySignature;
  Timer? _idleDisposeTimer;
  Future<void> _lock = Future.value();
  int _generationEpoch = 0;

  Future<Directory> getModelDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<bool> hasAnyModel() async {
    final modelDir = await getModelDirectory();
    if (!await modelDir.exists()) return false;
    final models = modelDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.gguf'))
        .toList();
    return models.isNotEmpty;
  }

  Future<void> ensureModelLoaded({
    required String modelPath,
    required AiRuntimePolicy policy,
  }) async {
    return _exclusive(() async {
      final file = File(modelPath);
      if (!await file.exists()) {
        throw StateError('Model file not found at: $modelPath');
      }

      final signature = _policySignature(policy);
      if (_engine != null &&
          _loadedModelPath == modelPath &&
          _loadedPolicySignature == signature &&
          _engine!.isReady) {
        _touchIdleTimer();
        return;
      }

      await _disposeInternal();

      var engine = LlamaEngine(LlamaBackend());
      try {
        await engine.loadModel(modelPath, modelParams: policy.modelParams);
      } catch (_) {
        // Safety fallback if GPU/auto path fails on device drivers.
        await engine.dispose();
        engine = LlamaEngine(LlamaBackend());
        final fallback = policy.modelParams.copyWith(
          preferredBackend: GpuBackend.cpu,
          gpuLayers: 0,
        );
        await engine.loadModel(modelPath, modelParams: fallback);
      }

      _engine = engine;
      _loadedModelPath = modelPath;
      _loadedPolicySignature = signature;
      _touchIdleTimer();
    });
  }

  Future<List<double>> embed(
    String text, {
    required String modelPath,
    required AiRuntimePolicy policy,
  }) async {
    await ensureModelLoaded(modelPath: modelPath, policy: policy);
    final vector = await _engine!.embed(text);
    _touchIdleTimer();
    return vector;
  }

  Stream<String> generate(
    String prompt, {
    required String modelPath,
    required AiRuntimePolicy policy,
    GenerationParams? params,
  }) async* {
    await ensureModelLoaded(modelPath: modelPath, policy: policy);

    final requestEpoch = ++_generationEpoch;
    final generationParams = params ?? policy.generationParams;

    try {
      await for (final token
          in _engine!.generate(prompt, params: generationParams)) {
        if (requestEpoch != _generationEpoch) {
          break;
        }
        yield token;
      }
    } finally {
      _touchIdleTimer();
    }
  }

  void cancelGeneration() {
    _generationEpoch++;
    try {
      _engine?.cancelGeneration();
    } catch (_) {
      // Best-effort cancel; backend may already be idle/disposed.
    }
  }

  Future<LlamaRuntimeDiagnostics> getDiagnostics() async {
    if (_engine == null || !_engine!.isReady) {
      return const LlamaRuntimeDiagnostics(isLoaded: false);
    }
    String? backend;
    int? gpuLayers;
    try {
      backend = await _engine!.getBackendName();
      gpuLayers = await _engine!.getResolvedGpuLayers();
    } catch (_) {
      // Best-effort diagnostics only.
    }
    return LlamaRuntimeDiagnostics(
      isLoaded: true,
      modelPath: _loadedModelPath,
      backendName: backend,
      resolvedGpuLayers: gpuLayers,
      policySignature: _loadedPolicySignature,
    );
  }

  Future<void> dispose() async {
    await _exclusive(_disposeInternal);
  }

  Future<void> _disposeInternal() async {
    _idleDisposeTimer?.cancel();
    _idleDisposeTimer = null;
    _generationEpoch++;

    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _loadedModelPath = null;
      _loadedPolicySignature = null;
    }
  }

  void _touchIdleTimer() {
    _idleDisposeTimer?.cancel();
    _idleDisposeTimer = Timer(
      AiConstants.modelIdleDisposeAfter,
      () => dispose(),
    );
  }

  String _policySignature(AiRuntimePolicy policy) {
    final p = policy.modelParams;
    return [
      p.contextSize,
      p.gpuLayers,
      p.preferredBackend.name,
      p.numberOfThreads,
      p.numberOfThreadsBatch,
      p.batchSize,
      p.microBatchSize,
      p.maxParallelSequences,
    ].join(':');
  }

  Future<void> _exclusive(Future<void> Function() action) {
    final run = _lock.then(
      (_) => action(),
      onError: (_) => action(),
    );
    _lock = run.catchError((_) {
      // Keep lock chain alive after failures.
    });
    return run;
  }
}
