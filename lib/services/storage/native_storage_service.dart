import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../models/types.dart';
import '../../models/objectbox_models.dart';
import '../../models/paged_result.dart';
import '../../objectbox.g.dart';
import '../../domain/journal_rules.dart' as journal_rules;
import '../../utils/async_mutex.dart';
import '../encryption_service.dart';
import 'storage_service_interface.dart';
class NativeStorageService extends StorageService {
  late final Box<ObjectBoxJournalEntry> _journalBox;
  late final Box<ObjectBoxRankingCategory> _rankingBox;
  late final Box<ObjectBoxUserSettings> _settingsBox;
  late final Box<ObjectBoxVisionBoard> _visionBoardBox;

  // Draft storage - uses default FlutterSecureStorage
  // Key caching is handled in SecurityService
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();

  /// Secure-storage key holding the JSON array of known draft ids.
  static const String _draftKeysKey = '_draft_keys_';

  /// Serialises mutations of [_draftKeysKey]. See [saveDraft] for why.
  final AsyncMutex _draftIndexLock = AsyncMutex();

  NativeStorageService(Store store)
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
  /// Entries are stored as plain text. Any surviving legacy-encrypted row is
  /// decrypted during conversion; [migrateLegacyEncryptedEntries] rewrites such
  /// rows as plain text so this stays a no-op in the steady state.
  @override
  Future<List<JournalEntry>> getJournal(
      {PrivacyFilter privacy = PrivacyFilter.excludePrivate}) async {
    final query = _journalBox
        .query(_privacyCondition(privacy))
        .order(ObjectBoxJournalEntry_.date, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      if (results.isEmpty) return const [];

      // One decrypt path. There used to be two: a `compute()` isolate taken
      // whenever a key was cached, and this one otherwise. The isolate handled
      // *only* version-1 (XOR) rows — a version-2 AES row fell straight
      // through it and was handed back as raw base64 — so the correct path was
      // reachable only when there was no key to decrypt with. Removing it also
      // removes a second copy of the cipher and the per-read isolate spawn,
      // which was pure overhead now that content is stored as plain text.
      return await Future.wait(results.map((e) => e.toFreezed()));
    } finally {
      query.close();
    }
  }

  /// Rewrite any legacy-encrypted journal row as plain text.
  ///
  /// Journal content is plain text by design; rows predating that decision may
  /// still hold a version-1 (XOR) or version-2 (AES) envelope. This converts
  /// them once so no read path needs a cipher at all.
  ///
  /// Safety invariant: a row is rewritten **only** when decryption actually
  /// produced different text. If the value could not be read — no cached key,
  /// wrong key, corrupt bytes — [EncryptionService.decrypt] returns the input
  /// unchanged, this sees no difference, and the row is left exactly as it was.
  /// Unreadable data is never overwritten with its own ciphertext.
  ///
  /// Idempotent: a second run finds nothing to do. Returns the number of rows
  /// rewritten.
  @override
  Future<int> migrateLegacyEncryptedEntries() async {
    final rows = _journalBox.getAll();
    final rewritten = <ObjectBoxJournalEntry>[];

    for (final row in rows) {
      if (!_rowLooksEncrypted(row)) continue;

      final decrypted = await row.toFreezed();
      final feelingUnchanged =
          (decrypted.feeling ?? '') == (row.feeling ?? '');
      if (decrypted.headline == row.headline &&
          decrypted.content == row.content &&
          feelingUnchanged) {
        continue; // could not decrypt — leave it untouched
      }

      final plain = await ObjectBoxJournalEntry.fromFreezed(decrypted);
      plain.id = row.id;
      rewritten.add(plain);
    }

    if (rewritten.isNotEmpty) {
      _journalBox.putMany(rewritten);
      debugPrint('Rewrote ${rewritten.length} legacy-encrypted entries as '
          'plain text');
    }
    return rewritten.length;
  }

  static bool _rowLooksEncrypted(ObjectBoxJournalEntry row) =>
      EncryptionService.looksEncrypted(row.headline) ||
      EncryptionService.looksEncrypted(row.content) ||
      EncryptionService.looksEncrypted(row.feeling ?? '');

  /// Number of stored journal entries visible under [privacy] — used for the
  /// header count when the list is only partially loaded via pagination.
  @override
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

