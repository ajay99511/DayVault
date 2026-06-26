import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/stats.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/providers/stats_provider.dart';

/// Builds a [JournalEntry] with sensible defaults so individual tests only
/// specify the fields they care about.
JournalEntry _entry({
  String id = 'id',
  DateTime? date,
  Mood mood = Mood.neutral,
  String content = '',
  List<String> tags = const [],
}) {
  return JournalEntry(
    id: id,
    type: EntryType.story,
    date: date ?? DateTime.now(),
    headline: 'H',
    content: content,
    mood: mood,
    tags: tags,
  );
}

void main() {
  // Property 1: Stats computation is correct for any entry collection.
  // (tasks.md 2.2 — Validates Requirements 1.1, 1.3)
  group('Property 1 — computeStats correctness', () {
    final rng = Random(20260615);
    const moods = Mood.values;
    final tagPool = ['work', 'life', 'health', 'travel', 'code', 'family'];

    test('holds for randomized collections of 0–500 entries', () {
      for (var iteration = 0; iteration < 200; iteration++) {
        final count = rng.nextInt(501); // 0..500
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final entries = <JournalEntry>[];
        for (var i = 0; i < count; i++) {
          final mood = moods[rng.nextInt(moods.length)];
          // Dates spread across the last ~400 days.
          final date = today.subtract(Duration(days: rng.nextInt(400)));
          // Content with a random, exactly-known word count.
          final words = rng.nextInt(12); // 0..11 words
          final content = List.filled(words, 'word').join('   ');
          // 0..3 random tags (may repeat — frequency must still be correct).
          final tagCount = rng.nextInt(4);
          final tags = List.generate(
              tagCount, (_) => tagPool[rng.nextInt(tagPool.length)]);
          entries.add(_entry(
            id: '$i',
            date: date,
            mood: mood,
            content: content,
            tags: tags,
          ));
        }

        final stats = StatsNotifier.computeStats(entries);

        if (entries.isEmpty) {
          expect(stats, same(JournalStats.empty));
          continue;
        }

        // totalEntries
        expect(stats.totalEntries, entries.length);

        // totalWordCount == manual whitespace-split count
        final expectedWords = entries.fold<int>(0, (sum, e) {
          final t = e.content.trim();
          return sum + (t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length);
        });
        expect(stats.totalWordCount, expectedWords);

        // mostFrequentMood == the modal mood, ties broken by lowest enum index
        final moodFreq = <Mood, int>{};
        for (final e in entries) {
          moodFreq[e.mood] = (moodFreq[e.mood] ?? 0) + 1;
        }
        Mood expectedMood = Mood.values.first;
        int bestCount = -1;
        for (final mood in Mood.values) {
          final c = moodFreq[mood] ?? 0;
          if (c > bestCount) {
            bestCount = c;
            expectedMood = mood;
          }
        }
        expect(stats.mostFrequentMood, expectedMood);

        // journalAgeInDays uses the oldest entry date
        final oldest = entries
            .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
            .reduce((a, b) => a.isBefore(b) ? a : b);
        expect(stats.journalAgeInDays, todayDate.difference(oldest).inDays);

        // topTags: at most 3, frequency desc, alpha on tie
        final freq = <String, int>{};
        for (final e in entries) {
          for (final tag in e.tags) {
            freq[tag] = (freq[tag] ?? 0) + 1;
          }
        }
        final expectedTags = (freq.entries.toList()
              ..sort((a, b) {
                final c = b.value.compareTo(a.value);
                return c != 0 ? c : a.key.compareTo(b.key);
              }))
            .take(3)
            .map((e) => e.key)
            .toList();
        expect(stats.topTags, expectedTags);
        expect(stats.topTags.length, lessThanOrEqualTo(3));
      }
    });

    test('empty collection returns the canonical empty stats', () {
      final stats = StatsNotifier.computeStats([]);
      expect(stats.totalEntries, 0);
      expect(stats.mostFrequentMood, isNull);
      expect(stats.streak, 0);
      expect(stats.totalWordCount, 0);
      expect(stats.journalAgeInDays, 0);
      expect(stats.topTags, isEmpty);
    });

    test('mostFrequentMood picks the modal mood', () {
      final entries = [
        _entry(id: '1', mood: Mood.sad),
        _entry(id: '2', mood: Mood.happy),
        _entry(id: '3', mood: Mood.happy),
      ];
      expect(StatsNotifier.computeStats(entries).mostFrequentMood, Mood.happy);
    });

    test('mostFrequentMood breaks ties by lowest enum index', () {
      // happy (index 1) and sad (index 5) both appear once -> happy wins.
      final entries = [
        _entry(id: '1', mood: Mood.sad),
        _entry(id: '2', mood: Mood.happy),
      ];
      expect(StatsNotifier.computeStats(entries).mostFrequentMood, Mood.happy);
    });

    test('top tags are alphabetically ordered on frequency ties', () {
      // All three tags appear exactly twice -> alpha order: apple, mango, zebra
      final entries = [
        _entry(id: '1', tags: ['zebra', 'mango', 'apple']),
        _entry(id: '2', tags: ['zebra', 'mango', 'apple']),
      ];
      final stats = StatsNotifier.computeStats(entries);
      expect(stats.topTags, ['apple', 'mango', 'zebra']);
    });
  });

  // Streak edge cases (tasks.md 2.2 — unit tests alongside the property test).
  group('computeStats — streak edge cases', () {
    DateTime daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

    test('single entry today -> streak 1', () {
      expect(StatsNotifier.computeStats([_entry(date: daysAgo(0))]).streak, 1);
    });

    test('single entry yesterday -> streak 1', () {
      expect(StatsNotifier.computeStats([_entry(date: daysAgo(1))]).streak, 1);
    });

    test('single entry two days ago -> streak 0', () {
      expect(StatsNotifier.computeStats([_entry(date: daysAgo(2))]).streak, 0);
    });

    test('gap in consecutive days stops the streak', () {
      // today, yesterday present; day-3 present but day-2 missing -> streak 2
      final entries = [
        _entry(id: 'a', date: daysAgo(0)),
        _entry(id: 'b', date: daysAgo(1)),
        _entry(id: 'c', date: daysAgo(3)),
      ];
      expect(StatsNotifier.computeStats(entries).streak, 2);
    });

    test('multiple entries on the same day count once', () {
      final entries = [
        _entry(id: 'a', date: daysAgo(0)),
        _entry(id: 'b', date: daysAgo(0)),
        _entry(id: 'c', date: daysAgo(1)),
      ];
      expect(StatsNotifier.computeStats(entries).streak, 2);
    });
  });

  group('computeStats — weekly consistency', () {
    DateTime daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

    test('buckets entries into the last 12 weeks (index 11 = current)', () {
      final entries = [
        _entry(id: 'today', date: daysAgo(0)), // current week
        _entry(id: 'thisweek', date: daysAgo(6)), // still current week
        _entry(id: 'lastweek', date: daysAgo(7)), // 1 week ago
        _entry(id: 'wk11', date: daysAgo(77)), // 11 weeks ago (oldest charted)
        _entry(id: 'tooold', date: daysAgo(84)), // 12 weeks ago -> excluded
      ];

      final weeks = StatsNotifier.computeStats(entries).entriesPerWeek;

      expect(weeks.length, 12);
      expect(weeks[11], 2); // today + 6 days ago
      expect(weeks[10], 1); // 7 days ago
      expect(weeks[0], 1); // 77 days ago
      expect(weeks.fold<int>(0, (s, v) => s + v), 4); // 84-day-old excluded
    });

    test('empty stats carry an empty week series', () {
      expect(JournalStats.empty.entriesPerWeek, isEmpty);
    });
  });
}
