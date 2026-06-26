import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/services/storage_service.dart';

JournalEntry _e(String id, {String headline = 'H', List<String> tags = const []}) =>
    JournalEntry(
      id: id,
      type: EntryType.story,
      date: DateTime(2025, 1, 1),
      headline: headline,
      content: 'C',
      mood: Mood.happy,
      tags: tags,
    );

void main() {
  // ─── 11.1 putManyJournalEntries dedup logic ──────────────────────────────
  group('StorageService.dedupeByEntryIdKeepingLast', () {
    test('empty input yields empty output', () {
      expect(StorageService.dedupeByEntryIdKeepingLast(const []), isEmpty);
    });

    test('distinct ids are preserved (one row each)', () {
      final out =
          StorageService.dedupeByEntryIdKeepingLast([_e('a'), _e('b'), _e('c')]);
      expect(out.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('duplicate ids collapse to the last occurrence (last-write-wins)', () {
      final out = StorageService.dedupeByEntryIdKeepingLast([
        _e('a', headline: 'first'),
        _e('b'),
        _e('a', headline: 'last'),
      ]);
      // One 'a' row, carrying the latest payload.
      final aRows = out.where((e) => e.id == 'a').toList();
      expect(aRows.length, 1);
      expect(aRows.single.headline, 'last');
      // No entryId appears more than once -> safe for the unique index.
      final ids = out.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // ─── Tag management transforms ───────────────────────────────────────────
  group('StorageService.applyTagRename', () {
    test('renames a tag across entries (case-insensitive), only changed rows', () {
      final out = StorageService.applyTagRename(
        [
          _e('a', tags: ['Work', 'life']),
          _e('b', tags: ['health']), // untouched
          _e('c', tags: ['WORK']),
        ],
        'work',
        'career',
      );
      expect(out.map((e) => e.id).toList(), ['a', 'c']); // 'b' unchanged
      expect(out[0].tags, ['career', 'life']);
      expect(out[1].tags, ['career']);
    });

    test('merges into an existing tag without duplicating', () {
      final out = StorageService.applyTagRename(
        [_e('a', tags: ['work', 'Career'])],
        'work',
        'career',
      );
      // 'work' -> 'career' collapses with the existing 'Career' (first wins).
      expect(out.single.tags, ['career']);
    });

    test('empty target is a no-op', () {
      expect(
        StorageService.applyTagRename([_e('a', tags: ['work'])], 'work', '   '),
        isEmpty,
      );
    });
  });

  group('StorageService.applyTagDelete', () {
    test('removes a tag (case-insensitive) from only the entries that carry it',
        () {
      final out = StorageService.applyTagDelete(
        [
          _e('a', tags: ['Work', 'life']),
          _e('b', tags: ['health']),
        ],
        'work',
      );
      expect(out.map((e) => e.id).toList(), ['a']);
      expect(out.single.tags, ['life']);
    });
  });

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
