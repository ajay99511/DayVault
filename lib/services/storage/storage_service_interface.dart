/// Platform-agnostic storage abstraction for DayVault.
///
/// This file defines the [StorageService] abstract class and related types
/// (e.g. [PrivacyFilter], [JournalRevisionNotifier]) that every platform
/// backend must implement. It deliberately avoids any ObjectBox or dart:ffi
/// imports so it can be compiled for web.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/types.dart';
import '../../models/paged_result.dart';

/// Monotonic counter bumped on every journal create/update/delete. Screens that
/// render journal data (`JournalScreen`, `CalendarScreen`) watch this and
/// reload, so a mutation made from one surface (e.g. editing in the viewer)
/// refreshes the others even when they are kept alive in the background.
final journalRevisionProvider =
    NotifierProvider<JournalRevisionNotifier, int>(JournalRevisionNotifier.new);

class JournalRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signal that journal data changed so dependent screens reload.
  void bump() => state++;
}

/// Default categories seeded on first launch (empty — no mock items).
const List<RankingCategory> defaultCategories = [
  RankingCategory(id: 'movies', title: 'Movies', iconName: 'movie', items: []),
  RankingCategory(
      id: 'restaurants',
      title: 'Restaurants',
      iconName: 'restaurant',
      items: []),
  RankingCategory(id: 'places', title: 'Places', iconName: 'place', items: []),
  RankingCategory(
      id: 'people', title: 'People', iconName: 'person', items: []),
  RankingCategory(id: 'books', title: 'Books', iconName: 'book', items: []),
];

/// Controls whether journal queries see vaulted (private) entries.
///
/// The default everywhere is [excludePrivate] so private entries stay hidden
/// from every surface (home, calendar, stats, tags, On This Day) unless a
/// caller explicitly opts in — the vault screen uses [onlyPrivate], and
/// integrity-critical operations (backup export, tag rename/delete) use [all].
enum PrivacyFilter { excludePrivate, onlyPrivate, all }

/// Platform-agnostic storage contract.
///
/// Native platforms implement this via [NativeStorageService] (ObjectBox);
/// web uses a separate implementation backed by IndexedDB or similar.
abstract class StorageService {
  // ─── Journal ──────────────────────────────────────────────────────────

  /// Get all journal entries.
  ///
  /// Existing encrypted entries are auto-detected and decrypted during
  /// conversion. New entries are stored as plain text.
  Future<List<JournalEntry>> getJournal(
      {PrivacyFilter privacy = PrivacyFilter.excludePrivate});

  /// Number of stored journal entries visible under [privacy] — used for the
  /// header count when the list is only partially loaded via pagination.
  int journalCount({PrivacyFilter privacy = PrivacyFilter.excludePrivate});

  Future<void> saveJournalEntry(JournalEntry entry);

  /// Cursor-based pagination — returns at most [pageSize] entries ordered by
  /// date descending. Pass [cursor] from the previous [PagedResult.nextCursor]
  /// to fetch the next page; omit or pass null to start from the first page.
  Future<PagedResult<JournalEntry>> getJournalPage(
    int pageSize, [
    PaginationCursor? cursor,
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  ]);

  /// Entries from the same calendar day (month + day) as [reference] in earlier
  /// years — powers the "On this day" memory resurfacing. Entries from
  /// [reference]'s own year are excluded so only genuinely past memories show.
  /// Returned most-recent first.
  Future<List<JournalEntry>> getOnThisDay(DateTime reference);

  /// Delete a journal entry.
  ///
  /// Image cleanup is reference-only by design: images are stored as references
  /// (file path / URL / gallery asset) that point at the user's existing files,
  /// never copies owned by the app. Removing the entry drops those references;
  /// we deliberately do NOT touch any file in device storage.
  Future<void> deleteJournalEntry(String entryId);

  /// Batch upsert of journal entries in a single write.
  Future<void> putManyJournalEntries(List<JournalEntry> entries);

  // ─── Tags ─────────────────────────────────────────────────────────────

  /// Distinct tags across all entries with their occurrence counts, keyed by the
  /// first-seen display casing (matching is case-insensitive).
  Future<Map<String, int>> getTagCounts();

  /// Rename tag [from] to [to] across every entry (case-insensitive). When an
  /// entry already carries [to], the two are merged (no duplicate). Returns the
  /// number of entries changed.
  Future<int> renameTag(String from, String to);

  /// Remove [tag] from every entry (case-insensitive). Returns the number of
  /// entries changed.
  Future<int> deleteTag(String tag);

  // ─── Rankings ─────────────────────────────────────────────────────────

  Future<List<RankingCategory>> getRankings();

  Future<List<RankingCategory>> getFavoriteRankings();

  Future<void> addRankingCategory(RankingCategory category);

  Future<void> deleteRankingCategory(String categoryId);

