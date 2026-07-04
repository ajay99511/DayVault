import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/types.dart';
import '../../models/paged_result.dart';
import 'storage_service_interface.dart';
import '../encryption_service.dart';
import '../security_service.dart';

class WebStorageService extends StorageService {
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();
  
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
      
      return entry.copyWith(
        headline: decryptedHeadline ?? entry.headline,
        content: decryptedContent ?? entry.content,
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

  @override
  Future<List<JournalEntry>> getJournal({PrivacyFilter privacy = PrivacyFilter.excludePrivate}) async {
    final entries = _loadJournal();
    final filtered = entries.where((e) => _matchesPrivacy(e, privacy)).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    final decrypted = await Future.wait(filtered.map((e) => _decryptEntry(e)));
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
    final entries = _loadJournal();
    final filtered = entries.where((e) => _matchesPrivacy(e, privacy)).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    final startIndex = cursor?.lastId ?? 0;
    if (startIndex >= filtered.length) {
      return PagedResult(items: [], nextCursor: null);
    }
    
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    final page = await Future.wait(filtered.sublist(startIndex, endIndex).map((e) => _decryptEntry(e)));
    
    final nextCursor = endIndex < filtered.length ? PaginationCursor.fromLastId(endIndex) : null;
    return PagedResult(items: page.toList(), nextCursor: nextCursor);
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
    final updated = StorageService.applyTagRename(entries, from, to);
    if (updated.isNotEmpty) {
      await putManyJournalEntries(updated);
    }
    return updated.length;
  }

  @override
  Future<int> deleteTag(String tag) async {
    final entries = await getJournal(privacy: PrivacyFilter.all);
    final updated = StorageService.applyTagDelete(entries, tag);
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
    try {
      final encryptedData = await EncryptionService().encrypt(draftData);
      await _draftStorage.write(
        key: '$_draftsPrefix$draftId',
        value: encryptedData,
      );
      
      final keys = await _getDraftKeys();
      if (!keys.contains(draftId)) {
        keys.add(draftId);
        await _saveDraftKeys(keys);
      }
    } catch (e) {
      debugPrint('Error saving draft on web: $e');
    }
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
    final keys = await _getDraftKeys();
    if (keys.remove(draftId)) {
      await _saveDraftKeys(keys);
    }
  }

  @override
  Future<List<String>> getAllDraftIds() async {
    return await _getDraftKeys();
  }

  @override
  Future<void> clearAllDrafts() async {
    final keys = await _getDraftKeys();
    for (final key in keys) {
      await _draftStorage.delete(key: '$_draftsPrefix$key');
    }
    await _draftStorage.delete(key: _draftKeysListKey);
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
