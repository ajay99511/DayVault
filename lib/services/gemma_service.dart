import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_info2/system_info2.dart';

/// Available Gemma model presets the user can choose from.
class GemmaModelPreset {
  final String id;
  final String displayName;
  final String description;
  final String downloadUrl;
  final ModelType modelType;
  final int approxSizeMb;

  const GemmaModelPreset({
    required this.id,
    required this.displayName,
    required this.description,
    required this.downloadUrl,
    required this.modelType,
    required this.approxSizeMb,
  });
}

/// Status of the Gemma engine.
enum GemmaEngineStatus {
  uninitialized,
  noModel,
  downloading,
  ready,
  error,
}

/// Holds current state of the Gemma service.
class GemmaState {
  final GemmaEngineStatus status;
  final double downloadProgress;
  final String? error;

  const GemmaState({
    this.status = GemmaEngineStatus.uninitialized,
    this.downloadProgress = 0.0,
    this.error,
  });

  GemmaState copyWith({
    GemmaEngineStatus? status,
    double? downloadProgress,
    String? error,
  }) {
    return GemmaState(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error,
    );
  }
}

/// Available model presets.
const List<GemmaModelPreset> _presets = [
  GemmaModelPreset(
    id: 'gemma3-1b',
    displayName: 'Gemma 3 — 1B',
    description: 'Good quality, fits most phones (~500 MB)',
    downloadUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1B-it-int4.task',
    modelType: ModelType.gemmaIt,
    approxSizeMb: 500,
  ),
  GemmaModelPreset(
    id: 'gemma3-270m',
    displayName: 'Gemma 3 — 270M (Lite)',
    description: 'Lightweight, works on low-end phones (~150 MB)',
    downloadUrl:
        'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma-3-270m-it-int4.task',
    modelType: ModelType.gemmaIt,
    approxSizeMb: 150,
  ),
];

/// Wraps [flutter_gemma] for DayVault. Handles model install, lifecycle, and
/// text generation against a locally installed Gemma model.
class GemmaService extends Notifier<GemmaState> {
  CancelToken? _downloadCancelToken;

  static List<GemmaModelPreset> get presets => _presets;

  /// Minimum free RAM required to load a model (in MB)
  static const int _minFreeRamMb = 512;

  @override
  GemmaState build() {
    return const GemmaState();
  }

  /// Check if device has enough RAM to load the model
  Future<bool> _hasEnoughRam(int requiredMb) async {
    try {
      final freeRamMb = (SysInfo.getFreePhysicalMemory() / (1024 * 1024)).round();
      final hasEnough = freeRamMb >= requiredMb;
      if (!hasEnough) {
        debugPrint(
          'Insufficient RAM for Gemma model: '
          '${freeRamMb}MB free, need ${requiredMb}MB',
        );
      }
      return hasEnough;
    } catch (e) {
      debugPrint('RAM check failed: $e');
      return true; // Default to allowing if check fails
    }
  }

