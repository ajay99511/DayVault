import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../models/objectbox_models.dart';
import '../objectbox.g.dart';
import 'objectbox_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ObjectBoxService.instance.store);
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
  late final Box<ObjectBoxJournalEntry> _journalBox;
  late final Box<ObjectBoxRankingCategory> _rankingBox;
  late final Box<ObjectBoxUserSettings> _settingsBox;
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();

  StorageService(Store store)
      : _journalBox = store.box<ObjectBoxJournalEntry>(),
        _rankingBox = store.box<ObjectBoxRankingCategory>(),
        _settingsBox = store.box<ObjectBoxUserSettings>();

  // ─── Journal ────────────────────────────────────────────────────────────

  Future<List<JournalEntry>> getJournal() async {
    // Query all entries, sort by date descending
    final query = _journalBox
        .query()
        .order(ObjectBoxJournalEntry_.date, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    return results.map((e) => e.toFreezed()).toList();
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    final obEntry = await ObjectBoxJournalEntry.fromFreezed(entry);

    // Check if entry with this entryId already exists (update case)
    final existing = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entry.id))
        .build()
        .findFirst();
    if (existing != null) {
      obEntry.id = existing.id; // Preserve ObjectBox ID for update
    }

    _journalBox.put(obEntry);
  }

  Future<void> deleteJournalEntry(String entryId) async {
    final existing = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build()
        .findFirst();
    if (existing != null) {
      _journalBox.remove(existing.id);
    }
  }

  // ─── Rankings ───────────────────────────────────────────────────────────

  Future<List<RankingCategory>> getFavoriteRankings() async {
    final query = _rankingBox
        .query(ObjectBoxRankingCategory_.isFavorite.equals(true))
        .build();
    final results = query.find();
    query.close();
    return results.map((c) => c.toFreezed()).toList();
  }

  Future<List<RankingCategory>> getRankings() async {
    var results = _rankingBox.getAll();

    // First-launch: seed default empty categories
    if (results.isEmpty) {
      for (final cat in _defaultCategories) {
        _rankingBox.put(ObjectBoxRankingCategory.fromFreezed(cat));
      }
      results = _rankingBox.getAll();
    }

    return results.map((c) => c.toFreezed()).toList();
  }

  Future<void> addRankingCategory(RankingCategory category) async {
    final existing = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(category.id))
        .build()
        .findFirst();

    final obCategory = ObjectBoxRankingCategory.fromFreezed(category);
    if (existing != null) {
      obCategory.id = existing.id;
    }
    _rankingBox.put(obCategory);
  }

  Future<void> deleteRankingCategory(String categoryId) async {
    final existing = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build()
        .findFirst();
    if (existing != null) {
      _rankingBox.remove(existing.id);
    }
  }

  Future<void> updateRankingCategory(RankingCategory category) async {
    final existing = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(category.id))
        .build()
        .findFirst();
    if (existing == null) return;

    final updated = ObjectBoxRankingCategory.fromFreezed(category)
      ..id = existing.id;
    _rankingBox.put(updated);
  }

  Future<void> addRankedItem(String categoryId, RankedItem item) async {
    final existing = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build()
        .findFirst();
    if (existing == null) return;

    final cat = existing.toFreezed();
    final updatedCat = cat.copyWith(items: [...cat.items, item]);

    final updated = ObjectBoxRankingCategory.fromFreezed(updatedCat)
      ..id = existing.id;
    _rankingBox.put(updated);
  }

  Future<void> deleteRankedItem(String categoryId, String itemId) async {
    final existing = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build()
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

    final updated = ObjectBoxRankingCategory.fromFreezed(updatedCat)
      ..id = existing.id;
    _rankingBox.put(updated);
  }

  Future<void> reorderRankedItems(
      String categoryId, List<RankedItem> reordered) async {
    final existing = _rankingBox
        .query(ObjectBoxRankingCategory_.categoryId.equals(categoryId))
        .build()
        .findFirst();
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
  }

  // ─── Settings ───────────────────────────────────────────────────────────

  UserSettings getSettings() {
    final existing = _settingsBox.get(1);
    if (existing == null) {
      return const UserSettings(); // Defaults from Freezed
    }
    return existing.toFreezed();
  }

  Future<UserSettings> saveSettings(UserSettings settings) async {
    final obSettings = ObjectBoxUserSettings.fromFreezed(settings);
    _settingsBox.put(obSettings);
    return settings;
  }

  // ─── Draft Management ───────────────────────────────────────────────────

  /// Save entry draft for auto-save functionality
  Future<void> saveDraft(String draftId, String draftData) async {
    await _draftStorage.write(key: 'draft_$draftId', value: draftData);
  }

  /// Get saved draft by ID
  Future<String?> getDraft(String draftId) async {
    return await _draftStorage.read(key: 'draft_$draftId');
  }

  /// Delete draft by ID
  Future<void> deleteDraft(String draftId) async {
    await _draftStorage.delete(key: 'draft_$draftId');
  }

  /// Get all draft IDs
  Future<List<String>> getAllDraftIds() async {
    final drafts = <String>[];
    // Read all keys and filter for draft keys
    // Note: flutter_secure_storage doesn't have a getAllKeys method,
    // so we track draft IDs separately if needed
    return drafts;
  }

  /// Clear all drafts (useful after successful save or user logout)
  Future<void> clearAllDrafts() async {
    // Implementation depends on tracking draft IDs
    // For now, drafts are cleared individually after save
  }
}
