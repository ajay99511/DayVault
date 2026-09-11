import 'package:flutter/foundation.dart';

/// The in-memory realisation of the journal ordering contract: newest first,
/// with the entry id as a deterministic tiebreaker.
///
/// The ordering contract every `StorageService` must satisfy is:
///
/// 1. entries come back strictly newest-first by `date`; and
/// 2. entries sharing an identical timestamp have a **stable total order**.
///
/// Rule 2 is not cosmetic. Cursor (keyset) pagination is only correct over a
/// total order — if two entries can compare equal, a page boundary landing
/// between them skips one and repeats the other. Journal entries are
/// user-dated, so shared timestamps are ordinary, not exotic.
///
/// Which entry wins a tie is deliberately left to the backend (ObjectBox
/// resolves ties by row id; this function and the web backend resolve them by
/// entry id) because only *stability* affects correctness. This function is
/// what the web backend and the pagination tests use.
///
/// Returns a negative number when (a) sorts before (b) — i.e. (a) is newer.
int compareJournalEntriesDescending(
  DateTime dateA,
  String entryIdA,
  DateTime dateB,
  String entryIdB,
) {
  final byDate = dateB.compareTo(dateA); // descending
  if (byDate != 0) return byDate;
  return entryIdB.compareTo(entryIdA); // descending, stable
}

/// A position in the journal's total ordering, naming the **last entry returned
/// by the previous page**. The next page resumes strictly after it.
///
/// It deliberately carries *domain* values — the entry's date and its stable
/// [JournalEntry.id] — rather than a storage row id. A row id means different
/// things in different backends (ObjectBox assigns them in insertion order;
/// the web backend has none at all), and an earlier version of this class
/// carried one: `NativeStorageService` filtered by row id while ordering by
/// date, so any back-dated entry — one written today about last year, which
/// this app treats as a first-class action — was dropped from every subsequent
/// page while other entries came back twice. Keying the cursor to the same
/// values the ordering uses is what makes that class of bug impossible.
@immutable
class PaginationCursor {
  /// Date of the last entry on the previous page.
  final DateTime lastDate;

  /// Stable [JournalEntry.id] of the last entry on the previous page.
  final String lastEntryId;

  const PaginationCursor({
    required this.lastDate,
    required this.lastEntryId,
  });

  /// True when the entry identified by [date]/[entryId] falls strictly *after*
  /// this cursor in [compareJournalEntriesDescending] order, i.e. it belongs on
  /// a later page. Entries at or before the cursor were already returned.
  bool isAfter(DateTime date, String entryId) =>
      compareJournalEntriesDescending(date, entryId, lastDate, lastEntryId) > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationCursor &&
          other.lastDate == lastDate &&
          other.lastEntryId == lastEntryId;

  @override
  int get hashCode => Object.hash(lastDate, lastEntryId);

  @override
  String toString() =>
      'PaginationCursor(lastDate: $lastDate, lastEntryId: $lastEntryId)';
}

class PagedResult<T> {
  final List<T> items;
  final PaginationCursor? nextCursor;

  const PagedResult({required this.items, this.nextCursor});
}

/// Reference implementation of the journal paging contract over an in-memory
/// list. `WebStorageService` runs this directly; `NativeStorageService`
/// expresses the identical predicate as an ObjectBox query so the two backends
/// agree on what a cursor means.
///
/// [items] need not be sorted — this sorts into the contract's total order
/// first, then returns the page of at most [pageSize] entries that falls
/// strictly after [cursor].
///
/// Throws [ArgumentError] if [pageSize] is outside `[1, 100]`, matching the
/// bound both backends enforce.
PagedResult<T> paginateByCursor<T>(
  Iterable<T> items, {
  required int pageSize,
  required PaginationCursor? cursor,
  required DateTime Function(T) dateOf,
  required String Function(T) idOf,
}) {
  if (pageSize < 1 || pageSize > 100) {
    throw ArgumentError('pageSize must be in [1, 100], got $pageSize');
  }

  final ordered = items.toList()
    ..sort((a, b) => compareJournalEntriesDescending(
          dateOf(a),
          idOf(a),
          dateOf(b),
          idOf(b),
        ));

  final remaining = cursor == null
      ? ordered
      : ordered.where((e) => cursor.isAfter(dateOf(e), idOf(e))).toList();

  final hasMore = remaining.length > pageSize;
  final page = hasMore ? remaining.sublist(0, pageSize) : remaining;

  return PagedResult<T>(
    items: page,
    nextCursor: hasMore
        ? PaginationCursor(
            lastDate: dateOf(page.last),
            lastEntryId: idOf(page.last),
          )
        : null,
  );
}