  /// Check if any model is installed and update state accordingly.
  Future<void> refreshStatus() async {
    try {
      final isInstalled = FlutterGemma.hasActiveModel();
      state = state.copyWith(
        status:
            isInstalled ? GemmaEngineStatus.ready : GemmaEngineStatus.noModel,
      );
    } catch (e) {
      state = state.copyWith(
        status: GemmaEngineStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Download a model from a preset with progress.
  Future<void> downloadModel(GemmaModelPreset preset,
      {String? hfToken}) async {
    // Check RAM before downloading
    final requiredRam = preset.approxSizeMb + _minFreeRamMb; // Model + runtime buffer
    final hasRam = await _hasEnoughRam(requiredRam);
    if (!hasRam) {
      state = state.copyWith(
        status: GemmaEngineStatus.error,
        error: 'Insufficient RAM. Need ~${requiredRam}MB free. '
               'Try the 270M Lite model instead.',
      );
      return;
    }

    _downloadCancelToken = CancelToken();
    state = state.copyWith(
      status: GemmaEngineStatus.downloading,
      downloadProgress: 0.0,
    );

    try {
      final future = FlutterGemma.installModel(
        modelType: preset.modelType,
      )
          .fromNetwork(
            preset.downloadUrl,
            token: hfToken,
          )
          .withCancelToken(_downloadCancelToken!)
          .withProgress((progress) {
            state = state.copyWith(
              downloadProgress: progress / 100.0,
            );
          })
          .install();
          
      await future;

      state = state.copyWith(
        status: GemmaEngineStatus.ready,
        downloadProgress: 1.0,
      );
    } catch (e) {
      if (CancelToken.isCancel(e)) {
        state = state.copyWith(status: GemmaEngineStatus.noModel);
      } else {
        state = state.copyWith(
          status: GemmaEngineStatus.error,
          error: 'Download failed: $e',
        );
      }
    }
    _downloadCancelToken = null;
  }

  /// Cancel an in-progress download.
  void cancelDownload() {
    _downloadCancelToken?.cancel('User cancelled download');
  }

  /// Delete the installed model and free storage.
  Future<void> deleteModel({String? modelId}) async {
    try {
      final installedModels = await FlutterGemma.listInstalledModels();
      
      if (modelId != null) {
        // Delete specific model
        await FlutterGemma.uninstallModel(modelId);
      } else if (installedModels.length == 1) {
        // Only one model installed, delete it
        await FlutterGemma.uninstallModel(installedModels.first);
      } else if (installedModels.isEmpty) {
        // No models to delete
        state = state.copyWith(status: GemmaEngineStatus.noModel);
        return;
      } else {
        // Multiple models — require explicit modelId
        throw StateError(
          'Multiple models installed (${installedModels.length}). '
          'Specify which model to delete using deleteModel(modelId: ...)',
        );
      }

      state = state.copyWith(status: GemmaEngineStatus.noModel);
    } catch (e) {
      state = state.copyWith(
        status: GemmaEngineStatus.error,
        error: 'Delete failed: $e',
      );
    }
  }

  /// Generate a response using the installed Gemma model.
  /// Returns a stream of tokens for real-time display.
  Stream<String> generate(
    String prompt, {
    int maxTokens = 1024,
    String? systemInstruction,
    Duration timeout = const Duration(minutes: 5), // Default 5 min timeout
  }) async* {
    if (state.status != GemmaEngineStatus.ready) {
      throw StateError('Gemma model is not installed. Download one first.');
    }

    // RAM check before generation
    final hasRam = await _hasEnoughRam(_minFreeRamMb);
    if (!hasRam) {
      throw StateError(
        'Insufficient memory for AI generation. '
        'Close other apps and try again.',
      );
    }

    InferenceModel? model;
    InferenceChat? chat;
    try {
      model = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
      );

      chat = await model.createChat();

      // Inject system instruction if provided
      final contextMsg = systemInstruction != null
          ? '$systemInstruction\n\nUser: $prompt'
          : prompt;

      await chat.addQuery(Message.text(
        text: contextMsg,
        isUser: true,
      ));

      final responseStream = chat.generateChatResponseAsync();

      // Add timeout wrapper
      await for (final token in responseStream.timeout(timeout)) {
        if (token is TextResponse) {
          yield token.token;
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('Gemma generation timed out: $e');
      throw StateError(
        'AI generation timed out. Please try again with a shorter prompt.',
      );
    } catch (e) {
      debugPrint('Gemma generation error: $e');
      rethrow;
    } finally {
      // Close model to free resources
      try {
        await model?.close();
      } catch (_) {
        // Best-effort cleanup
      }
      // Let chat be garbage collected - flutter_gemma handles lifecycle
    }
  }

  /// Initialize flutter_gemma (call once per app lifecycle, from main.dart).
  static void initializeGlobal({String? huggingFaceToken}) {
    FlutterGemma.initialize(
      huggingFaceToken: huggingFaceToken,
      maxDownloadRetries: 5,
    );
  }
}

final gemmaServiceProvider = NotifierProvider<GemmaService, GemmaState>(() {
  return GemmaService();
});
