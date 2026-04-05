import 'dart:io';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llamadart/llamadart.dart';
import 'package:system_info2/system_info2.dart';

import '../config/ai_constants.dart';
import '../models/objectbox_models.dart';
import 'storage_service.dart';

enum AiDeviceTier { low, mid, high, ultra }

class AiDeviceProfile {
  final int totalRamGb;
  final int freeRamGb;
  final int cpuCores;
  final AiDeviceTier tier;

  const AiDeviceProfile({
    required this.totalRamGb,
    required this.freeRamGb,
    required this.cpuCores,
    required this.tier,
  });
}

class AiRuntimePolicy {
  final AiDeviceProfile profile;
  final ModelParams modelParams;
  final GenerationParams generationParams;
  final bool shouldPauseEmbedding;
  final String explanation;

  const AiRuntimePolicy({
    required this.profile,
    required this.modelParams,
    required this.generationParams,
    required this.shouldPauseEmbedding,
    required this.explanation,
  });
}

class AiRuntimePolicyService {
  final StorageService _storage;
  final Battery _battery = Battery();

  AiRuntimePolicyService(this._storage);

  AiDeviceProfile getDeviceProfile() {
    final totalRamGb =
        (SysInfo.getTotalPhysicalMemory() / (1024 * 1024 * 1024)).round();
    final freeRamGb =
        (SysInfo.getFreePhysicalMemory() / (1024 * 1024 * 1024)).round();
    final cpuCores = Platform.numberOfProcessors;

    final tier = switch (totalRamGb) {
      <= 4 => AiDeviceTier.low,
      <= 6 => AiDeviceTier.mid,
      <= 8 => AiDeviceTier.high,
      _ => AiDeviceTier.ultra,
    };

    return AiDeviceProfile(
      totalRamGb: totalRamGb,
      freeRamGb: freeRamGb,
      cpuCores: cpuCores,
      tier: tier,
    );
  }

  Future<AiRuntimePolicy> buildPolicy({required bool forEmbedding}) async {
    final config = await _storage.getAiRuntimeConfig();
    final profile = getDeviceProfile();

    final lowPowerPause = await _shouldPauseEmbedding(config);

    final autoContext = _defaultContextSize(profile.tier, forEmbedding);
    final autoThreads = _defaultThreads(profile.cpuCores, profile.tier);

    final contextSize = config.forcedContextSize > 0
        ? config.forcedContextSize
        : (config.autoPolicy
            ? autoContext
            : (forEmbedding ? 1024 : AiConstants.chatContextTokens));
    final threads = config.forcedThreads > 0
        ? config.forcedThreads
        : (config.autoPolicy
            ? autoThreads
            : math.max(2, profile.cpuCores ~/ 2));

    final backend = config.autoPolicy
        ? _resolveBackendPreference(config.backendIndex, profile.tier)
        : _resolveManualBackendPreference(config.backendIndex);
    final gpuLayers = config.forcedGpuLayers >= 0
        ? config.forcedGpuLayers
        : _defaultGpuLayers(backend, profile.tier);

    final batchSize = math.min(contextSize, _defaultBatchSize(profile.tier));
    final microBatch = math.min(batchSize, _defaultMicroBatch(profile.tier));

    final modelParams = ModelParams(
      contextSize: contextSize,
      preferredBackend: backend,
      gpuLayers: gpuLayers,
      numberOfThreads: threads,
      numberOfThreadsBatch: threads,
      batchSize: batchSize,
      microBatchSize: microBatch,
      maxParallelSequences: forEmbedding ? 2 : 1,
    );

    final generationParams = GenerationParams(
      maxTokens: config.maxGenerationTokens > 0
          ? config.maxGenerationTokens
          : AiConstants.chatMaxOutputTokens,
      temp: 0.6,
      topK: 32,
      topP: 0.9,
      penalty: 1.05,
      streamBatchTokenThreshold: 6,
      streamBatchByteThreshold: 384,
    );

    final explanation =
        'tier=${profile.tier.name}, ram=${profile.totalRamGb}GB, '
        'backend=${backend.name}, ctx=$contextSize, threads=$threads, '
        'gpuLayers=$gpuLayers, lowPowerPause=$lowPowerPause';

    return AiRuntimePolicy(
      profile: profile,
      modelParams: modelParams,
      generationParams: generationParams,
      shouldPauseEmbedding: forEmbedding && lowPowerPause,
      explanation: explanation,
    );
  }

  Future<bool> _shouldPauseEmbedding(ObjectBoxAiRuntimeConfig config) async {
    if (!config.pauseEmbeddingOnLowBattery) return false;
    try {
      final state = await _battery.batteryState;
      if (state == BatteryState.charging || state == BatteryState.full) {
        return false;
      }
      final level = await _battery.batteryLevel;
      return level <= config.lowBatteryThreshold;
    } catch (_) {
      // Battery API may fail on some devices/emulators.
      return false;
    }
  }

  int _defaultContextSize(AiDeviceTier tier, bool forEmbedding) {
    if (forEmbedding) {
      return switch (tier) {
        AiDeviceTier.low => 768,
        AiDeviceTier.mid => 1024,
        AiDeviceTier.high => 1536,
        AiDeviceTier.ultra => 2048,
      };
    }
    return switch (tier) {
      AiDeviceTier.low => 1024,
      AiDeviceTier.mid => 1536,
      AiDeviceTier.high => 2048,
      AiDeviceTier.ultra => AiConstants.chatContextTokens,
    };
  }

  int _defaultThreads(int cpuCores, AiDeviceTier tier) {
    final reserve = switch (tier) {
      AiDeviceTier.low => 2,
      AiDeviceTier.mid => 2,
      AiDeviceTier.high => 1,
      AiDeviceTier.ultra => 1,
    };
    return math.max(2, cpuCores - reserve);
  }

  GpuBackend _resolveBackendPreference(int backendIndex, AiDeviceTier tier) {
    if (backendIndex == 1) return GpuBackend.cpu;
    if (backendIndex == 2) return GpuBackend.vulkan;
    return switch (tier) {
      AiDeviceTier.low => GpuBackend.cpu,
      AiDeviceTier.mid => GpuBackend.cpu,
      AiDeviceTier.high => GpuBackend.auto,
      AiDeviceTier.ultra => GpuBackend.auto,
    };
  }

  GpuBackend _resolveManualBackendPreference(int backendIndex) {
    if (backendIndex == 2) return GpuBackend.vulkan;
    return GpuBackend.cpu;
  }

  int _defaultGpuLayers(GpuBackend backend, AiDeviceTier tier) {
    if (backend == GpuBackend.cpu) return 0;
    return switch (tier) {
      AiDeviceTier.low => 0,
      AiDeviceTier.mid => 8,
      AiDeviceTier.high => 20,
      AiDeviceTier.ultra => 32,
    };
  }

  int _defaultBatchSize(AiDeviceTier tier) {
    return switch (tier) {
      AiDeviceTier.low => 128,
      AiDeviceTier.mid => 192,
      AiDeviceTier.high => 256,
      AiDeviceTier.ultra => 320,
    };
  }

  int _defaultMicroBatch(AiDeviceTier tier) {
    return switch (tier) {
      AiDeviceTier.low => 64,
      AiDeviceTier.mid => 96,
      AiDeviceTier.high => 128,
      AiDeviceTier.ultra => 160,
    };
  }
}

final aiRuntimePolicyServiceProvider = Provider<AiRuntimePolicyService>((ref) {
  return AiRuntimePolicyService(ref.read(storageServiceProvider));
});
