import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../models/objectbox_models.dart';
import '../config/ai_constants.dart';
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
  late final Box<ObjectBoxJournalChunk> _chunkBox;
  late final Box<ObjectBoxEmbeddingJob> _embeddingJobBox;
  late final Box<ObjectBoxAiModel> _aiModelBox;
  late final Box<ObjectBoxAiRuntimeConfig> _aiRuntimeConfigBox;
  late final Box<ObjectBoxRankingCategory> _rankingBox;
  late final Box<ObjectBoxUserSettings> _settingsBox;
  
  // Draft storage - uses default FlutterSecureStorage
  // Key caching is handled in SecurityService
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();

  StorageService(Store store)
      : _journalBox = store.box<ObjectBoxJournalEntry>(),
        _chunkBox = store.box<ObjectBoxJournalChunk>(),
        _embeddingJobBox = store.box<ObjectBoxEmbeddingJob>(),
        _aiModelBox = store.box<ObjectBoxAiModel>(),
        _aiRuntimeConfigBox = store.box<ObjectBoxAiRuntimeConfig>(),
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
    final results = query.find();
    query.close();
    return Future.wait(results.map((e) => e.toFreezed()));
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    final obEntry = await ObjectBoxJournalEntry.fromFreezed(entry);

    // Check if entry with this entryId already exists (update case)
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entry.id))
        .build();
    final existing = query.findFirst();
    query.close();
    if (existing != null) {
      obEntry.id = existing.id; // Preserve ObjectBox ID for update
    }

    _journalBox.put(obEntry);
    await enqueueEmbeddingUpsert(entry.id);
  }

  Future<void> deleteJournalEntry(String entryId) async {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    final existing = query.findFirst();
    query.close();
    if (existing != null) {
      _journalBox.remove(existing.id);
    }
    await enqueueEmbeddingDelete(entryId);
  }

  Future<ObjectBoxJournalEntry?> getJournalEntryById(String entryId) async {
    final query = _journalBox
        .query(ObjectBoxJournalEntry_.entryId.equals(entryId))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Future<void> replaceEntryChunks(
    String entryId,
    List<ObjectBoxJournalChunk> chunks,
  ) async {
    final existingQuery =
        _chunkBox.query(ObjectBoxJournalChunk_.entryId.equals(entryId)).build();
    final existing = existingQuery.find();
    existingQuery.close();

    if (existing.isNotEmpty) {
      _chunkBox.removeMany(existing.map((e) => e.id).toList());
    }

    if (chunks.isNotEmpty) {
      _chunkBox.putMany(chunks);
    }
  }

  Future<void> deleteChunksForEntry(String entryId) async {
    final query =
        _chunkBox.query(ObjectBoxJournalChunk_.entryId.equals(entryId)).build();
    final existing = query.find();
    query.close();
    if (existing.isNotEmpty) {
      _chunkBox.removeMany(existing.map((e) => e.id).toList());
    }
  }

  Future<List<ObjectBoxJournalChunk>> getAllChunks(
      {String? embeddingModelId}) async {
    if (embeddingModelId == null || embeddingModelId.isEmpty) {
      return _chunkBox.getAll();
    }
    final query = _chunkBox
        .query(ObjectBoxJournalChunk_.embeddingModelId.equals(embeddingModelId))
        .build();
    final found = query.find();
    query.close();
    return found;
  }

  Future<List<ObjectWithScore<ObjectBoxJournalChunk>>> findNearestChunks(
    List<double> queryVector, {
    int limit = 8,
    String? embeddingModelId,
  }) async {
    final vectorCond = ObjectBoxJournalChunk_.embedding.nearestNeighborsF32(
      queryVector,
      limit,
    );
    final condition = (embeddingModelId == null || embeddingModelId.isEmpty)
        ? vectorCond
        : (vectorCond &
            ObjectBoxJournalChunk_.embeddingModelId.equals(
              embeddingModelId,
            ));
    final query = _chunkBox.query(condition).build();
    final found = query.findWithScores();
    query.close();
    return found;
  }

  Future<void> enqueueEmbeddingUpsert(String entryId) async {
    await _enqueueEmbeddingJob(entryId, opType: 0);
  }

  Future<void> enqueueEmbeddingDelete(String entryId) async {
    await _enqueueEmbeddingJob(entryId, opType: 1);
  }

  Future<void> _enqueueEmbeddingJob(String entryId,
      {required int opType}) async {
    final query = _embeddingJobBox
        .query(ObjectBoxEmbeddingJob_.entryId.equals(entryId))
        .build();
    final existing = query.find();
    query.close();
    if (existing.isNotEmpty) {
      _embeddingJobBox.removeMany(existing.map((e) => e.id).toList());
    }

    final now = DateTime.now();
    final keySuffix = opType == 1 ? 'delete' : 'upsert';
    _embeddingJobBox.put(
      ObjectBoxEmbeddingJob()
        ..jobKey = '$entryId:$keySuffix'
        ..entryId = entryId
        ..opType = opType
        ..attempts = 0
        ..createdAt = now
        ..updatedAt = now,
    );
  }

  Future<ObjectBoxEmbeddingJob?> getNextEmbeddingJob() async {
    final query = _embeddingJobBox
        .query()
        .order(ObjectBoxEmbeddingJob_.updatedAt)
        .build();
    final candidates = query.find();
    query.close();
    for (final job in candidates) {
      if (job.attempts < AiConstants.embeddingJobMaxAttempts) {
        return job;
      }
      _embeddingJobBox.remove(job.id);
    }
    return null;
  }

  Future<void> completeEmbeddingJob(int id) async {
    _embeddingJobBox.remove(id);
  }

  Future<void> failEmbeddingJob(ObjectBoxEmbeddingJob job, String error) async {
    if (job.id == 0) return;
    if (job.attempts + 1 >= AiConstants.embeddingJobMaxAttempts) {
      _embeddingJobBox.remove(job.id);
      return;
    }
    job
      ..attempts += 1
      ..lastError = error
      ..updatedAt = DateTime.now();
    _embeddingJobBox.put(job);
  }

  Future<void> enqueueReindexAllEntries() async {
    _embeddingJobBox.removeAll();
    final entries = _journalBox.getAll();
    final now = DateTime.now();
    final jobs = <ObjectBoxEmbeddingJob>[];
    for (final entry in entries) {
      jobs.add(
        ObjectBoxEmbeddingJob()
          ..jobKey = '${entry.entryId}:upsert'
          ..entryId = entry.entryId
          ..opType = 0
          ..attempts = 0
          ..createdAt = now
          ..updatedAt = now,
      );
    }
    if (jobs.isNotEmpty) {
      _embeddingJobBox.putMany(jobs);
    }
  }

  // ─── AI Model Registry ──────────────────────────────────────────────────

  Future<List<ObjectBoxAiModel>> getAiModels({int? roleIndex}) async {
    if (roleIndex == null) {
      return _aiModelBox.getAll()
        ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    }
    final query = _aiModelBox
        .query(ObjectBoxAiModel_.roleIndex.equals(roleIndex))
        .build();
    final results = query.find();
    query.close();
    results.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return results;
  }

  Future<ObjectBoxAiModel?> getAiModelById(String modelId) async {
    final query =
        _aiModelBox.query(ObjectBoxAiModel_.modelId.equals(modelId)).build();
    final model = query.findFirst();
    query.close();
    return model;
  }

  Future<ObjectBoxAiModel?> getActiveAiModel(int roleIndex) async {
    final query = _aiModelBox
        .query(
          ObjectBoxAiModel_.roleIndex.equals(roleIndex) &
              ObjectBoxAiModel_.isActive.equals(true),
        )
        .build();
    final model = query.findFirst();
    query.close();
    return model;
  }

  Future<ObjectBoxAiModel> upsertAiModel(ObjectBoxAiModel model) async {
    final existing = await getAiModelById(model.modelId);
    if (existing != null) {
      model.id = existing.id;
    }
    _aiModelBox.put(model);
    return model;
  }

  Future<void> setActiveAiModel({
    required int roleIndex,
    required String modelId,
  }) async {
    final roleQuery = _aiModelBox
        .query(ObjectBoxAiModel_.roleIndex.equals(roleIndex))
        .build();
    final roleModels = roleQuery.find();
    roleQuery.close();

    for (final model in roleModels) {
      model.isActive = model.modelId == modelId;
    }
    if (roleModels.isNotEmpty) {
      _aiModelBox.putMany(roleModels);
    }
  }

  Future<void> deleteAiModel(String modelId) async {
    final existing = await getAiModelById(modelId);
    if (existing != null) {
      _aiModelBox.remove(existing.id);
    }
  }

  Future<void> markAiModelError(String modelId, String? error) async {
    final model = await getAiModelById(modelId);
    if (model == null) return;
    model
      ..isUsable = error == null
      ..lastError = error
      ..updatedAt = DateTime.now();
    _aiModelBox.put(model);
  }

  Future<ObjectBoxAiRuntimeConfig> getAiRuntimeConfig() async {
    final byFixedId = _aiRuntimeConfigBox.get(1);
    if (byFixedId != null) return byFixedId;

    final existing = _aiRuntimeConfigBox.getAll();
    if (existing.isNotEmpty) return existing.first;

    // Let ObjectBox assign an internal ID on first insert.
    final created = ObjectBoxAiRuntimeConfig()..id = 0;
    final id = _aiRuntimeConfigBox.put(created);
    return _aiRuntimeConfigBox.get(id)!;
  }

  Future<void> saveAiRuntimeConfig(ObjectBoxAiRuntimeConfig config) async {
    final existingByFixedId = _aiRuntimeConfigBox.get(1);
    if (existingByFixedId != null) {
      config.id = existingByFixedId.id;
    } else {
      final existing = _aiRuntimeConfigBox.getAll();
      config.id = existing.isNotEmpty ? existing.first.id : 0;
    }
    _aiRuntimeConfigBox.put(config);
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

  // ─── Draft Management ───────────────────────────────────────────────────

  /// Save entry draft for auto-save functionality
  Future<void> saveDraft(String draftId, String draftData) async {
    await _draftStorage.write(key: 'draft_$draftId', value: draftData);
    
    // Track this draft ID for bulk operations
    final existingDrafts = await getAllDraftIds();
    if (!existingDrafts.contains(draftId)) {
      existingDrafts.add(draftId);
      await _draftStorage.write(
        key: '_draft_keys_', 
        value: existingDrafts.join(','),
      );
    }
  }

  /// Get saved draft by ID
  Future<String?> getDraft(String draftId) async {
    return await _draftStorage.read(key: 'draft_$draftId');
  }

  /// Delete draft by ID
  Future<void> deleteDraft(String draftId) async {
    await _draftStorage.delete(key: 'draft_$draftId');
    
    // Remove from tracking
    final existingDrafts = await getAllDraftIds();
    existingDrafts.remove(draftId);
    await _draftStorage.write(
      key: '_draft_keys_', 
      value: existingDrafts.join(','),
    );
  }

  /// Get all draft IDs
  Future<List<String>> getAllDraftIds() async {
    final draftKeysJson = await _draftStorage.read(key: '_draft_keys_');
    if (draftKeysJson == null || draftKeysJson.isEmpty) {
      return [];
    }
    
    try {
      return draftKeysJson.split(',').where((id) => id.isNotEmpty).toList();
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
