import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/objectbox_models.dart';
import 'llama_runtime_service.dart';
import 'rag_service.dart';
import 'storage_service.dart';

class AiModelImportResult {
  final bool success;
  final bool cancelled;
  final String message;
  final ObjectBoxAiModel? model;

  const AiModelImportResult({
    required this.success,
    required this.cancelled,
    required this.message,
    this.model,
  });
}

class AiModelRegistryService {
  final StorageService _storage;
  final LlamaRuntimeService _runtime = LlamaRuntimeService.instance;
  final RagService _ragService;

  AiModelRegistryService(this._storage, this._ragService);

  Future<List<ObjectBoxAiModel>> getModels({int? roleIndex}) {
    return _storage.getAiModels(roleIndex: roleIndex);
  }

  Future<ObjectBoxAiRuntimeConfig> getRuntimeConfig() {
    return _storage.getAiRuntimeConfig();
  }

  Future<void> saveRuntimeConfig(ObjectBoxAiRuntimeConfig config) {
    return _storage.saveAiRuntimeConfig(config);
  }

  Future<AiModelImportResult> pickAndImportModel({
    required int roleIndex,
  }) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
      allowMultiple: false,
      withData: false,
    );

    if (pick == null || pick.files.isEmpty) {
      return const AiModelImportResult(
        success: false,
        cancelled: true,
        message: 'Model import cancelled.',
      );
    }

    final file = pick.files.first;
    return importModel(
      roleIndex: roleIndex,
      sourcePath: file.path,
      sourceBytes: file.bytes,
      sourceName: file.name,
    );
  }

  Future<AiModelImportResult> importModel({
    required int roleIndex,
    String? sourcePath,
    Uint8List? sourceBytes,
    String? sourceName,
  }) async {
    try {
      if (sourcePath == null && sourceBytes == null) {
        return const AiModelImportResult(
          success: false,
          cancelled: false,
          message: 'No model file selected.',
        );
      }

      final fileName = sourceName ??
          (sourcePath != null
              ? sourcePath.split(Platform.pathSeparator).last
              : 'model.gguf');

      if (!fileName.toLowerCase().endsWith('.gguf')) {
        return const AiModelImportResult(
          success: false,
          cancelled: false,
          message: 'Invalid file type. Please select a .gguf model file.',
        );
      }

      final modelDir = await _runtime.getModelDirectory();
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final analysis = await _analyzeSource(
        sourcePath: sourcePath,
        sourceBytes: sourceBytes,
      );
      if (!analysis.isValidGguf) {
        return const AiModelImportResult(
          success: false,
          cancelled: false,
          message: 'The selected file is not a valid GGUF model.',
        );
      }

      if (analysis.fileSizeBytes < (20 * 1024 * 1024)) {
        return const AiModelImportResult(
          success: false,
          cancelled: false,
          message: 'Model file looks too small to be valid.',
        );
      }

      final modelId = '${_rolePrefix(roleIndex)}_${analysis.sha256}';
      final existing = await _storage.getAiModelById(modelId);
      if (existing != null) {
        final existingFile = File(existing.filePath);
        if (!await existingFile.exists()) {
          // Stale metadata entry; remove and continue with fresh import.
          await _storage.deleteAiModel(modelId);
        } else {
          await _storage.setActiveAiModel(
              roleIndex: roleIndex, modelId: modelId);
          await _runtime.dispose();
          if (roleIndex == 1) {
            await _storage.enqueueReindexAllEntries();
            await _ragService.kickWorker();
          }
          return AiModelImportResult(
            success: true,
            cancelled: false,
            message: 'Model already imported. Activated existing copy.',
            model: existing,
          );
        }
      }

      final fileByPath = await _storage.getAiModels(roleIndex: roleIndex);
      final samePath =
          fileByPath.where((m) => m.filePath == sourcePath).toList();
      if (samePath.isNotEmpty) {
        // Prevent duplicate metadata rows pointing to the same source file.
        final preferred = samePath.first;
        await _storage.setActiveAiModel(
          roleIndex: roleIndex,
          modelId: preferred.modelId,
        );
        if (roleIndex == 1) {
          await _storage.enqueueReindexAllEntries();
          await _ragService.kickWorker();
        }
        await _runtime.dispose();
        return AiModelImportResult(
          success: true,
          cancelled: false,
          message: 'Model already tracked. Activated existing entry.',
          model: preferred,
        );
      }

      const ext = '.gguf';
      final baseName =
          '${_rolePrefix(roleIndex)}_${analysis.sha256.substring(0, 12)}';
      final finalPath =
          '${modelDir.path}${Platform.pathSeparator}$baseName$ext';
      final tempPath =
          '$finalPath.importing_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

      await _copyToTemp(
        tempPath: tempPath,
        sourcePath: sourcePath,
        sourceBytes: sourceBytes,
      );

      final targetFile = File(finalPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await File(tempPath).rename(finalPath);

      final now = DateTime.now();
      final model = await _storage.upsertAiModel(
        ObjectBoxAiModel()
          ..modelId = modelId
          ..roleIndex = roleIndex
          ..displayName = fileName
          ..filePath = finalPath
          ..checksum = analysis.sha256
          ..fileSizeBytes = analysis.fileSizeBytes
          ..isActive = true
          ..isUsable = true
          ..lastError = null
          ..importedAt = now
          ..updatedAt = now,
      );

      await _storage.setActiveAiModel(roleIndex: roleIndex, modelId: modelId);
      await _runtime.dispose();

      if (roleIndex == 1) {
        await _storage.enqueueReindexAllEntries();
        await _ragService.kickWorker();
      }

      return AiModelImportResult(
        success: true,
        cancelled: false,
        message: 'Model imported successfully.',
        model: model,
      );
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28) {
        return const AiModelImportResult(
          success: false,
          cancelled: false,
          message: 'Not enough storage space for this model.',
        );
      }
      return AiModelImportResult(
        success: false,
        cancelled: false,
        message: 'File operation failed: ${e.message}',
      );
    } catch (e) {
      return AiModelImportResult(
        success: false,
        cancelled: false,
        message: 'Model import failed: $e',
      );
    }
  }

  Future<void> activateModel({
    required int roleIndex,
    required String modelId,
  }) async {
    final model = await _storage.getAiModelById(modelId);
    if (model == null || model.roleIndex != roleIndex) {
      throw StateError('Selected model does not exist for this role.');
    }

    final file = File(model.filePath);
    if (!await file.exists()) {
      await _storage.markAiModelError(modelId, 'Model file not found on disk.');
      throw StateError('Model file is missing. Re-import the model.');
    }

    await _storage.setActiveAiModel(roleIndex: roleIndex, modelId: modelId);
    await _storage.markAiModelError(modelId, null);
    await _runtime.dispose();
    if (roleIndex == 1) {
      await _storage.enqueueReindexAllEntries();
      await _ragService.kickWorker();
    }
  }

  Future<void> deleteModel(String modelId) async {
    final existing = await _storage.getAiModelById(modelId);
    if (existing == null) return;

    final path = existing.filePath;
    final roleIndex = existing.roleIndex;
    final wasActive = existing.isActive;

    await _storage.deleteAiModel(modelId);

    // Keep file if any other model references the same path.
    final allModels = await _storage.getAiModels();
    final hasSamePathReference = allModels.any((m) => m.filePath == path);
    if (!hasSamePathReference) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (wasActive) {
      final remaining = await _storage.getAiModels(roleIndex: roleIndex);
      if (remaining.isNotEmpty) {
        await _storage.setActiveAiModel(
          roleIndex: roleIndex,
          modelId: remaining.first.modelId,
        );
        if (roleIndex == 1) {
          await _storage.enqueueReindexAllEntries();
          await _ragService.kickWorker();
        }
      }
      await _runtime.dispose();
    }
  }

  Future<void> _copyToTemp({
    required String tempPath,
    String? sourcePath,
    Uint8List? sourceBytes,
  }) async {
    final tempFile = File(tempPath);
    final parent = tempFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    if (sourcePath != null) {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw FileSystemException('Source file not found', sourcePath);
      }
      await source.copy(tempPath);
      return;
    }

    if (sourceBytes == null) {
      throw const FormatException('No source bytes provided');
    }
    await tempFile.writeAsBytes(sourceBytes, flush: true);
  }

  Future<_SourceAnalysis> _analyzeSource({
    String? sourcePath,
    Uint8List? sourceBytes,
  }) async {
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      final isGguf = _hasGgufHeader(sourceBytes);
      final digest = sha256.convert(sourceBytes).toString();
      return _SourceAnalysis(
        isValidGguf: isGguf,
        sha256: digest,
        fileSizeBytes: sourceBytes.length,
      );
    }

    if (sourcePath == null) {
      throw const FormatException('Missing source path and source bytes.');
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('File does not exist', sourcePath);
    }

    var totalBytes = 0;
    final firstBytes = <int>[];

    await for (final chunk in source.openRead()) {
      totalBytes += chunk.length;
      if (firstBytes.length < 4) {
        final needed = 4 - firstBytes.length;
        firstBytes.addAll(chunk.take(needed));
      }
    }
    final digest = (await sha256.bind(source.openRead()).first).toString();
    final headerBytes = Uint8List.fromList(firstBytes);

    return _SourceAnalysis(
      isValidGguf: _hasGgufHeader(headerBytes),
      sha256: digest,
      fileSizeBytes: totalBytes,
    );
  }

  bool _hasGgufHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final header = ascii.decode(bytes.sublist(0, 4), allowInvalid: true);
    return header == 'GGUF';
  }

  String _rolePrefix(int roleIndex) => roleIndex == 1 ? 'embed' : 'chat';
}

class _SourceAnalysis {
  final bool isValidGguf;
  final String sha256;
  final int fileSizeBytes;

  const _SourceAnalysis({
    required this.isValidGguf,
    required this.sha256,
    required this.fileSizeBytes,
  });
}

final aiModelRegistryServiceProvider = Provider<AiModelRegistryService>((ref) {
  return AiModelRegistryService(
    ref.read(storageServiceProvider),
    ref.read(ragServiceProvider),
  );
});
