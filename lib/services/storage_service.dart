import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Mock data to start with
final List<JournalEntry> _mockEntries = [];

final List<RankingCategory> _mockCategories = [
  RankingCategory(id: 'movies', title: 'Movies', iconName: 'movie', items: [
    RankedItem(
      id: 'mov1',
      rank: 1,
      name: 'Interstellar',
      rating: 5,
      subtitle: 'Christopher Nolan',
      notes: 'Mind-bending space epic',
      dateAdded: DateTime(2025, 6, 15),
    ),
    RankedItem(
      id: 'mov2',
      rank: 2,
      name: 'The Shawshank Redemption',
      rating: 4.5,
      subtitle: 'Frank Darabont',
      notes: 'A timeless story of hope',
      dateAdded: DateTime(2025, 7, 2),
    ),
  ]),
  const RankingCategory(
      id: 'restaurants',
      title: 'Restaurants',
      iconName: 'restaurant',
      items: []),
  const RankingCategory(
      id: 'places', title: 'Places', iconName: 'place', items: []),
  const RankingCategory(
      id: 'people', title: 'People', iconName: 'person', items: []),
  RankingCategory(id: 'books', title: 'Books', iconName: 'book', items: [
    RankedItem(
      id: 'book1',
      rank: 1,
      name: 'Atomic Habits',
      rating: 4,
      subtitle: 'James Clear',
      notes: 'Great for building systems',
      dateAdded: DateTime(2025, 8, 10),
    ),
  ]),
];

class StorageService {
  UserSettings _settings = const UserSettings(securityEnabled: false);

  Future<List<JournalEntry>> getJournal() async {
    // Simulate delay
    await Future.delayed(const Duration(milliseconds: 100));
    return List.from(_mockEntries)..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    _mockEntries.add(entry);
  }

  Future<List<RankingCategory>> getRankings() async {
    return _mockCategories;
  }

  Future<void> updateRankingCategory(RankingCategory category) async {
    final index = _mockCategories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _mockCategories[index] = category;
    }
  }

  Future<void> addRankedItem(String categoryId, RankedItem item) async {
    final index = _mockCategories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      final cat = _mockCategories[index];
      _mockCategories[index] = cat.copyWith(items: [...cat.items, item]);
    }
  }

  Future<void> deleteRankedItem(String categoryId, String itemId) async {
    final index = _mockCategories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      final cat = _mockCategories[index];
      final updated = cat.items.where((i) => i.id != itemId).toList();
      // Re-rank remaining items sequentially
      final reRanked = [
        for (int i = 0; i < updated.length; i++)
          updated[i].copyWith(rank: i + 1),
      ];
      _mockCategories[index] = cat.copyWith(items: reRanked);
    }
  }

  Future<void> reorderRankedItems(
      String categoryId, List<RankedItem> reordered) async {
    final index = _mockCategories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      // Assign sequential ranks
      final reRanked = [
        for (int i = 0; i < reordered.length; i++)
          reordered[i].copyWith(rank: i + 1),
      ];
      _mockCategories[index] = _mockCategories[index].copyWith(items: reRanked);
    }
  }

  UserSettings getSettings() {
    return _settings;
  }

  Future<UserSettings> saveSettings(UserSettings settings) async {
    _settings = settings;
    return _settings;
  }
}
