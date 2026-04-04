import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/types.dart';
import 'storage_service.dart';
import 'encryption_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final settings = _storageService.getSettings();

    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'journal': journal.map((e) => _serializeEntry(e)).toList(),
      'rankings': rankings.map((c) => c.toJson()).toList(),
      'settings': settings.toJson(),
      'metadata': {
        'totalEntries': journal.length,
        'totalRankings': rankings.length,
        'totalCategories': rankings.length,
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
      'images': entry.images,
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
  }) async {
    try {
      final data = await exportData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      String content = jsonString;
      String fileExtension = 'json';

      if (encrypted) {
        // Encrypt the backup
        final encryptedContent = await _encryptionService.encrypt(jsonString);
        if (encryptedContent == null) {
          return BackupResult(
            success: false,
            error: 'Encryption failed - no encryption key available',
          );
        }
        content = encryptedContent;
        fileExtension = 'encrypted';
      }

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
      final shareResult = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Memory Palace Backup',
        text: encrypted
            ? 'Encrypted backup file. Import in Memory Palace app.'
            : 'Backup file from Memory Palace app.',
      );

      return BackupResult(
        success: true,
        filePath: filePath,
        shareResult: shareResult.status == ShareResultStatus.success,
      );
    } catch (e) {
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
  }) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup format
      if (!data.containsKey('version') || !data.containsKey('journal')) {
        return BackupResult(
          success: false,
          error: 'Invalid backup file format',
        );
      }

      // Import journal entries
      final journalList = data['journal'] as List;
      int importedEntries = 0;
      int skippedEntries = 0;

      for (final entryData in journalList) {
        try {
          final entry = _deserializeEntry(entryData as Map<String, dynamic>);
          await _storageService.saveJournalEntry(entry);
          importedEntries++;
        } catch (e) {
          debugPrint('Failed to import entry: $e');
          skippedEntries++;
        }
      }

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

      return BackupResult(
        success: true,
        message:
            'Imported $importedEntries entries and $importedRankings rankings'
            '${skippedEntries > 0 ? ' ($skippedEntries skipped)' : ''}',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        error: 'Import failed: ${e.toString()}',
      );
    }
  }

  /// Import from encrypted backup file
  Future<BackupResult> importEncryptedFile(String filePath) async {
    try {
      final file = File(filePath);
      final encryptedContent = await file.readAsString();

      // Decrypt the content
      final decryptedJson = await _encryptionService.decrypt(encryptedContent);

      return await importFromJson(decryptedJson);
    } catch (e) {
      return BackupResult(
        success: false,
        error: 'Failed to decrypt or import: ${e.toString()}',
      );
    }
  }

  /// Deserialize journal entry from export format
  JournalEntry _deserializeEntry(Map<String, dynamic> data) {
    return JournalEntry(
      id: data['id'] as String,
      type: EntryType.values[data['type'] as int],
      date: DateTime.parse(data['date'] as String),
      headline: data['headline'] as String,
      content: data['content'] as String,
      mood: Mood.values[data['mood'] as int],
      feeling: data['feeling'] as String?,
      tags: (data['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      location: data['location'] != null
          ? LocationData.fromJson(data['location'] as Map<String, dynamic>)
          : null,
      timeBucket: data['timeBucket'] != null
          ? TimeBucket.values[data['timeBucket'] as int]
          : null,
      images: _parseBackupImages(data['images'] as List?),
      isSpotlight: data['isSpotlight'] as bool? ?? false,
    );
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