  Future<void> updateRankingCategory(RankingCategory category);

  Future<void> addRankedItem(String categoryId, RankedItem item);

  Future<void> deleteRankedItem(String categoryId, String itemId);

  Future<void> reorderRankedItems(
      String categoryId, List<RankedItem> reordered);

  // ─── Vision Board ─────────────────────────────────────────────────────

  List<VisionBoard> getVisionBoards();

  VisionBoard? getVisionBoardForYear(int year);

  VisionBoard getOrCreateVisionBoard(int year);

  void saveVisionBoard(VisionBoard board);

  void addVisionBoardItem(int year, VisionBoardItem item);

  void updateVisionBoardItem(int year, VisionBoardItem item);

  void deleteVisionBoardItem(int year, String itemId);

  /// Merge an imported board (e.g. from a restore) into local data, keyed by
  /// [VisionBoard.year] rather than board id.
  void mergeVisionBoard(VisionBoard imported);

  // ─── Settings ─────────────────────────────────────────────────────────

  UserSettings getSettings();

  Future<UserSettings> saveSettings(UserSettings settings);

  // ─── Drafts ───────────────────────────────────────────────────────────

  /// Save entry draft for auto-save functionality.
  Future<void> saveDraft(String draftId, String draftData);

  /// Get saved draft by ID.
  Future<String?> getDraft(String draftId);

  /// Delete draft by ID.
  Future<void> deleteDraft(String draftId);

  /// Get all draft IDs.
  Future<List<String>> getAllDraftIds();

  /// Clear all drafts (useful after successful save or user logout).
  Future<void> clearAllDrafts();

  // ─── "On this day" banner dismissal ───────────────────────────────────

  Future<void> setOnThisDayDismissed(DateTime day);

  Future<bool> isOnThisDayDismissed(DateTime day);

  // ─── Static helpers (pure, platform-agnostic) ─────────────────────────

  /// Compute the current journaling streak.
  ///
  /// Returns the number of consecutive calendar days ending on today
  /// (or the most recent entry date) on which at least one entry exists.
  /// Returns 0 if [entries] is empty.
  static int computeStreak(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;

    // Extract unique calendar dates (date only, no time)
    final dates = entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // descending

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime expected = todayDate;

    // If the most recent entry is not today or yesterday, streak is 0
    if (dates.first.isBefore(expected.subtract(const Duration(days: 1)))) {
      return 0;
    }

    // If most recent is yesterday, start from yesterday
    if (dates.first == expected.subtract(const Duration(days: 1)) &&
        dates.first != expected) {
      expected = dates.first;
    }

    for (final date in dates) {
      if (date == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (date.isBefore(expected)) {
        break; // gap found
      }
      // date > expected means duplicate date (already counted via toSet)
    }

    return streak;
  }

  /// Collapse a list of entries to one-per-[JournalEntry.id], keeping the last
  /// occurrence of each id. Order of the surviving entries follows first-seen
  /// id order. Pure + exposed for unit testing.
  @visibleForTesting
  static List<JournalEntry> dedupeByEntryIdKeepingLast(
      List<JournalEntry> entries) {
    final byId = <String, JournalEntry>{};
    for (final e in entries) {
      byId[e.id] = e; // later occurrence overwrites earlier
    }
    return byId.values.toList();
  }

  /// Pure transform powering [renameTag]: returns only the entries whose tag
  /// list changed, with [from] replaced by [to] (case-insensitive) and any
  /// resulting duplicate collapsed. An empty/whitespace [to] is a no-op.
  /// Exposed for unit testing.
  static List<JournalEntry> applyTagRename(
      List<JournalEntry> entries, String from, String to) {
    final fromL = from.toLowerCase();
    final toTrim = to.trim();
    if (toTrim.isEmpty) return const [];
    final changed = <JournalEntry>[];
    for (final e in entries) {
      if (!e.tags.any((t) => t.toLowerCase() == fromL)) continue;
      final newTags = <String>[];
      final seen = <String>{};
      for (final t in e.tags) {
        final replacement = t.toLowerCase() == fromL ? toTrim : t;
        if (seen.add(replacement.toLowerCase())) newTags.add(replacement);
      }
      changed.add(e.copyWith(tags: newTags));
    }
    return changed;
  }

  /// Pure transform powering [deleteTag]: returns only the entries whose tag
  /// list changed, with [tag] removed (case-insensitive). Exposed for testing.
  static List<JournalEntry> applyTagDelete(
      List<JournalEntry> entries, String tag) {
    final tagL = tag.toLowerCase();
    final changed = <JournalEntry>[];
    for (final e in entries) {
      if (!e.tags.any((t) => t.toLowerCase() == tagL)) continue;
      changed.add(e.copyWith(
          tags: e.tags.where((t) => t.toLowerCase() != tagL).toList()));
    }
    return changed;
  }
}
