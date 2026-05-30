import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/services/storage_service.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('StorageService.computeStreak', () {
    test('returns 0 for empty entries', () {
      expect(StorageService.computeStreak([]), 0);
    });

    test('returns 1 if only entry is today', () {
      final now = DateTime.now();
      final entries = [
        JournalEntry(
          id: '1',
          type: EntryType.story,
          date: now,
          headline: 'H',
          content: 'C',
          mood: Mood.happy,
        ),
      ];
      expect(StorageService.computeStreak(entries), 1);
    });

    test('returns 1 if only entry is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final entries = [
        JournalEntry(
          id: '1',
          type: EntryType.story,
          date: yesterday,
          headline: 'H',
          content: 'C',
          mood: Mood.happy,
        ),
      ];
      expect(StorageService.computeStreak(entries), 1);
    });

    test('returns 0 if only entry is 2 days ago', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final entries = [
        JournalEntry(
          id: '1',
          type: EntryType.story,
          date: twoDaysAgo,
          headline: 'H',
          content: 'C',
          mood: Mood.happy,
        ),
      ];
      expect(StorageService.computeStreak(entries), 0);
    });

    test('counts consecutive days correctly', () {
      final now = DateTime.now();
      final entries = List.generate(7, (i) => JournalEntry(
        id: '$i',
        type: EntryType.story,
        date: now.subtract(Duration(days: i)),
        headline: 'H',
        content: 'C',
        mood: Mood.happy,
      ));
      expect(StorageService.computeStreak(entries), 7);
    });

    test('stops at gap', () {
      final now = DateTime.now();
      final entries = [
        JournalEntry(id: '1', type: EntryType.story, date: now, headline: 'H', content: 'C', mood: Mood.happy),
        // skip yesterday
        JournalEntry(id: '2', type: EntryType.story, date: now.subtract(const Duration(days: 2)), headline: 'H', content: 'C', mood: Mood.happy),
      ];
      expect(StorageService.computeStreak(entries), 1);
    });

    test('order-independence', () {
      final now = DateTime.now();
      final entries = [
        JournalEntry(id: '1', type: EntryType.story, date: now, headline: 'H', content: 'C', mood: Mood.happy),
        JournalEntry(id: '2', type: EntryType.story, date: now.subtract(const Duration(days: 1)), headline: 'H', content: 'C', mood: Mood.happy),
      ];
      expect(StorageService.computeStreak(entries.reversed.toList()), 2);
    });
  });
}
