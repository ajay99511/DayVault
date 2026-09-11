import 'dart:convert';
// dart:html is deprecated in favour of package:web + dart:js_interop. That
// migration is a separate, independently-verifiable change and is tracked
// alongside the web backend's at-rest encryption gap; until both land, this
// import is what keeps the web target building.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/types.dart';
import '../../models/paged_result.dart';
import '../../utils/async_mutex.dart';
import '../../domain/journal_rules.dart' as journal_rules;
import 'storage_service_interface.dart';
import '../encryption_service.dart';

class WebStorageService extends StorageService {
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();

  /// Serialises mutations of the draft id index. See [saveDraft].
  final AsyncMutex _draftIndexLock = AsyncMutex();
  
  static const _journalKey = 'dv_journal';
  static const _rankingsKey = 'dv_rankings';
  static const _settingsKey = 'dv_settings';
  static const _visionBoardsKey = 'dv_vision_boards';
  static const _onThisDayDismissedKey = 'dv_on_this_day_dismissed';

  bool _matchesPrivacy(JournalEntry entry, PrivacyFilter privacy) {
    switch (privacy) {
      case PrivacyFilter.excludePrivate:
        return !entry.isPrivate;
      case PrivacyFilter.onlyPrivate:
        return entry.isPrivate;
      case PrivacyFilter.all:
        return true;
    }
  }

  Future<JournalEntry> _decryptEntry(JournalEntry entry) async {
    if (!entry.isPrivate) return entry;
    
    try {
      final decryptedHeadline = await EncryptionService().decrypt(entry.headline);
      final decryptedContent = await EncryptionService().decrypt(entry.content);
      final decryptedFeeling = entry.feeling != null ? await EncryptionService().decrypt(entry.feeling!) : null;
      
      // decrypt() returns a non-nullable String (it falls back to the original
      // text), so headline/content need no null-coalescing. feeling stays
      // guarded because the ternary above yields null for a null input.
      return entry.copyWith(
        headline: decryptedHeadline,
        content: decryptedContent,
        feeling: decryptedFeeling ?? entry.feeling,
      );
    } catch (e) {
      debugPrint('Error decrypting entry on web: $e');
      return entry;
    }
  }

  List<JournalEntry> _loadJournal() {
    final str = html.window.localStorage[_journalKey];
    if (str == null || str.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(str);
      return jsonList.map((j) => JournalEntry.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error parsing web journal: $e');
      return [];
    }
  }

  void _saveJournal(List<JournalEntry> entries) {
    html.window.localStorage[_journalKey] = jsonEncode(entries.map((e) => e.toJson()).toList());
  }

  /// All entries visible under [privacy], in the journal ordering contract's
  /// total order (newest first, ties broken deterministically by entry id).
  List<JournalEntry> _orderedJournal(PrivacyFilter privacy) {
    final filtered =
        _loadJournal().where((e) => _matchesPrivacy(e, privacy)).toList();
    filtered.sort((a, b) =>
        compareJournalEntriesDescending(a.date, a.id, b.date, b.id));
    return filtered;
  }

  @override
  Future<List<JournalEntry>> getJournal({PrivacyFilter privacy = PrivacyFilter.excludePrivate}) async {
    final decrypted =
        await Future.wait(_orderedJournal(privacy).map(_decryptEntry));
    return decrypted.toList();
  }

  @override
  int journalCount({PrivacyFilter privacy = PrivacyFilter.excludePrivate}) {
    final entries = _loadJournal();
    return entries.where((e) => _matchesPrivacy(e, privacy)).length;
  }

  @override
  Future<void> saveJournalEntry(JournalEntry entry) async {
    final entries = _loadJournal();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    _saveJournal(entries);
  }

  @override
  Future<PagedResult<JournalEntry>> getJournalPage(
    int pageSize, [
    PaginationCursor? cursor,
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  ]) async {
    // Keyset, not offset. This previously advanced by array index, so an entry
    // added or removed between two page fetches shifted the whole window and
    // the next page silently skipped or repeated rows. Resuming from the entry
    // the cursor names is immune to that.
    //
    // Paginate before decrypting: date and id are stored in the clear, so only
    // the entries actually being returned pay the decryption cost.
    final page = paginateByCursor<JournalEntry>(
      _loadJournal().where((e) => _matchesPrivacy(e, privacy)),
      pageSize: pageSize,
      cursor: cursor,
      dateOf: (e) => e.date,
      idOf: (e) => e.id,
    );

    final items = await Future.wait(page.items.map(_decryptEntry));
    return PagedResult(items: items, nextCursor: page.nextCursor);
  }

  @override
  Future<List<JournalEntry>> getOnThisDay(DateTime reference) async {
    final entries = _loadJournal();
    final filtered = entries.where((e) {
      return !e.isPrivate && 
             e.date.month == reference.month && 
             e.date.day == reference.day && 
             e.date.year != reference.year;
    }).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    final entries = _loadJournal();
    entries.removeWhere((e) => e.id == entryId);
    _saveJournal(entries);
  }

  @override
  Future<void> putManyJournalEntries(List<JournalEntry> newEntries) async {
    final entries = _loadJournal();
    for (var entry in newEntries) {
      final idx = entries.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        entries[idx] = entry;
      } else {
        entries.add(entry);
      }
    }
    _saveJournal(entries);
  }

