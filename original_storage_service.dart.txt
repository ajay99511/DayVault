import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/types.dart';
import '../models/objectbox_models.dart';
import '../models/paged_result.dart';
import '../objectbox.g.dart';
import 'objectbox_service.dart';
import 'encryption_service.dart';
import 'security_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ObjectBoxService.instance.store);
});

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
const List<RankingCategory> _defaultCategories = [
  RankingCategory(id: 'movies', title: 'Movies', iconName: 'movie', items: []),
  RankingCategory(
      id: 'restaurants',
      title: 'Restaurants',
      iconName: 'restaurant',
      items: []),
  RankingCategory(id: 'places', title: 'Places', iconName: 'place', items: []),
  RankingCategory(id: 'people', title: 'People', iconName: 'person', items: []),
  RankingCategory(id: 'books', title: 'Books', iconName: 'book', items: []),
];

/// Controls whether journal queries see vaulted (private) entries.
///
/// The default everywhere is [excludePrivate] so private entries stay hidden
/// from every surface (home, calendar, stats, tags, On This Day) unless a
/// caller explicitly opts in — the vault screen uses [onlyPrivate], and
/// integrity-critical operations (backup export, tag rename/delete) use [all].
enum PrivacyFilter { excludePrivate, onlyPrivate, all }

class StorageService {
  late final Box<ObjectBoxJournalEntry> _journalBox;
  late final Box<ObjectBoxRankingCategory> _rankingBox;
  late final Box<ObjectBoxUserSettings> _settingsBox;
  late final Box<ObjectBoxVisionBoard> _visionBoardBox;

  // Draft storage - uses default FlutterSecureStorage
  // Key caching is handled in SecurityService
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();

  StorageService(Store store)
      : _journalBox = store.box<ObjectBoxJournalEntry>(),
        _rankingBox = store.box<ObjectBoxRankingCategory>(),
        _settingsBox = store.box<ObjectBoxUserSettings>(),
        _visionBoardBox = store.box<ObjectBoxVisionBoard>();

  // ─── Journal ────────────────────────────────────────────────────────────

  /// Privacy condition for [privacy], or null when no filtering applies.
  static Condition<ObjectBoxJournalEntry>? _privacyCondition(
      PrivacyFilter privacy) {
    switch (privacy) {
      case PrivacyFilter.excludePrivate:
        return ObjectBoxJournalEntry_.isPrivate.equals(false);
      case PrivacyFilter.onlyPrivate:
        return ObjectBoxJournalEntry_.isPrivate.equals(true);
      case PrivacyFilter.all:
        return null;
    }
  }

  /// Get all journal entries.
  ///
  /// Existing encrypted entries are auto-detected and decrypted during
  /// conversion. New entries are stored as plain text.
  Future<List<JournalEntry>> getJournal(
      {PrivacyFilter privacy = PrivacyFilter.excludePrivate}) async {
    final query = _journalBox
        .query(_privacyCondition(privacy))
        .order(ObjectBoxJournalEntry_.date, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      
      // We only need to batch decrypt if we have a key (meaning the user has
      // verified their PIN and we actually have a way to decrypt legacy AES data)
      final key = SecurityService().getCachedEncryptionKey();
      
      if (results.isEmpty) return [];

      if (key == null) {
        // If no key, just map synchronously (only XOR legacy will decrypt)
        return Future.wait(results.map((e) => e.toFreezed()));
      }
      
      // Extract raw data needed for decryption to pass to Isolate
      final rawEntries = results.map((e) => e.toRawMap()).toList();
      
      // Perform batch decryption in an Isolate
      final decryptedData = await compute(
        _batchDecryptEntries,
        {
          'entries': rawEntries,
          'key': key,
        },
      );
      
      // Reconstruct JournalEntry objects
      return List.generate(results.length, (i) {
        return results[i].toFreezedFromDecrypted(decryptedData[i]);
      });
    } finally {
      query.close();
    }
  }

