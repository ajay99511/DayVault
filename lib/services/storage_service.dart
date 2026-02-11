
import '../models/types.dart';

// Mock data to start with
final List<JournalEntry> _mockEntries = [];

final List<RankingCategory> _mockCategories = [
  RankingCategory(id: 'movies', title: 'Movies', iconName: 'movie', items: []),
  RankingCategory(id: 'restaurants', title: 'Restaurants', iconName: 'restaurant', items: []),
  RankingCategory(id: 'places', title: 'Places', iconName: 'place', items: []),
  RankingCategory(id: 'people', title: 'People', iconName: 'person', items: []),
  RankingCategory(id: 'books', title: 'Books', iconName: 'book', items: []),
];

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  UserSettings _settings = UserSettings(securityEnabled: false);
  
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

  UserSettings getSettings() {
    return _settings;
  }

  Future<UserSettings> saveSettings(UserSettings settings) async {
    _settings = settings;
    return _settings;
  }
}
