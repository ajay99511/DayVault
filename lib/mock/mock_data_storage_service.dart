import '../domain/journal_rules.dart' as journal_rules;
import '../models/paged_result.dart';
import '../models/types.dart';
import '../services/storage/storage_service_interface.dart';
import 'mock_dataset.dart';

/// A [StorageService] that serves the demo fixtures entirely from memory.
///
/// Two properties define it:
///
/// 1. **It never touches persistent storage.** No ObjectBox store, no
///    localStorage, no secure storage, no files. Demo mode therefore cannot
///    corrupt, overwrite or leak the real journal, and switching back returns
///    that data exactly as it was.
/// 2. **It is fully writable.** Creating, editing, deleting, tagging,
///    reordering and vaulting all behave like the real thing for as long as
///    the process lives, and every trace disappears on restart or on
///    "Reset demo data". That is what makes the demo a usable test bed rather
///    than a read-only screenshot.
///
/// Ordering, pagination and tag semantics are delegated to the same shared
/// helpers the real backends use ([paginateByCursor],
/// [compareJournalEntriesDescending], `domain/journal_rules.dart`) so the demo
/// exercises production logic rather than a lookalike of it.
class MockDataStorageService extends StorageService {
  /// The pristine fixtures. Retained so [reset] can restore them without
  /// re-reading assets.
  final MockDataset source;

  final List<JournalEntry> _entries;
  final List<RankingCategory> _categories;
  final List<VisionBoard> _boards;
  final Map<String, String> _drafts = {};
  final Set<String> _onThisDayDismissals = {};
  UserSettings _settings;

  MockDataStorageService(this.source)
      : _entries = List.of(source.journalEntries),
        _categories = List.of(source.rankingCategories),
        _boards = List.of(source.visionBoards),
        _settings = source.settings;

  /// Discard every in-session change and return to the pristine fixtures.
  void reset() {
    _entries
      ..clear()
      ..addAll(source.journalEntries);
    _categories
      ..clear()
      ..addAll(source.rankingCategories);
    _boards
      ..clear()
      ..addAll(source.visionBoards);
    _drafts.clear();
    _onThisDayDismissals.clear();
    _settings = source.settings;
  }

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

  void _upsert(JournalEntry entry) {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
  }

  // ─── Journal ──────────────────────────────────────────────────────────

  @override
  Future<List<JournalEntry>> getJournal({
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  }) async {
    return _entries.where((e) => _matchesPrivacy(e, privacy)).toList()
      ..sort((a, b) =>
          compareJournalEntriesDescending(a.date, a.id, b.date, b.id));
  }

  @override
  int journalCount({PrivacyFilter privacy = PrivacyFilter.excludePrivate}) =>
      _entries.where((e) => _matchesPrivacy(e, privacy)).length;

  @override
  Future<void> saveJournalEntry(JournalEntry entry) async => _upsert(entry);

  @override
  Future<PagedResult<JournalEntry>> getJournalPage(
    int pageSize, [
    PaginationCursor? cursor,
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  ]) async {
    return paginateByCursor<JournalEntry>(
      _entries.where((e) => _matchesPrivacy(e, privacy)),
      pageSize: pageSize,
      cursor: cursor,
      dateOf: (e) => e.date,
      idOf: (e) => e.id,
    );
  }

  @override
  Future<List<JournalEntry>> getOnThisDay(DateTime reference) async {
    return _entries
        .where((e) =>
            !e.isPrivate &&
            e.date.month == reference.month &&
            e.date.day == reference.day &&
            e.date.year != reference.year)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
  }

  @override
  Future<void> putManyJournalEntries(List<JournalEntry> entries) async {
    for (final entry in entries) {
      _upsert(entry);
    }
  }

  /// No-op: fixtures are authored as plain text and nothing in this backend
  /// ever writes an encryption envelope, so there is never anything to migrate.
  @override
  Future<int> migrateLegacyEncryptedEntries() async => 0;

  // ─── Tags ─────────────────────────────────────────────────────────────

