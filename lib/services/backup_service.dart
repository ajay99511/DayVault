import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/types.dart';
import 'storage_service.dart';
import 'encryption_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BackupStage { idle, serializing, encrypting, writing, reading, decrypting, restoring }

/// Progress callback for staged backup/restore operations.
typedef BackupProgress = void Function(BackupStage stage);

/// Pretty-print the export map to JSON. Top-level + pure so it can run off the
/// main isolate via [compute] (serializing a large journal is CPU-heavy).
String encodeBackupJson(Map<String, dynamic> data) =>
    const JsonEncoder.withIndent('  ').convert(data);

/// Parse a backup JSON document. Top-level + pure for off-isolate [compute].
Map<String, dynamic> decodeBackupJson(String jsonString) =>
    jsonDecode(jsonString) as Map<String, dynamic>;

/// Service for exporting and importing user data.
/// 
/// Features:
/// - Export all journal entries, rankings, and settings to JSON
/// - Optional encryption for backup files
/// - Share backup to cloud storage or other apps
/// - Import backup data with validation
class BackupService {
  final StorageService _storageService;
  final EncryptionService _encryptionService;

  BackupService(this._storageService)
      : _encryptionService = EncryptionService();

  /// Export all user data to JSON format
  /// 
  /// Returns a JSON string containing all exportable data.
  Future<Map<String, dynamic>> exportData() async {
    final journal = await _storageService.getJournal();
    final rankings = await _storageService.getRankings();
    final visionBoards = _storageService.getVisionBoards();
    final settings = _storageService.getSettings();

    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'journal': journal.map((e) => _serializeEntry(e)).toList(),
      'rankings': rankings.map((c) => c.toJson()).toList(),
      'visionBoards': visionBoards.map((b) => b.toJson()).toList(),
      'settings': settings.toJson(),
      'metadata': {
        'totalEntries': journal.length,
        'totalRankings': rankings.length,
        'totalCategories': rankings.length,
        'totalVisionBoards': visionBoards.length,
      },
    };
  }

  /// Serialize journal entry for export
  Map<String, dynamic> _serializeEntry(JournalEntry entry) {
    return {
      'id': entry.id,
      'type': entry.type.index,
      'date': entry.date.toIso8601String(),
      'headline': entry.headline,
      'content': entry.content,
      'mood': entry.mood.index,
      'feeling': entry.feeling,
      'tags': entry.tags,
      'location': entry.location?.toJson(),
      'timeBucket': entry.timeBucket?.index,
      'images': entry.images.map((i) => i.toJson()).toList(),
      'isSpotlight': entry.isSpotlight,
    };
  }

  /// Export data to a file and share it
  /// 
  /// [encrypted] - Whether to encrypt the backup file
  /// [password] - Optional password for encryption (uses PIN if null)
  Future<BackupResult> exportToFile({
    bool encrypted = true,
    String? password,
    BackupProgress? onProgress,
  }) async {
    try {
      onProgress?.call(BackupStage.serializing);
      final data = await exportData();
      // Serialize off the main isolate — large journals are CPU-heavy to encode.
      final jsonString = await compute(encodeBackupJson, data);

      String content = jsonString;
      String fileExtension = 'json';

      if (encrypted) {
        // Encrypt the backup. NOTE: kept on the main isolate — encryption is
        // bound to the in-memory key held by the SecurityService singleton,
        // which an isolate cannot see.
        onProgress?.call(BackupStage.encrypting);
        final encryptedContent = await _encryptionService.encrypt(jsonString);
        if (encryptedContent == null) {
          onProgress?.call(BackupStage.idle);
          return BackupResult(
            success: false,
            error: 'Encryption failed - no encryption key available',
          );
        }
        content = encryptedContent;
        fileExtension = 'encrypted';
      }

      onProgress?.call(BackupStage.writing);
      // Save to file
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'memory_palace_backup_$timestamp.$fileExtension';
      final filePath = '${backupDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(content);

      // Share the file
      // ignore: deprecated_member_use
      final shareResult = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Memory Palace Backup',
        text: encrypted
            ? 'Encrypted backup file. Import in Memory Palace app.'
            : 'Backup file from Memory Palace app.',
      );

      onProgress?.call(BackupStage.idle);
      return BackupResult(
        success: true,
        filePath: filePath,
        shareResult: shareResult.status == ShareResultStatus.success,
      );
    } catch (e) {
      onProgress?.call(BackupStage.idle);
      return BackupResult(
        success: false,
        error: 'Export failed: ${e.toString()}',
      );
    }
  }

  /// Import data from JSON string
  /// 
  /// [jsonString] - The JSON data to import
  /// [merge] - If true, merge with existing data. If false, replace all.
  Future<BackupResult> importFromJson(
    String jsonString, {
    bool merge = true,
    BackupProgress? onProgress,
  }) async {
    try {
      onProgress?.call(BackupStage.reading);
      // Parse off the main isolate — a large backup is heavy to decode.
      final data = await compute(decodeBackupJson, jsonString);

      // Validate backup format
      if (!data.containsKey('version') || !data.containsKey('journal')) {
        onProgress?.call(BackupStage.idle);
        return BackupResult(
          success: false,
          error: 'Invalid backup file format',
        );
      }

      // Import journal entries
      final journalList = data['journal'] as List;

      // Enforce maximum entries to prevent resource exhaustion
      if (journalList.length > 10000) {
        onProgress?.call(BackupStage.idle);
        return BackupResult(
          success: false,
          error: 'Backup contains ${journalList.length} entries; maximum is 10,000',
        );
      }

      onProgress?.call(BackupStage.restoring);
      int skippedEntries = 0;

      // Deserialize first (skipping any malformed entries), then write the whole
      // batch in a single ObjectBox transaction via putManyJournalEntries —
      // far cheaper than a per-entry query+put for large restores. Upsert-by
      // entryId semantics are preserved (existing ids are overwritten).
      final entries = <JournalEntry>[];
      for (final entryData in journalList) {
        try {
          entries.add(_deserializeEntry(entryData as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Failed to import entry: $e');
          skippedEntries++;
        }
      }
      await _storageService.putManyJournalEntries(entries);
      final importedEntries = entries.length;

      // Import rankings
      final rankingsList = data['rankings'] as List?;
      int importedRankings = 0;

      if (rankingsList != null) {
        for (final categoryData in rankingsList) {
          try {
            final category = RankingCategory.fromJson(
              categoryData as Map<String, dynamic>,
            );
            await _storageService.addRankingCategory(category);
            importedRankings++;
          } catch (e) {
            debugPrint('Failed to import ranking: $e');
          }
        }
      }

      // Import vision boards (optional — older backups predate this key, so a
      // missing 'visionBoards' field is not an error). Merged by year.
      final visionBoardsList = data['visionBoards'] as List?;
      int importedVisionBoards = 0;

      if (visionBoardsList != null) {
        for (final boardData in visionBoardsList) {
          try {
            final board =
                VisionBoard.fromJson(boardData as Map<String, dynamic>);
            _storageService.mergeVisionBoard(board);
            importedVisionBoards++;
          } catch (e) {
            debugPrint('Failed to import vision board: $e');
          }
        }
      }

      onProgress?.call(BackupStage.idle);
      return BackupResult(
        success: true,
        message:
            'Imported $importedEntries entries, $importedRankings rankings'
            '${importedVisionBoards > 0 ? ', $importedVisionBoards vision boards' : ''}'
            '${skippedEntries > 0 ? ' ($skippedEntries skipped)' : ''}',
      );
    } catch (e) {
      onProgress?.call(BackupStage.idle);
      return BackupResult(
        success: false,
        error: 'Import failed: ${e.toString()}',
      );
    }
  }

  /// Import a backup file, dispatching on whether it is encrypted.
  ///
  /// Used by the "Restore" action in the Manage Backups sheet.
  Future<BackupResult> importBackupFile(
    String filePath, {
    required bool isEncrypted,
    BackupProgress? onProgress,
  }) async {
    if (isEncrypted) {
      return importEncryptedFile(filePath, onProgress: onProgress);
    }
    try {
      onProgress?.call(BackupStage.reading);
      final content = await File(filePath).readAsString();
      return importFromJson(content, onProgress: onProgress);
    } catch (e) {
      onProgress?.call(BackupStage.idle);
      return BackupResult(
        success: false,
        error: 'Failed to read backup: ${e.toString()}',
      );
    }
  }

  /// Import from encrypted backup file
  Future<BackupResult> importEncryptedFile(
    String filePath, {
    BackupProgress? onProgress,
  }) async {
    try {
      onProgress?.call(BackupStage.reading);
      final file = File(filePath);
      final encryptedContent = await file.readAsString();

      // Decrypt the content (main isolate — key-bound, see exportToFile note).
      onProgress?.call(BackupStage.decrypting);
      final decryptedJson = await _encryptionService.decrypt(encryptedContent);

      return await importFromJson(decryptedJson, onProgress: onProgress);
    } catch (e) {
      onProgress?.call(BackupStage.idle);
      return BackupResult(
        success: false,
        error: 'Failed to decrypt or import: ${e.toString()}',
      );
    }
  }

  /// Deserialize journal entry from export format with validation
  JournalEntry _deserializeEntry(Map<String, dynamic> data) {
    return JournalEntry(
      id: data['id'] as String,
      type: _safeEnumValue(EntryType.values, data['type'] as int?, 'type'),
      date: DateTime.parse(data['date'] as String),
      headline: _truncate(data['headline'] as String?) ?? '',
      content: _truncate(data['content'] as String?) ?? '',
      mood: _safeEnumValue(Mood.values, data['mood'] as int?, 'mood'),
      feeling: _truncate(data['feeling'] as String?),
      tags: (data['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      location: data['location'] != null
          ? LocationData.fromJson(data['location'] as Map<String, dynamic>)
          : null,
      timeBucket: data['timeBucket'] != null
          ? _safeEnumValue(TimeBucket.values, data['timeBucket'] as int?, 'timeBucket')
          : null,
      images: _parseBackupImages(data['images'] as List?),
      isSpotlight: data['isSpotlight'] as bool? ?? false,
    );
  }

  /// Helper to safely get enum value from index with bounds checking
  T _safeEnumValue<T>(List<T> values, int? index, String fieldName) {
    if (index == null || index < 0 || index >= values.length) {
      throw FormatException(
        'Invalid $fieldName value: $index (valid range 0-${values.length - 1})'
      );
    }
    return values[index];
  }

  /// Truncate long strings to prevent resource exhaustion attacks
  String? _truncate(String? value, {int maxLength = 10000}) {
    if (value == null) return null;
    return value.length > maxLength ? value.substring(0, maxLength) : value;
  }

  /// Parse images from backup data (backward compatible).
  static List<ImageReference> _parseBackupImages(List? rawImages) {
    if (rawImages == null || rawImages.isEmpty) return [];

    final first = rawImages.first;
    if (first is Map && first.containsKey('source')) {
      // New format: ImageReference JSON
      return rawImages
          .map((m) => ImageReference.fromJson(m as Map<String, dynamic>))
          .toList();
    } else if (first is String) {
      // Old format: plain file paths
      return rawImages
          .map((path) => ImageReference(
                source: path as String,
                type: ImageSourceType.filePath,
              ))
          .toList();
    }
    return [];
  }

  /// Get backup directory path
  Future<String> getBackupDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir.path;
  }

  /// List all backup files
  Future<List<BackupFileInfo>> listBackups() async {
    try {
      final backupDirPath = await getBackupDirectory();
      final backupDir = Directory(backupDirPath);
      
      if (!await backupDir.exists()) {
        return [];
      }

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.json') || f.path.endsWith('.encrypted'))
          .toList();

      return files
          .map((f) {
            try {
              final stat = f.statSync();
              return BackupFileInfo(
                path: f.path,
                name: f.path.split('/').last,
                size: stat.size,
                created: stat.modified,
                isEncrypted: f.path.endsWith('.encrypted'),
              );
            } catch (e) {
              return null;
            }
          })
          .whereType<BackupFileInfo>()
          .toList()
        ..sort((a, b) => b.created.compareTo(a.created));
    } catch (e) {
      debugPrint('Failed to list backups: $e');
      return [];
    }
  }

  /// Delete a backup file
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to delete backup: $e');
      return false;
    }
  }
}

/// Result of backup/restore operation
class BackupResult {
  final bool success;
  final String? error;
  final String? message;
  final String? filePath;
  final bool? shareResult;

  BackupResult({
    required this.success,
    this.error,
    this.message,
    this.filePath,
    this.shareResult,
  });
}

/// Information about a backup file
class BackupFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime created;
  final bool isEncrypted;

  BackupFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.created,
    required this.isEncrypted,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return DateFormat('MMM d, yyyy • h:mm a').format(created);
  }
}

/// Provider for backup service
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.read(storageServiceProvider));
});