  /// Number of stored journal entries visible under [privacy] — used for the
  /// header count when the list is only partially loaded via pagination.
  int journalCount({PrivacyFilter privacy = PrivacyFilter.excludePrivate}) {
    final cond = _privacyCondition(privacy);
    if (cond == null) return _journalBox.count();
    final query = _journalBox.query(cond).build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    final obEntry = await ObjectBoxJournalEntry.fromFreezed(entry);

    // Check if entry with this entryId already exists (update case)
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entry.id))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null) {
        obEntry.id = existing.id; // Preserve ObjectBox ID for update
      }
      _journalBox.put(obEntry);
    } finally {
      query.close();
    }
  }

  /// Cursor-based pagination — returns at most [pageSize] entries ordered by
  /// date descending. Pass [cursor] from the previous [PagedResult.nextCursor]
  /// to fetch the next page; omit or pass null to start from the first page.
  Future<PagedResult<JournalEntry>> getJournalPage(
    int pageSize, [
    PaginationCursor? cursor,
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  ]) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError('pageSize must be in [1, 100], got $pageSize');
    }

    final privacyCond = _privacyCondition(privacy);
    final cursorCond = cursor == null
        ? null
        : ObjectBoxJournalEntry_.id.lessThan(cursor.lastId);
    final cond = privacyCond == null
        ? cursorCond
        : (cursorCond == null ? privacyCond : cursorCond & privacyCond);
    final queryBuilder = _journalBox.query(cond);

    final query = queryBuilder
        .order(ObjectBoxJournalEntry_.date, flags: Order.descending)
        .build()
      ..limit = pageSize + 1;

    final List<ObjectBoxJournalEntry> raw;
    try {
      raw = query.find();
    } finally {
      query.close();
    }

    final hasMore = raw.length > pageSize;
    final page = hasMore ? raw.sublist(0, pageSize) : raw;

    final key = SecurityService().getCachedEncryptionKey();
    final List<JournalEntry> items;
    if (key == null) {
      items = await Future.wait(page.map((e) => e.toFreezed()));
    } else {
      final rawEntries = page.map((e) => e.toRawMap()).toList();
      final decrypted = await compute(
        _batchDecryptEntries,
        {'entries': rawEntries, 'key': key},
      );
      items = List.generate(
          page.length, (i) => page[i].toFreezedFromDecrypted(decrypted[i]));
    }

    final nextCursor =
        hasMore ? PaginationCursor.fromLastId(page.last.id) : null;
    return PagedResult(items: items, nextCursor: nextCursor);
  }

  /// Entries from the same calendar day (month + day) as [reference] in earlier
  /// years — powers the "On this day" memory resurfacing. Entries from
  /// [reference]'s own year are excluded so only genuinely past memories show.
  /// Returned most-recent first.
  Future<List<JournalEntry>> getOnThisDay(DateTime reference) async {
    final all = await getJournal(); // already ordered date-descending
    return all
        .where((e) =>
            e.date.month == reference.month &&
            e.date.day == reference.day &&
            e.date.year != reference.year)
        .toList();
  }

  /// Delete a journal entry.
  ///
  /// Image cleanup is reference-only by design: images are stored as references
  /// (file path / URL / gallery asset) that point at the user's existing files,
  /// never copies owned by the app. Removing the entry drops those references;
  /// we deliberately do NOT touch any file in device storage. (See 9.4 — the
  /// app keeps no orphaned image files to clean up under the reference-only
  /// model.)
  Future<void> deleteJournalEntry(String entryId) async {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null) {
        _journalBox.remove(existing.id); // drops the entry + its image refs
      }
    } finally {
      query.close();
    }
  }

  Future<ObjectBoxJournalEntry?> getJournalEntryById(String entryId) async {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  /// Returns the internal ObjectBox numeric id for the entry identified by
  /// [entryId], or null if no such entry exists.
  Future<int?> getObjectBoxIdForEntry(String entryId) async {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    try {
      return query.findFirst()?.id;
    } finally {
      query.close();
    }
  }

  /// Batch upsert of journal entries in a single ObjectBox write.
  ///
  /// Preserves the `@Unique entryId` update semantics used by
  /// [saveJournalEntry]: any entry whose [JournalEntry.id] already exists keeps
  /// that row's ObjectBox id, so the write updates the existing row in place
  /// instead of throwing a UniqueViolation. Within [entries], a later duplicate
  /// of the same id wins (last-write-wins).
  Future<void> putManyJournalEntries(List<JournalEntry> entries) async {
    if (entries.isEmpty) return;

    // Collapse intra-batch duplicates so we never try to insert two rows with
    // the same unique entryId in one transaction.
    final deduped = dedupeByEntryIdKeepingLast(entries);

    // Convert (serialize) all entries up front.
    final converted = <ObjectBoxJournalEntry>[];
    for (final e in deduped) {
      converted.add(await ObjectBoxJournalEntry.fromFreezed(e));
    }
    final obByEntryId = {for (final ob in converted) ob.entryId: ob};

    // One query maps already-persisted entryIds -> their ObjectBox ids.
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.oneOf(obByEntryId.keys.toList()))
        .build();
    try {
      for (final existing in query.find()) {
        obByEntryId[existing.entryId]?.id = existing.id;
      }
    } finally {
      query.close();
    }

    _journalBox.putMany(converted);
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

  // ─── Tags ─────────────────────────────────────────────────────────────--

  /// Distinct tags across all entries with their occurrence counts, keyed by the
  /// first-seen display casing (matching is case-insensitive).
  Future<Map<String, int>> getTagCounts() async {
    final all = await getJournal();
    final counts = <String, int>{};
    final lowerToDisplay = <String, String>{};
    for (final e in all) {
      for (final t in e.tags) {
        final display = lowerToDisplay.putIfAbsent(t.toLowerCase(), () => t);
        counts[display] = (counts[display] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Rename tag [from] to [to] across every entry (case-insensitive). When an
  /// entry already carries [to], the two are merged (no duplicate). Returns the
  /// number of entries changed.
  Future<int> renameTag(String from, String to) async {
    // Tag integrity must reach vaulted entries too, or renames silently
    // diverge between the vault and the rest of the journal.
    final changed =
        applyTagRename(await getJournal(privacy: PrivacyFilter.all), from, to);
    if (changed.isNotEmpty) await putManyJournalEntries(changed);
    return changed.length;
  }

  /// Remove [tag] from every entry (case-insensitive). Returns the number of
  /// entries changed.
  Future<int> deleteTag(String tag) async {
    // Same as renameTag: deletion must reach vaulted entries.
    final changed =
        applyTagDelete(await getJournal(privacy: PrivacyFilter.all), tag);
    if (changed.isNotEmpty) await putManyJournalEntries(changed);
    return changed.length;
  }

  /// Pure transform powering [renameTag]: returns only the entries whose tag
  /// list changed, with [from] replaced by [to] (case-insensitive) and any
  /// resulting duplicate collapsed. An empty/whitespace [to] is a no-op.
  /// Exposed for unit testing.
  @visibleForTesting
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
  @visibleForTesting
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

  // ─── Rankings ───────────────────────────────────────────────────────────

  Future<List<RankingCategory>> getFavoriteRankings() async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.isFavorite.equals(true))
        .build();
    try {
      final results = query.find();
      return results.map((c) => c.toFreezed()).toList();
    } finally {
      query.close();
    }
  }

  Future<List<RankingCategory>> getRankings() async {
    final results = _rankingBox.getAll();
    return results.map((c) => c.toFreezed()).toList();
  }

  Future<void> addRankingCategory(RankingCategory category) async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(category.id))
        .build();
    try {
      final existing = query.findFirst();

      final obCategory = ObjectBoxRankingCategory.fromFreezed(category);
      if (existing != null) {
        obCategory.id = existing.id;
      }
      _rankingBox.put(obCategory);
    } finally {
      query.close();
    }
  }

  Future<void> deleteRankingCategory(String categoryId) async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null) {
        _rankingBox.remove(existing.id);
      }
    } finally {
      query.close();
    }
  }

  Future<void> updateRankingCategory(RankingCategory category) async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(category.id))
        .build();
    try {
      final existing = query.findFirst();
      if (existing == null) return;

      final updated = ObjectBoxRankingCategory.fromFreezed(category)
        ..id = existing.id;
      _rankingBox.put(updated);
    } finally {
      query.close();
    }
  }

  Future<void> addRankedItem(String categoryId, RankedItem item) async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build();
    try {
      final existing = query.findFirst();
      if (existing == null) return;

      final cat = existing.toFreezed();
      final updatedCat = cat.copyWith(items: [...cat.items, item]);

      final updated = ObjectBoxRankingCategory.fromFreezed(updatedCat)
        ..id = existing.id;
      _rankingBox.put(updated);
    } finally {
      query.close();
    }
  }

  Future<void> deleteRankedItem(String categoryId, String itemId) async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build();
    try {
      final existing = query.findFirst();
      if (existing == null) return;

      final cat = existing.toFreezed();
      final filtered = cat.items.where((i) => i.id != itemId).toList();
      // Re-rank remaining items sequentially
      final reRanked = [
        for (int i = 0; i < filtered.length; i++)
          filtered[i].copyWith(rank: i + 1),
      ];
      final updatedCat = cat.copyWith(items: reRanked);

      final updated = ObjectBoxRankingCategory.fromFreezed(updatedCat)
        ..id = existing.id;
      _rankingBox.put(updated);
    } finally {
      query.close();
    }
  }

  Future<void> reorderRankedItems(
      String categoryId, List<RankedItem> reordered) async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build();
    try {
      final existing = query.findFirst();
      if (existing == null) return;

      // Assign sequential ranks
      final reRanked = [
        for (int i = 0; i < reordered.length; i++)
          reordered[i].copyWith(rank: i + 1),
      ];
      final updatedCat = existing.toFreezed().copyWith(items: reRanked);

      final updated = ObjectBoxRankingCategory.fromFreezed(updatedCat)
        ..id = existing.id;
      _rankingBox.put(updated);
    } finally {
      query.close();
    }
  }

  // ─── Vision Board ────────────────────────────────────────────────────────

  List<VisionBoard> getVisionBoards() {
    final results = _visionBoardBox.getAll();
    return results.map((b) => b.toFreezed()).toList()
      ..sort((a, b) => b.year.compareTo(a.year));
  }

  VisionBoard? getVisionBoardForYear(int year) {
    final query = _visionBoardBox
        .query(ObjectBoxVisionBoard_.year.equals(year))
        .build();
    try {
      return query.findFirst()?.toFreezed();
    } finally {
      query.close();
    }
  }

  VisionBoard getOrCreateVisionBoard(int year) {
    final existing = getVisionBoardForYear(year);
    if (existing != null) return existing;
    final board = VisionBoard(
      id: const Uuid().v4(),
      year: year,
      createdAt: DateTime.now(),
    );
    saveVisionBoard(board);
    return board;
  }

  void saveVisionBoard(VisionBoard board) {
    final ob = ObjectBoxVisionBoard.fromFreezed(board);
    final query = _visionBoardBox
        .query(ObjectBoxVisionBoard_.boardId.equals(board.id))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null) ob.id = existing.id;
      _visionBoardBox.put(ob);
    } finally {
      query.close();
    }
  }

  void addVisionBoardItem(int year, VisionBoardItem item) {
    final board = getOrCreateVisionBoard(year);
    saveVisionBoard(board.copyWith(items: [...board.items, item]));
  }

  void updateVisionBoardItem(int year, VisionBoardItem item) {
    final board = getVisionBoardForYear(year);
    if (board == null) return;
    final updatedItems = board.items
        .map((i) => i.id == item.id ? item : i)
        .toList();
    saveVisionBoard(board.copyWith(items: updatedItems));
  }

  void deleteVisionBoardItem(int year, String itemId) {
    final board = getVisionBoardForYear(year);
    if (board == null) return;
    saveVisionBoard(board.copyWith(
      items: board.items.where((i) => i.id != itemId).toList(),
    ));
  }

  /// Merge an imported board (e.g. from a restore) into local data, keyed by
  /// [VisionBoard.year] rather than board id. If a board already exists for that
  /// year, the imported items are upserted into it (matched by item id) and the
  /// existing row's id is preserved, so a restore can never create two rows for
  /// the same year. Otherwise the imported board is saved as-is.
  void mergeVisionBoard(VisionBoard imported) {
    final existing = getVisionBoardForYear(imported.year);
    if (existing == null) {
      saveVisionBoard(imported);
      return;
    }
    final byId = {for (final i in existing.items) i.id: i};
    for (final item in imported.items) {
      byId[item.id] = item; // upsert
    }
    saveVisionBoard(existing.copyWith(items: byId.values.toList()));
  }

  // ─── Settings ───────────────────────────────────────────────────────────

  UserSettings getSettings() {
    final byFixedId = _settingsBox.get(1);
    if (byFixedId != null) {
      return byFixedId.toFreezed();
    }

    final all = _settingsBox.getAll();
    if (all.isEmpty) {
      return const UserSettings(); // Defaults from Freezed
    }
    return all.first.toFreezed();
  }

  Future<UserSettings> saveSettings(UserSettings settings) async {
    final obSettings = ObjectBoxUserSettings.fromFreezed(settings);
    final byFixedId = _settingsBox.get(1);
    if (byFixedId != null) {
      obSettings.id = byFixedId.id;
    } else {
      final all = _settingsBox.getAll();
      obSettings.id = all.isNotEmpty ? all.first.id : 0;
    }
    _settingsBox.put(obSettings);
    return settings;
  }

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

  // ─── "On this day" banner dismissal ─────────────────────────────────────
  // Persist the calendar day the user dismissed the banner on, so it stays
  // hidden for that day but returns on later days (previously the dismissal was
  // in-memory only and reset every launch). Stored in the same key-value store
  // used for drafts; the value is a non-sensitive date string.
  static const String _onThisDayDismissedKey = 'on_this_day_dismissed';

  static String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

  Future<void> setOnThisDayDismissed(DateTime day) async {
    await _draftStorage.write(
        key: _onThisDayDismissedKey, value: _dayKey(day));
  }

  Future<bool> isOnThisDayDismissed(DateTime day) async {
    final stored = await _draftStorage.read(key: _onThisDayDismissedKey);
    return stored == _dayKey(day);
  }

  // ─── Draft Management ───────────────────────────────────────────────────

  /// Save entry draft for auto-save functionality
  Future<void> saveDraft(String draftId, String draftData) async {
    final encrypted = await EncryptionService().encrypt(draftData);
    await _draftStorage.write(key: 'draft_$draftId', value: encrypted);
    
    // Track this draft ID for bulk operations
    final existingDrafts = await getAllDraftIds();
    if (!existingDrafts.contains(draftId)) {
      existingDrafts.add(draftId);
      await _draftStorage.write(
        key: '_draft_keys_', 
        value: jsonEncode(existingDrafts),
      );
    }
  }

  /// Get saved draft by ID
  Future<String?> getDraft(String draftId) async {
    final raw = await _draftStorage.read(key: 'draft_$draftId');
    if (raw == null) return null;
    return EncryptionService().decrypt(raw);
  }

  /// Delete draft by ID
  Future<void> deleteDraft(String draftId) async {
    await _draftStorage.delete(key: 'draft_$draftId');
    
    // Remove from tracking
    final existingDrafts = await getAllDraftIds();
    existingDrafts.remove(draftId);
    await _draftStorage.write(
      key: '_draft_keys_', 
      value: jsonEncode(existingDrafts),
    );
  }

  /// Get all draft IDs
  Future<List<String>> getAllDraftIds() async {
    final json = await _draftStorage.read(key: '_draft_keys_');
    if (json == null || json.isEmpty) {
      return [];
    }
    
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (e) {
      debugPrint('Failed to parse draft keys: $e');
      return [];
    }
  }

  /// Clear all drafts (useful after successful save or user logout)
  Future<void> clearAllDrafts() async {
    final draftIds = await getAllDraftIds();
    for (final id in draftIds) {
      await _draftStorage.delete(key: 'draft_$id');
    }
    await _draftStorage.delete(key: '_draft_keys_');
  }
}

/// Top-level function for Isolate batch decryption.
List<Map<String, dynamic>> _batchDecryptEntries(Map<String, dynamic> params) {
  final entries = params['entries'] as List<Map<String, dynamic>>;
  final key = params['key'] as Uint8List;

  String decryptSync(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    try {
      final combined = base64Decode(encryptedText);
      if (combined.length < 17) return encryptedText;
      final version = combined[0];
      if (version == 1) {
        final data = combined.sublist(1);
        final result = Uint8List(data.length);
        for (int i = 0; i < data.length; i++) {
          result[i] = data[i] ^ key[i % key.length];
        }
        return utf8.decode(result, allowMalformed: true);
      }
    } catch (_) {}
    return encryptedText;
  }

  for (final entry in entries) {
    entry['headline'] = decryptSync(entry['headline'] as String);
    entry['content'] = decryptSync(entry['content'] as String);
    if (entry['feeling'] != null) {
      entry['feeling'] = decryptSync(entry['feeling'] as String);
    }
  }

  return entries;
}