  @override
  Future<Map<String, int>> getTagCounts() async {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final entry in _entries.where((e) => !e.isPrivate)) {
      for (final tag in entry.tags) {
        final label = display.putIfAbsent(tag.toLowerCase(), () => tag);
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<int> renameTag(String from, String to) async {
    final updated = journal_rules.applyTagRename(
      await getJournal(privacy: PrivacyFilter.all),
      from,
      to,
    );
    await putManyJournalEntries(updated);
    return updated.length;
  }

  @override
  Future<int> deleteTag(String tag) async {
    final updated = journal_rules.applyTagDelete(
      await getJournal(privacy: PrivacyFilter.all),
      tag,
    );
    await putManyJournalEntries(updated);
    return updated.length;
  }

  // ─── Rankings ─────────────────────────────────────────────────────────

  @override
  Future<List<RankingCategory>> getRankings() async => List.of(_categories);

  @override
  Future<List<RankingCategory>> getFavoriteRankings() async =>
      _categories.where((c) => c.isFavorite).toList();

  @override
  Future<void> addRankingCategory(RankingCategory category) async {
    _categories.add(category);
  }

  @override
  Future<void> deleteRankingCategory(String categoryId) async {
    _categories.removeWhere((c) => c.id == categoryId);
  }

  @override
  Future<void> updateRankingCategory(RankingCategory category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) _categories[idx] = category;
  }

  @override
  Future<void> addRankedItem(String categoryId, RankedItem item) async {
    _mutateCategory(categoryId, (items) => items..add(item));
  }

  @override
  Future<void> deleteRankedItem(String categoryId, String itemId) async {
    _mutateCategory(
        categoryId, (items) => items..removeWhere((i) => i.id == itemId));
  }

  @override
  Future<void> reorderRankedItems(
    String categoryId,
    List<RankedItem> reordered,
  ) async {
    _mutateCategory(categoryId, (_) => List.of(reordered));
  }

  void _mutateCategory(
    String categoryId,
    List<RankedItem> Function(List<RankedItem> items) mutate,
  ) {
    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx < 0) return;
    final next = mutate(List.of(_categories[idx].items));
    _categories[idx] = _categories[idx].copyWith(items: next);
  }

  // ─── Vision Board ─────────────────────────────────────────────────────

  @override
  List<VisionBoard> getVisionBoards() => List.of(_boards);

  @override
  VisionBoard? getVisionBoardForYear(int year) {
    for (final board in _boards) {
      if (board.year == year) return board;
    }
    return null;
  }

  @override
  VisionBoard getOrCreateVisionBoard(int year) {
    final existing = getVisionBoardForYear(year);
    if (existing != null) return existing;
    final board = VisionBoard(
      id: 'mock-vision-board-$year',
      year: year,
      createdAt: DateTime.now(),
      items: const [],
    );
    _boards.add(board);
    return board;
  }

  @override
  void saveVisionBoard(VisionBoard board) {
    final idx = _boards.indexWhere((b) => b.year == board.year);
    if (idx >= 0) {
      _boards[idx] = board;
    } else {
      _boards.add(board);
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
    final items = List.of(board.items);
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx < 0) return;
    items[idx] = item;
    saveVisionBoard(board.copyWith(items: items));
  }

  @override
  void deleteVisionBoardItem(int year, String itemId) {
    final board = getVisionBoardForYear(year);
    if (board == null) return;
    final items = List.of(board.items)..removeWhere((i) => i.id == itemId);
    saveVisionBoard(board.copyWith(items: items));
  }

  @override
  void mergeVisionBoard(VisionBoard imported) {
    final board = getOrCreateVisionBoard(imported.year);
    final existingIds = board.items.map((i) => i.id).toSet();
    final merged = [
      ...board.items,
      ...imported.items.where((i) => !existingIds.contains(i.id)),
    ];
    saveVisionBoard(board.copyWith(items: merged));
  }

  // ─── Settings ─────────────────────────────────────────────────────────

  @override
  UserSettings getSettings() => _settings;

  @override
  Future<UserSettings> saveSettings(UserSettings settings) async {
    _settings = settings;
    return settings;
  }

  // ─── Drafts ───────────────────────────────────────────────────────────

  @override
  Future<void> saveDraft(String draftId, String draftData) async {
    _drafts[draftId] = draftData;
  }

  @override
  Future<String?> getDraft(String draftId) async => _drafts[draftId];

  @override
  Future<void> deleteDraft(String draftId) async {
    _drafts.remove(draftId);
  }

  @override
  Future<List<String>> getAllDraftIds() async => _drafts.keys.toList();

  @override
  Future<void> clearAllDrafts() async => _drafts.clear();

  // ─── "On this day" banner dismissal ───────────────────────────────────

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<void> setOnThisDayDismissed(DateTime day) async {
    _onThisDayDismissals.add(_dayKey(day));
  }

  @override
  Future<bool> isOnThisDayDismissed(DateTime day) async =>
      _onThisDayDismissals.contains(_dayKey(day));
}