  /// See [StorageService.migrateLegacyEncryptedEntries].
  ///
  /// The web backend persists entries as plain JSON, so only rows written by an
  /// older build that encrypted private entries can carry an envelope.
  @override
  Future<int> migrateLegacyEncryptedEntries() async {
    final stored = _loadJournal();
    var changed = 0;

    final migrated = <JournalEntry>[];
    for (final entry in stored) {
      final needsWork = EncryptionService.looksEncrypted(entry.headline) ||
          EncryptionService.looksEncrypted(entry.content) ||
          EncryptionService.looksEncrypted(entry.feeling ?? '');
      if (!needsWork) {
        migrated.add(entry);
        continue;
      }

      final headline = await EncryptionService().decrypt(entry.headline);
      final content = await EncryptionService().decrypt(entry.content);
      final feeling = entry.feeling == null
          ? null
          : await EncryptionService().decrypt(entry.feeling!);

      // Only rewrite when decryption actually yielded different text; an
      // unreadable value is left exactly as stored.
      if (headline == entry.headline &&
          content == entry.content &&
          (feeling ?? '') == (entry.feeling ?? '')) {
        migrated.add(entry);
        continue;
      }

      migrated.add(entry.copyWith(
        headline: headline,
        content: content,
        feeling: feeling,
      ));
      changed++;
    }

    if (changed > 0) _saveJournal(migrated);
    return changed;
  }

