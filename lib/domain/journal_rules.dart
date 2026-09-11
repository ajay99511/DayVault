import '../models/types.dart';

/// Pure journal rules, independent of storage backend, Flutter and Riverpod.
///
/// These previously existed in several places at once: `computeStreak` had
/// three separate implementations (the `StorageService` interface, the ObjectBox
/// backend, and `StatsNotifier`) of which only one was ever called, and the tag
/// and dedupe helpers had two each. Statics are not inherited in Dart, so the
/// ObjectBox backend could not reuse the ones on its own superclass and copied
/// them instead — which is how the drift started.
///
/// Everything here is a pure function over data: no clock, no I/O, no globals.
/// `today` is a parameter rather than a `DateTime.now()` call precisely so the
/// streak can be tested at a date boundary without faking time.

/// Number of consecutive calendar days, ending at [today], on which at least
/// one entry exists.
///
/// A streak that ended yesterday still counts (the user has not broken it until
/// today ends), so the walk starts from yesterday when there is no entry today.
/// Returns 0 for an empty list or when the newest entry is older than that.
int computeJournalStreak(
  List<JournalEntry> entries, {
  required DateTime today,
}) {
  if (entries.isEmpty) return 0;

  final todayDate = DateTime(today.year, today.month, today.day);

  // Unique calendar days, newest first. Time-of-day is discarded: two entries
  // on the same day are one day of streak.
  final dates = entries
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  final yesterday = todayDate.subtract(const Duration(days: 1));
  if (dates.first.isBefore(yesterday)) return 0;

  // Entries dated in the future do not extend a streak; start no later than
  // today, and allow a streak whose most recent day is yesterday.
  var expected = dates.first == yesterday ? yesterday : todayDate;

  var streak = 0;
  for (final date in dates) {
    if (date == expected) {
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    } else if (date.isBefore(expected)) {
      break; // gap — the streak ends here
    }
    // date after expected: a future-dated entry, or a duplicate already
    // collapsed by the set above. Skip without breaking the run.
  }
  return streak;
}

/// Collapse [entries] to one per [JournalEntry.id], keeping the last occurrence
/// of each id. Surviving entries follow first-seen id order.
List<JournalEntry> dedupeByEntryIdKeepingLast(List<JournalEntry> entries) {
  final byId = <String, JournalEntry>{};
  for (final e in entries) {
    byId[e.id] = e; // later occurrence overwrites earlier
  }
  return byId.values.toList();
}

/// Returns only the entries whose tag list changes when [from] is renamed to
/// [to] (case-insensitive), with any resulting duplicate collapsed.
///
/// An empty or whitespace-only [to] is a no-op — renaming a tag to nothing
/// would silently delete it, which is a different operation with a different
/// confirmation.
List<JournalEntry> applyTagRename(
  List<JournalEntry> entries,
  String from,
  String to,
) {
  final fromLower = from.toLowerCase();
  final target = to.trim();
  if (target.isEmpty) return const [];

  final changed = <JournalEntry>[];
  for (final e in entries) {
    if (!e.tags.any((t) => t.toLowerCase() == fromLower)) continue;
    final newTags = <String>[];
    final seen = <String>{};
    for (final t in e.tags) {
      final replacement = t.toLowerCase() == fromLower ? target : t;
      if (seen.add(replacement.toLowerCase())) newTags.add(replacement);
    }
    changed.add(e.copyWith(tags: newTags));
  }
  return changed;
}

/// Returns only the entries whose tag list changes when [tag] is removed
/// (case-insensitive).
List<JournalEntry> applyTagDelete(List<JournalEntry> entries, String tag) {
  final tagLower = tag.toLowerCase();
  final changed = <JournalEntry>[];
  for (final e in entries) {
    if (!e.tags.any((t) => t.toLowerCase() == tagLower)) continue;
    changed.add(e.copyWith(
      tags: e.tags.where((t) => t.toLowerCase() != tagLower).toList(),
    ));
  }
  return changed;
}
