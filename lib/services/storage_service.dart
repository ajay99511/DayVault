import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../models/objectbox_models.dart';
import '../objectbox.g.dart';
import 'objectbox_service.dart';
import 'encryption_service.dart';
import 'security_service.dart';
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

  // Draft storage - uses default FlutterSecureStorage
  // Key caching is handled in SecurityService
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();

  StorageService(Store store)
      : _journalBox = store.box<ObjectBoxJournalEntry>(),
        _rankingBox = store.box<ObjectBoxRankingCategory>(),
        _settingsBox = store.box<ObjectBoxUserSettings>();

  // ─── Journal ────────────────────────────────────────────────────────────

  /// Get all journal entries.
  /// 
  /// Existing encrypted entries are auto-detected and decrypted during
  /// conversion. New entries are stored as plain text.
  Future<List<JournalEntry>> getJournal() async {
    final query = _journalBox
        .query()
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

  Future<void> deleteJournalEntry(String entryId) async {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null) {
        _journalBox.remove(existing.id);
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
