import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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
      
      final captured = verify(mockStorage.saveJournalEntry(captureAny)).captured.first;
      expect(captured.headline.length, 10000);
    });
  });
}