  @override
  Future<Map<String, int>> getTagCounts() async {
    final entries = await getJournal(privacy: PrivacyFilter.excludePrivate);
    final counts = <String, int>{};
    for (final e in entries) {
      for (final tag in e.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<int> renameTag(String from, String to) async {
    final entries = await getJournal(privacy: PrivacyFilter.all);
    final updated = journal_rules.applyTagRename(entries, from, to);
    if (updated.isNotEmpty) {
      await putManyJournalEntries(updated);
    }
    return updated.length;
  }

  @override
  Future<int> deleteTag(String tag) async {
    final entries = await getJournal(privacy: PrivacyFilter.all);
    final updated = journal_rules.applyTagDelete(entries, tag);
    if (updated.isNotEmpty) {
      await putManyJournalEntries(updated);
    }
    return updated.length;
  }

  // ─── Rankings ─────────────────────────────────────────────────────────────

  List<RankingCategory> _loadRankings() {
    final str = html.window.localStorage[_rankingsKey];
    if (str == null || str.isEmpty) {
      _saveRankings(defaultCategories);
      return defaultCategories;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(str);
      return jsonList.map((j) => RankingCategory.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error parsing rankings: $e');
      return defaultCategories;
    }
  }

  void _saveRankings(List<RankingCategory> categories) {
    html.window.localStorage[_rankingsKey] = jsonEncode(categories.map((c) => c.toJson()).toList());
  }

  @override
  Future<List<RankingCategory>> getRankings() async {
    return _loadRankings();
  }

  @override
  Future<List<RankingCategory>> getFavoriteRankings() async {
    return _loadRankings().where((c) => c.isFavorite).toList();
  }

  @override
  Future<void> addRankingCategory(RankingCategory category) async {
    final cats = _loadRankings();
    cats.add(category);
    _saveRankings(cats);
  }

  @override
  Future<void> deleteRankingCategory(String categoryId) async {
    final cats = _loadRankings();
    cats.removeWhere((c) => c.id == categoryId);
    _saveRankings(cats);
  }

  @override
  Future<void> updateRankingCategory(RankingCategory category) async {
    final cats = _loadRankings();
    final idx = cats.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      cats[idx] = category;
      _saveRankings(cats);
    }
  }

  @override
  Future<void> addRankedItem(String categoryId, RankedItem item) async {
    final cats = _loadRankings();
    final idx = cats.indexWhere((c) => c.id == categoryId);
    if (idx >= 0) {
      final items = List<RankedItem>.from(cats[idx].items);
      items.add(item);
      cats[idx] = cats[idx].copyWith(items: items);
      _saveRankings(cats);
    }
  }

  @override
  Future<void> deleteRankedItem(String categoryId, String itemId) async {
    final cats = _loadRankings();
    final idx = cats.indexWhere((c) => c.id == categoryId);
    if (idx >= 0) {
      final items = List<RankedItem>.from(cats[idx].items);
      items.removeWhere((i) => i.id == itemId);
      cats[idx] = cats[idx].copyWith(items: items);
      _saveRankings(cats);
    }
  }

  @override
  Future<void> reorderRankedItems(String categoryId, List<RankedItem> reordered) async {
    final cats = _loadRankings();
    final idx = cats.indexWhere((c) => c.id == categoryId);
    if (idx >= 0) {
      cats[idx] = cats[idx].copyWith(items: reordered);
      _saveRankings(cats);
    }
  }

  // ─── Vision Boards ────────────────────────────────────────────────────────

  List<VisionBoard> _loadVisionBoards() {
    final str = html.window.localStorage[_visionBoardsKey];
    if (str == null || str.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(str);
      return jsonList.map((j) => VisionBoard.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error parsing vision boards: $e');
      return [];
    }
  }

  void _saveVisionBoards(List<VisionBoard> boards) {
    html.window.localStorage[_visionBoardsKey] = jsonEncode(boards.map((b) => b.toJson()).toList());
  }

  @override
  List<VisionBoard> getVisionBoards() {
    return _loadVisionBoards();
  }

  @override
  VisionBoard? getVisionBoardForYear(int year) {
    final boards = _loadVisionBoards();
    try {
      return boards.firstWhere((b) => b.year == year);
    } catch (e) {
      return null;
    }
  }

  @override
  VisionBoard getOrCreateVisionBoard(int year) {
    final existing = getVisionBoardForYear(year);
    if (existing != null) return existing;
    
    final board = VisionBoard(
      id: 'vb_$year',
      year: year,
      createdAt: DateTime.now(),
      items: [],
    );
    final boards = _loadVisionBoards();
    boards.add(board);
    _saveVisionBoards(boards);
    return board;
  }

  @override
  void saveVisionBoard(VisionBoard board) {
    final boards = _loadVisionBoards();
    final idx = boards.indexWhere((b) => b.year == board.year);
    if (idx >= 0) {
      boards[idx] = board;
    } else {
      boards.add(board);
    }
    _saveVisionBoards(boards);
  }

  @override
  void addVisionBoardItem(int year, VisionBoardItem item) {
    final board = getOrCreateVisionBoard(year);
    final items = List<VisionBoardItem>.from(board.items)..add(item);
    saveVisionBoard(board.copyWith(items: items));
  }

  @override
  void updateVisionBoardItem(int year, VisionBoardItem item) {
    final board = getVisionBoardForYear(year);
    if (board != null) {
      final items = List<VisionBoardItem>.from(board.items);
      final idx = items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        items[idx] = item;
        saveVisionBoard(board.copyWith(items: items));
      }
    }
  }

  @override
  void deleteVisionBoardItem(int year, String itemId) {
    final board = getVisionBoardForYear(year);
    if (board != null) {
      final items = List<VisionBoardItem>.from(board.items);
      items.removeWhere((i) => i.id == itemId);
      saveVisionBoard(board.copyWith(items: items));
    }
  }

  @override
  void mergeVisionBoard(VisionBoard imported) {
    final board = getOrCreateVisionBoard(imported.year);
    final existingIds = board.items.map((i) => i.id).toSet();
    final newItems = List<VisionBoardItem>.from(board.items);
    
    for (final item in imported.items) {
      if (!existingIds.contains(item.id)) {
        newItems.add(item);
      }
    }
    saveVisionBoard(board.copyWith(items: newItems));
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  @override
  UserSettings getSettings() {
    final str = html.window.localStorage[_settingsKey];
    if (str == null || str.isEmpty) return const UserSettings();
    try {
      return UserSettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error parsing settings: $e');
      return const UserSettings();
    }
  }

  @override
  Future<UserSettings> saveSettings(UserSettings settings) async {
    html.window.localStorage[_settingsKey] = jsonEncode(settings.toJson());
    return settings;
  }

  // ─── Drafts ─────────────────────────────────────────────────────────────
  
  static const String _draftsPrefix = 'draft_';
  static const String _draftKeysListKey = 'all_draft_keys';

  Future<List<String>> _getDraftKeys() async {
    final str = await _draftStorage.read(key: _draftKeysListKey);
    if (str == null || str.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(str));
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveDraftKeys(List<String> keys) async {
    await _draftStorage.write(key: _draftKeysListKey, value: jsonEncode(keys));
  }

  @override
  Future<void> saveDraft(String draftId, String draftData) async {
    // Failures propagate. This used to swallow every error and return
    // normally, so a draft that was never written looked to the editor exactly
    // like one that was — the caller already handles the failure and tells the
    // user, and it cannot do that for an error it never sees.
    final encryptedData = await EncryptionService().encrypt(draftData);
    await _draftStorage.write(
      key: '$_draftsPrefix$draftId',
      value: encryptedData,
    );

    // Serialised: the id index is a single JSON blob, so a concurrent autosave
    // would otherwise read the same list and clobber the other's id.
    await _draftIndexLock.run(() async {
      final keys = await _getDraftKeys();
      if (keys.contains(draftId)) return;
      await _saveDraftKeys([...keys, draftId]);
    });
  }

  @override
  Future<String?> getDraft(String draftId) async {
    try {
      final encryptedData = await _draftStorage.read(key: '$_draftsPrefix$draftId');
      if (encryptedData == null) return null;
      return await EncryptionService().decrypt(encryptedData);
    } catch (e) {
      debugPrint('Error getting draft on web: $e');
      return null;
    }
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    await _draftStorage.delete(key: '$_draftsPrefix$draftId');
    await _draftIndexLock.run(() async {
      final keys = await _getDraftKeys();
      if (keys.remove(draftId)) {
        await _saveDraftKeys(keys);
      }
    });
  }

  @override
  Future<List<String>> getAllDraftIds() async {
    return await _getDraftKeys();
  }

  @override
  Future<void> clearAllDrafts() async {
    await _draftIndexLock.run(() async {
      final keys = await _getDraftKeys();
      for (final key in keys) {
        await _draftStorage.delete(key: '$_draftsPrefix$key');
      }
      await _draftStorage.delete(key: _draftKeysListKey);
    });
  }

  // ─── On This Day ──────────────────────────────────────────────────────────

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<void> setOnThisDayDismissed(DateTime day) async {
    html.window.localStorage[_onThisDayDismissedKey] = _formatDate(day);
  }

  @override
  Future<bool> isOnThisDayDismissed(DateTime day) async {
    final str = html.window.localStorage[_onThisDayDismissedKey];
    return str == _formatDate(day);
  }
}