  @override
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
  @override
  Future<PagedResult<JournalEntry>> getJournalPage(
    int pageSize, [
    PaginationCursor? cursor,
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  ]) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError('pageSize must be in [1, 100], got $pageSize');
    }

    final privacyCond = _privacyCondition(privacy);
    final keysetCond = cursor == null ? null : _keysetCondition(cursor);
    final cond = privacyCond == null
        ? keysetCond
        : (keysetCond == null ? privacyCond : keysetCond & privacyCond);
    final queryBuilder = _journalBox.query(cond);

    final query = queryBuilder
        // (date DESC, id DESC) is a *total* order. The secondary sort is what
        // makes the keyset above exact: without it, two entries sharing a
        // timestamp have no defined relative position, so a page boundary
        // landing between them would drop one and repeat the other.
        .order(ObjectBoxJournalEntry_.date, flags: Order.descending)
        .order(ObjectBoxJournalEntry_.id, flags: Order.descending)
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

    // Single decrypt path — see the note in [getJournal].
    final items = await Future.wait(page.map((e) => e.toFreezed()));

    final nextCursor = hasMore
        ? PaginationCursor(
            lastDate: page.last.date,
            lastEntryId: page.last.entryId,
          )
        : null;
    return PagedResult(items: items, nextCursor: nextCursor);
  }

  /// Resume condition for [cursor]: everything strictly after it in
  /// `(date DESC, id DESC)` order, i.e.
  /// `date < lastDate OR (date == lastDate AND id < lastRowId)`.
  ///
  /// The cursor names an entry by its stable [JournalEntry.id], so the row id
  /// is resolved here through the `@Unique` index — one cheap lookup per page.
  /// Keying off the row id directly (as an earlier version did) is what made
  /// pagination wrong: rows are numbered in insertion order while the listing
  /// is ordered by user-chosen date, so a back-dated entry got a high row id
  /// with an old date and fell out of every page after the first.
  Condition<ObjectBoxJournalEntry>? _keysetCondition(PaginationCursor cursor) {
    final lastMillis = cursor.lastDate.millisecondsSinceEpoch;
    final lastRowId = _rowIdForEntryId(cursor.lastEntryId);

    if (lastRowId == null) {
      // The cursor's entry was deleted between pages. Fall back to the
      // date-only boundary: that can only re-show entries sharing this exact
      // millisecond, never skip one. Repeating an entry is a visible, harmless
      // glitch; silently dropping one is data the user believes they lost.
      return ObjectBoxJournalEntry_.date.lessOrEqual(lastMillis);
    }

    return ObjectBoxJournalEntry_.date.lessThan(lastMillis) |
        (ObjectBoxJournalEntry_.date.equals(lastMillis) &
            ObjectBoxJournalEntry_.id.lessThan(lastRowId));
  }

  /// Synchronous `entryId -> ObjectBox row id` lookup over the unique index.
  int? _rowIdForEntryId(String entryId) {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    try {
      return query.findFirst()?.id;
    } finally {
      query.close();
    }
  }

  /// Entries from the same calendar day (month + day) as [reference] in earlier
  /// years — powers the "On this day" memory resurfacing. Entries from
  /// [reference]'s own year are excluded so only genuinely past memories show.
  /// Returned most-recent first.
  @override
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
  @override
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
  @override
  Future<void> putManyJournalEntries(List<JournalEntry> entries) async {
    if (entries.isEmpty) return;

    // Collapse intra-batch duplicates so we never try to insert two rows with
    // the same unique entryId in one transaction.
    final deduped = journal_rules.dedupeByEntryIdKeepingLast(entries);

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

  // ─── Tags ─────────────────────────────────────────────────────────────--

  /// Distinct tags across all entries with their occurrence counts, keyed by the
  /// first-seen display casing (matching is case-insensitive).
  @override
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
  @override
  Future<int> renameTag(String from, String to) async {
    // Tag integrity must reach vaulted entries too, or renames silently
    // diverge between the vault and the rest of the journal.
    final changed =
        journal_rules.applyTagRename(
            await getJournal(privacy: PrivacyFilter.all), from, to);
    if (changed.isNotEmpty) await putManyJournalEntries(changed);
    return changed.length;
  }

  /// Remove [tag] from every entry (case-insensitive). Returns the number of
  /// entries changed.
  @override
  Future<int> deleteTag(String tag) async {
    // Same as renameTag: deletion must reach vaulted entries.
    final changed =
        journal_rules.applyTagDelete(
            await getJournal(privacy: PrivacyFilter.all), tag);
    if (changed.isNotEmpty) await putManyJournalEntries(changed);
    return changed.length;
  }

  // ─── Rankings ───────────────────────────────────────────────────────────

  @override
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

  @override
  Future<List<RankingCategory>> getRankings() async {
    final results = _rankingBox.getAll();
    return results.map((c) => c.toFreezed()).toList();
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  List<VisionBoard> getVisionBoards() {
    final results = _visionBoardBox.getAll();
    return results.map((b) => b.toFreezed()).toList()
      ..sort((a, b) => b.year.compareTo(a.year));
  }

  @override
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

  @override
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

  @override
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

  @override
  void addVisionBoardItem(int year, VisionBoardItem item) {
    final board = getOrCreateVisionBoard(year);
    saveVisionBoard(board.copyWith(items: [...board.items, item]));
  }

  @override
  void updateVisionBoardItem(int year, VisionBoardItem item) {
    final board = getVisionBoardForYear(year);
    if (board == null) return;
    final updatedItems = board.items
        .map((i) => i.id == item.id ? item : i)
        .toList();
    saveVisionBoard(board.copyWith(items: updatedItems));
  }

  @override
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
  @override
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

  @override
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

  @override
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

  // ─── "On this day" banner dismissal ─────────────────────────────────────
  // Persist the calendar day the user dismissed the banner on, so it stays
  // hidden for that day but returns on later days (previously the dismissal was
  // in-memory only and reset every launch). Stored in the same key-value store
  // used for drafts; the value is a non-sensitive date string.
  static const String _onThisDayDismissedKey = 'on_this_day_dismissed';

  static String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

  @override
  Future<void> setOnThisDayDismissed(DateTime day) async {
    await _draftStorage.write(
        key: _onThisDayDismissedKey, value: _dayKey(day));
  }

  @override
  Future<bool> isOnThisDayDismissed(DateTime day) async {
    final stored = await _draftStorage.read(key: _onThisDayDismissedKey);
    return stored == _dayKey(day);
  }

  // ─── Draft Management ───────────────────────────────────────────────────

  /// Save entry draft for auto-save functionality
  @override
  Future<void> saveDraft(String draftId, String draftData) async {
    final encrypted = await EncryptionService().encrypt(draftData);
    await _draftStorage.write(key: 'draft_$draftId', value: encrypted);

    // The id index is one JSON blob, so appending to it is a read-modify-write
    // across an await. The editor autosaves on a timer while other flows can
    // save at the same moment; unsynchronised, both read the same list and the
    // later write drops the earlier id — stranding an encrypted blob that
    // clearAllDrafts can then never find. Serialise index mutations.
    await _draftIndexLock.run(() async {
      final existingDrafts = await getAllDraftIds();
      if (existingDrafts.contains(draftId)) return;
      await _draftStorage.write(
        key: _draftKeysKey,
        value: jsonEncode([...existingDrafts, draftId]),
      );
    });
  }

  /// Get saved draft by ID
  @override
  Future<String?> getDraft(String draftId) async {
    final raw = await _draftStorage.read(key: 'draft_$draftId');
    if (raw == null) return null;
    return EncryptionService().decrypt(raw);
  }

  /// Delete draft by ID
  @override
  Future<void> deleteDraft(String draftId) async {
    await _draftStorage.delete(key: 'draft_$draftId');

    // Same read-modify-write hazard as saveDraft — see the note there.
    await _draftIndexLock.run(() async {
      final existingDrafts = await getAllDraftIds();
      if (!existingDrafts.remove(draftId)) return;
      await _draftStorage.write(
        key: _draftKeysKey,
        value: jsonEncode(existingDrafts),
      );
    });
  }

  /// Get all draft IDs
  @override
  Future<List<String>> getAllDraftIds() async {
    final json = await _draftStorage.read(key: _draftKeysKey);
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
  @override
  Future<void> clearAllDrafts() async {
    await _draftIndexLock.run(() async {
      final draftIds = await getAllDraftIds();
      for (final id in draftIds) {
        await _draftStorage.delete(key: 'draft_$id');
      }
      await _draftStorage.delete(key: _draftKeysKey);
    });
  }
}

