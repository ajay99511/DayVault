import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../models/isar_models.dart';
import 'isar_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(IsarService.instance.isar);
});

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

class StorageService {
  final Isar _isar;

  StorageService(this._isar);

  // ─── Journal ────────────────────────────────────────────────────────────

  Future<List<JournalEntry>> getJournal() async {
    final results =
        await _isar.isarJournalEntrys.where().sortByDateDesc().findAll();
    return results.map((e) => e.toFreezed()).toList();
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    final isarEntry = IsarJournalEntry.fromFreezed(entry);
    await _isar.writeTxn(() => _isar.isarJournalEntrys.put(isarEntry));
  }

  // ─── Rankings ───────────────────────────────────────────────────────────

  Future<List<RankingCategory>> getRankings() async {
    var results = await _isar.isarRankingCategorys.where().findAll();

    // First-launch: seed default empty categories
    if (results.isEmpty) {
      await _isar.writeTxn(() async {
        for (final cat in _defaultCategories) {
          await _isar.isarRankingCategorys
              .put(IsarRankingCategory.fromFreezed(cat));
        }
      });
      results = await _isar.isarRankingCategorys.where().findAll();
    }

    return results.map((c) => c.toFreezed()).toList();
  }

  Future<void> updateRankingCategory(RankingCategory category) async {
    final existing = await _isar.isarRankingCategorys
        .filter()
        .categoryIdEqualTo(category.id)
        .findFirst();
    if (existing == null) return;

    final updated = IsarRankingCategory.fromFreezed(category)
      ..isarId = existing.isarId;
    await _isar.writeTxn(() => _isar.isarRankingCategorys.put(updated));
  }

  Future<void> addRankedItem(String categoryId, RankedItem item) async {
    final existing = await _isar.isarRankingCategorys
        .filter()
        .categoryIdEqualTo(categoryId)
        .findFirst();
    if (existing == null) return;

    final cat = existing.toFreezed();
    final updatedCat = cat.copyWith(items: [...cat.items, item]);

    final updated = IsarRankingCategory.fromFreezed(updatedCat)
      ..isarId = existing.isarId;
    await _isar.writeTxn(() => _isar.isarRankingCategorys.put(updated));
  }

  Future<void> deleteRankedItem(String categoryId, String itemId) async {
    final existing = await _isar.isarRankingCategorys
        .filter()
        .categoryIdEqualTo(categoryId)
        .findFirst();
    if (existing == null) return;

    final cat = existing.toFreezed();
    final filtered = cat.items.where((i) => i.id != itemId).toList();
    // Re-rank remaining items sequentially
    final reRanked = [
      for (int i = 0; i < filtered.length; i++)
        filtered[i].copyWith(rank: i + 1),
    ];
    final updatedCat = cat.copyWith(items: reRanked);

    final updated = IsarRankingCategory.fromFreezed(updatedCat)
      ..isarId = existing.isarId;
    await _isar.writeTxn(() => _isar.isarRankingCategorys.put(updated));
  }

  Future<void> reorderRankedItems(
      String categoryId, List<RankedItem> reordered) async {
    final existing = await _isar.isarRankingCategorys
        .filter()
        .categoryIdEqualTo(categoryId)
        .findFirst();
    if (existing == null) return;

    // Assign sequential ranks
    final reRanked = [
      for (int i = 0; i < reordered.length; i++)
        reordered[i].copyWith(rank: i + 1),
    ];
    final updatedCat = existing.toFreezed().copyWith(items: reRanked);

    final updated = IsarRankingCategory.fromFreezed(updatedCat)
      ..isarId = existing.isarId;
    await _isar.writeTxn(() => _isar.isarRankingCategorys.put(updated));
  }

  // ─── Settings ───────────────────────────────────────────────────────────

  UserSettings getSettings() {
    final existing = _isar.isarUserSettings.getSync(1);
    if (existing == null) {
      return const UserSettings(); // Defaults from Freezed
    }
    return existing.toFreezed();
  }

  Future<UserSettings> saveSettings(UserSettings settings) async {
    final isarSettings = IsarUserSettings.fromFreezed(settings);
    await _isar.writeTxn(() => _isar.isarUserSettings.put(isarSettings));
    return settings;
  }
}
