import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/paged_result.dart';
import 'package:memory_palace/models/types.dart';

/// Exercises the journal paging contract via [paginateByCursor] — the same code
/// `WebStorageService.getJournalPage` runs, and the specification
/// `NativeStorageService` mirrors as an ObjectBox keyset query.
///
/// The regression these pin down: the cursor used to carry an ObjectBox *row
/// id* while the listing was ordered by *date*. Row ids follow insertion order,
/// so an entry written today about last year got a high row id and an old date,
/// and fell out of every page after the first.
void main() {
  JournalEntry entry(String id, DateTime date) => JournalEntry(
        id: id,
        type: EntryType.story,
        date: date,
        headline: 'h-$id',
        content: 'c-$id',
        mood: Mood.neutral,
      );

  /// Walks every page to exhaustion, returning the ids in the order seen.
  List<String> pageThrough(List<JournalEntry> all, {required int pageSize}) {
    final seen = <String>[];
    PaginationCursor? cursor;
    var guard = 0;
    do {
      final page = paginateByCursor<JournalEntry>(
        all,
        pageSize: pageSize,
        cursor: cursor,
        dateOf: (e) => e.date,
        idOf: (e) => e.id,
      );
      seen.addAll(page.items.map((e) => e.id));
      cursor = page.nextCursor;
      if (++guard > 1000) fail('pagination did not terminate');
    } while (cursor != null);
    return seen;
  }

  group('ordering contract', () {
    test('orders newest first', () {
      final all = [
        entry('old', DateTime(2020, 1, 1)),
        entry('new', DateTime(2026, 1, 1)),
        entry('mid', DateTime(2023, 1, 1)),
      ];
      expect(pageThrough(all, pageSize: 10), ['new', 'mid', 'old']);
    });

    test('breaks timestamp ties deterministically rather than arbitrarily', () {
      final sameInstant = DateTime(2026, 5, 5, 12, 0, 0);
      final all = [
        entry('aaa', sameInstant),
        entry('ccc', sameInstant),
        entry('bbb', sameInstant),
      ];

      final first = pageThrough(all, pageSize: 10);
      // Re-run with the input in a different order: a total order must not
      // depend on how the rows happened to arrive.
      final second = pageThrough(all.reversed.toList(), pageSize: 10);

      expect(first, second);
      expect(first.length, 3);
    });
  });

  group('cursor pagination', () {
    test('returns every entry exactly once across pages', () {
      final all = [
        for (var i = 0; i < 25; i++)
          entry('e$i', DateTime(2026, 8, 24).subtract(Duration(days: i))),
      ];

      final seen = pageThrough(all, pageSize: 10);

      expect(seen.length, 25, reason: 'no entry may be dropped');
      expect(seen.toSet().length, 25, reason: 'no entry may repeat');
    });

    test('back-dated entry added last still appears on a later page', () {
      // The exact shape of the original defect: 25 recent entries, then one
      // written *now* but dated years ago. Under the old row-id cursor this
      // entry was returned by no page at all.
      final all = [
        for (var i = 0; i < 25; i++)
          entry('e$i', DateTime(2026, 8, 24).subtract(Duration(days: i))),
        entry('backdated', DateTime(2019, 1, 1)),
      ];

      final seen = pageThrough(all, pageSize: 10);

      expect(seen, contains('backdated'));
      expect(seen.length, 26);
      expect(seen.toSet().length, 26);
      expect(seen.last, 'backdated',
          reason: 'oldest entry sorts last, on the final page');
    });

    test('entries sharing a timestamp survive a page boundary landing between '
        'them', () {
      // pageSize 2 over 4 entries that all share one instant: the boundary
      // falls mid-tie, which is precisely where an ordering that is not total
      // loses or repeats rows.
      final sameInstant = DateTime(2026, 3, 3, 9, 30);
      final all = [
        entry('id-a', sameInstant),
        entry('id-b', sameInstant),
        entry('id-c', sameInstant),
        entry('id-d', sameInstant),
      ];

      final seen = pageThrough(all, pageSize: 2);

      expect(seen.length, 4);
      expect(seen.toSet(), {'id-a', 'id-b', 'id-c', 'id-d'});
    });

    test('page size larger than the collection ends with a null cursor', () {
      final page = paginateByCursor<JournalEntry>(
        [entry('only', DateTime(2026, 1, 1))],
        pageSize: 10,
        cursor: null,
        dateOf: (e) => e.date,
        idOf: (e) => e.id,
      );
      expect(page.items.single.id, 'only');
      expect(page.nextCursor, isNull,
          reason: 'a partial page means there is nothing after it');
    });

    test('exactly-full page reports no more when nothing follows', () {
      final all = [
        entry('a', DateTime(2026, 2, 2)),
        entry('b', DateTime(2026, 1, 1)),
      ];
      final page = paginateByCursor<JournalEntry>(
        all,
        pageSize: 2,
        cursor: null,
        dateOf: (e) => e.date,
        idOf: (e) => e.id,
      );
      expect(page.items.length, 2);
      expect(page.nextCursor, isNull);
    });

    test('empty collection yields an empty page and no cursor', () {
      final page = paginateByCursor<JournalEntry>(
        const <JournalEntry>[],
        pageSize: 20,
        cursor: null,
        dateOf: (e) => e.date,
        idOf: (e) => e.id,
      );
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('an entry inserted after page 1 does not shift the window', () {
      // Offset paging fails this: inserting an older entry ahead of the read
      // position pushed everything down by one and page 2 repeated a row.
      final all = [
        for (var i = 0; i < 6; i++)
          entry('e$i', DateTime(2026, 8, 24).subtract(Duration(days: i))),
      ];

      final first = paginateByCursor<JournalEntry>(
        all,
        pageSize: 3,
        cursor: null,
        dateOf: (e) => e.date,
        idOf: (e) => e.id,
      );
      expect(first.items.map((e) => e.id), ['e0', 'e1', 'e2']);

      // A brand new, newest-dated entry lands between the two fetches.
      final grown = [...all, entry('inserted', DateTime(2026, 9, 1))];

      final second = paginateByCursor<JournalEntry>(
        grown,
        pageSize: 3,
        cursor: first.nextCursor,
        dateOf: (e) => e.date,
        idOf: (e) => e.id,
      );

      expect(second.items.map((e) => e.id), ['e3', 'e4', 'e5'],
          reason: 'resuming from an entry, not an index, is insert-proof');
      expect(second.items.map((e) => e.id), isNot(contains('inserted')),
          reason: 'the new entry sorts before the cursor, already-read region');
    });
  });

  group('page size bounds', () {
    test('rejects a page size below the minimum', () {
      expect(
        () => paginateByCursor<JournalEntry>(
          const <JournalEntry>[],
          pageSize: 0,
          cursor: null,
          dateOf: (e) => e.date,
          idOf: (e) => e.id,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unbounded page size', () {
      expect(
        () => paginateByCursor<JournalEntry>(
          const <JournalEntry>[],
          pageSize: 101,
          cursor: null,
          dateOf: (e) => e.date,
          idOf: (e) => e.id,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PaginationCursor', () {
    test('compares by value', () {
      final d = DateTime(2026, 4, 4);
      expect(
        PaginationCursor(lastDate: d, lastEntryId: 'x'),
        PaginationCursor(lastDate: d, lastEntryId: 'x'),
      );
      expect(
        PaginationCursor(lastDate: d, lastEntryId: 'x'),
        isNot(PaginationCursor(lastDate: d, lastEntryId: 'y')),
      );
    });

    test('isAfter excludes the entry it names and everything before it', () {
      final cursor = PaginationCursor(
        lastDate: DateTime(2026, 6, 1),
        lastEntryId: 'm',
      );

      // The cursor entry itself was already returned.
      expect(cursor.isAfter(DateTime(2026, 6, 1), 'm'), isFalse);
      // Newer entries were already returned.
      expect(cursor.isAfter(DateTime(2026, 7, 1), 'a'), isFalse);
      // Older entries are still to come.
      expect(cursor.isAfter(DateTime(2026, 5, 1), 'z'), isTrue);
    });
  });
}
