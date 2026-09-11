/// Platform-agnostic storage abstraction for DayVault.
///
/// This file defines the [StorageService] abstract class and related types
/// (e.g. [PrivacyFilter], [JournalRevisionNotifier]) that every platform
/// backend must implement. It deliberately avoids any ObjectBox or dart:ffi
/// imports so it can be compiled for web.
library;
import '../../models/types.dart';
import '../../models/paged_result.dart';

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

  /// Rewrite any legacy-encrypted journal row as plain text, returning the
  /// number of rows changed.
  ///
  /// Journal content is stored unencrypted by design — the Privacy Vault
  /// separates entries behind a PIN rather than making them unreadable — but
  /// rows written by older builds may still carry an encryption envelope.
  /// Converting them once lets the read path drop its cipher entirely.
  ///
  /// Implementations must be idempotent, and must leave a row untouched when
  /// they cannot actually decrypt it: unreadable data is never to be
  /// overwritten with its own ciphertext.
  Future<int> migrateLegacyEncryptedEntries();

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

}
