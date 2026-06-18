import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/screens/calendar_screen.dart';

JournalEntry _entry(DateTime date, {String id = 'x'}) => JournalEntry(
      id: id,
      type: EntryType.story,
      date: date,
      headline: 'h',
      content: 'c',
      mood: Mood.happy,
    );

void main() {
  // ─── 5.8* Calendar date map property test ────────────────────────────────
  group('CalendarScreen.buildDateMap property', () {
    test('every entry is reachable under its date-only key and only there', () {
      final rng = Random(7);
      for (var iter = 0; iter < 200; iter++) {
        final n = rng.nextInt(60);
        final entries = List.generate(n, (i) {
          // Random dates spread across a ~2 year window, with random time parts.
          final base = DateTime(2024, 1, 1)
              .add(Duration(days: rng.nextInt(730), seconds: rng.nextInt(86400)));
          return _entry(base, id: 'e$i');
        });

        final map = CalendarScreen.buildDateMap(entries);

        // Invariant 1: counts are conserved — no entry dropped or duplicated.
        final total = map.values.fold<int>(0, (a, b) => a + b.length);
        expect(total, entries.length);

        // Invariant 2: each entry sits in the bucket whose key is its date-only.
        for (final e in entries) {
          final key = DateTime(e.date.year, e.date.month, e.date.day);
          expect(map[key], contains(e));
        }

        // Invariant 3: every key is normalized to midnight (no time component).
        for (final key in map.keys) {
          expect(key.hour, 0);
          expect(key.minute, 0);
          expect(key.second, 0);
          expect(key.millisecond, 0);
          expect(key.microsecond, 0);
        }

        // Invariant 4: entries sharing a calendar day collapse into one bucket.
        final distinctDays = entries
            .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
            .toSet();
        expect(map.keys.toSet(), distinctDays);
      }
    });

    test('empty input yields an empty map', () {
      expect(CalendarScreen.buildDateMap(const []), isEmpty);
    });

    test('same-day entries with different times group together', () {
      final a = _entry(DateTime(2025, 6, 16, 8, 0), id: 'a');
      final b = _entry(DateTime(2025, 6, 16, 23, 59), id: 'b');
      final map = CalendarScreen.buildDateMap([a, b]);
      expect(map.keys.length, 1);
      expect(map[DateTime(2025, 6, 16)], containsAll([a, b]));
    });
  });
}
