import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/services/backup_service.dart';
import 'package:memory_palace/services/storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<StorageService>()])
import 'backup_service_test.mocks.dart';

void main() {
  late BackupService backupService;
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    backupService = BackupService(mockStorage);
  });

  group('BackupService Validation', () {
    test('10,001 entries rejected', () async {
      final largeBackup = {
        'version': '1.0',
        'journal': List.generate(10001, (i) => {'id': '$i'}),
      };
      
      final result = await backupService.importFromJson(jsonEncode(largeBackup));
      
      expect(result.success, isFalse);
      expect(result.error, contains('maximum is 10,000'));
    });

    test('Invalid type index throws FormatException', () async {
      final invalidBackup = {
        'version': '1.0',
        'journal': [{
          'id': '1',
          'type': 99, // Invalid enum index
          'date': DateTime.now().toIso8601String(),
          'headline': 'H',
          'content': 'C',
          'mood': 0,
        }],
      };
      
      // importFromJson catches and skips failed entries, but we can verify it via the message
      final result = await backupService.importFromJson(jsonEncode(invalidBackup));
      expect(result.message, contains('0 entries'));
    });

    test('Long string fields are truncated', () async {
      final longString = 'A' * 20000;
      final backup = {
        'version': '1.0',
        'journal': [{
          'id': '1',
          'type': 0,
          'date': DateTime.now().toIso8601String(),
          'headline': longString,
          'content': 'C',
          'mood': 0,
        }],
      };
      
      await backupService.importFromJson(jsonEncode(backup));

      // Entries are restored as a single batch via putManyJournalEntries; the
      // captured argument is the list of deserialized entries.
      final captured =
          verify(mockStorage.putManyJournalEntries(captureAny)).captured.first;
      expect(captured.first.headline.length, 10000);
    });
  });

  // ─── 9.7* Off-thread staged progress ─────────────────────────────────────
  group('BackupService staged progress', () {
    Map<String, dynamic> validBackup() => {
          'version': '1.0',
          'journal': [
            {
              'id': '1',
              'type': 0,
              'date': DateTime.now().toIso8601String(),
              'headline': 'H',
              'content': 'C',
              'mood': 0,
            }
          ],
        };

    test('importFromJson emits reading -> restoring -> idle', () async {
      final stages = <BackupStage>[];
      await backupService.importFromJson(jsonEncode(validBackup()),
          onProgress: stages.add);
      expect(stages, [
        BackupStage.reading,
        BackupStage.restoring,
        BackupStage.idle,
      ]);
    });

    test('oversized backup ends at idle without restoring', () async {
      final stages = <BackupStage>[];
      final big = {
        'version': '1.0',
        'journal': List.generate(10001, (i) => {'id': '$i'}),
      };
      final result = await backupService.importFromJson(jsonEncode(big),
          onProgress: stages.add);
      expect(result.success, isFalse);
      expect(stages, [BackupStage.reading, BackupStage.idle]);
    });

    test('invalid format ends at idle', () async {
      final stages = <BackupStage>[];
      final result = await backupService.importFromJson(
          jsonEncode({'nope': true}),
          onProgress: stages.add);
      expect(result.success, isFalse);
      expect(stages, [BackupStage.reading, BackupStage.idle]);
    });
  });

  // ─── 9.8* Backup round-trip property ─────────────────────────────────────
  group('Backup JSON round-trip (encode/decode)', () {
    test('decode(encode(data)) == data for randomized documents', () {
      final rng = Random(2026);
      for (var i = 0; i < 100; i++) {
        final data = <String, dynamic>{
          'version': '1.0',
          'exportDate': DateTime(2025, 1, 1).toIso8601String(),
          'journal': List.generate(rng.nextInt(25), (j) {
            return {
              'id': 'e$j',
              'type': rng.nextInt(2),
              'headline': 'head $j',
              'content': 'body ${rng.nextInt(1000)}',
              'mood': rng.nextInt(5),
              'tags': ['t${rng.nextInt(3)}', 't${rng.nextInt(3)}'],
              'isSpotlight': j.isEven,
            };
          }),
          'metadata': {'totalEntries': rng.nextInt(100)},
        };

        final encoded = encodeBackupJson(data);
        final decoded = decodeBackupJson(encoded);
        expect(decoded, equals(data));
      }
    });
  });

  // ─── Privacy Vault flag in backups ───────────────────────────────────────
  group('Backup isPrivate handling', () {
    Map<String, dynamic> entryJson(String id, {bool? isPrivate}) => {
          'id': id,
          'type': 0,
          'date': DateTime(2025, 6, 1).toIso8601String(),
          'headline': 'H',
          'content': 'C',
          'mood': 0,
          if (isPrivate != null) 'isPrivate': isPrivate,
        };

    test('import preserves isPrivate=true', () async {
      final backup = {
        'version': '1.0',
        'journal': [
          entryJson('pub', isPrivate: false),
          entryJson('priv', isPrivate: true),
        ],
      };

      await backupService.importFromJson(jsonEncode(backup));

      final captured =
          verify(mockStorage.putManyJournalEntries(captureAny)).captured.first;
      expect(captured.singleWhere((e) => e.id == 'priv').isPrivate, isTrue);
      expect(captured.singleWhere((e) => e.id == 'pub').isPrivate, isFalse);
    });

    test('legacy backups without the key import as isPrivate=false', () async {
      final backup = {
        'version': '1.0',
        'journal': [entryJson('legacy')],
      };

      await backupService.importFromJson(jsonEncode(backup));

      final captured =
          verify(mockStorage.putManyJournalEntries(captureAny)).captured.first;
      expect(captured.single.isPrivate, isFalse);
    });

    test('export requests ALL entries (including vaulted) and carries the flag',
        () async {
      when(mockStorage.getSettings()).thenReturn(const UserSettings());
      when(mockStorage.getJournal(privacy: PrivacyFilter.all))
          .thenAnswer((_) async => [
                JournalEntry(
                  id: 'priv',
                  type: EntryType.story,
                  date: DateTime(2025, 6, 1),
                  headline: 'H',
                  content: 'C',
                  mood: Mood.happy,
                  isPrivate: true,
                ),
              ]);

      final data = await backupService.exportData();

      verify(mockStorage.getJournal(privacy: PrivacyFilter.all)).called(1);
      final journal = data['journal'] as List;
      expect((journal.single as Map<String, dynamic>)['isPrivate'], isTrue);
    });
  });
}
