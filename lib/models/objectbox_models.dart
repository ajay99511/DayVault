import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'types.dart';
import '../services/encryption_service.dart';
import '../config/ai_constants.dart';

// ─── Entities ────────────────────────────────────────────────────────────────

@Entity()
class ObjectBoxJournalEntry {
  @Id()
  int id = 0;

  @Unique()
  String entryId = ''; // Maps to JournalEntry.id

  /// Stored as enum index.
  int typeIndex = 0;

  @Property(type: PropertyType.date)
  DateTime date = DateTime.now();

  /// Encrypted field - headline
  String headline = '';

  /// Encrypted field - content
  String content = '';

  /// Stored as enum index.
  int moodIndex = 0;

  /// Encrypted field - feeling
  String? feeling;

  /// Tags stored as JSON-encoded list.
  String tagsJson = '[]';

  /// Location stored as JSON-encoded map (nullable).
  String? locationJson;

  /// Stored as enum index (nullable → -1 means null).
  int timeBucketIndex = -1;

  /// Images stored as JSON-encoded list.
  String imagesJson = '[]';

  bool isSpotlight = false;

  // ── Converters ──────────────────────────────────────────────────────────

  Future<JournalEntry> toFreezed() async {
    final encryptionService = EncryptionService();
    final decryptedHeadline = await encryptionService.decrypt(headline);
    final decryptedContent = await encryptionService.decrypt(content);
    final decryptedFeeling =
        feeling != null ? await encryptionService.decrypt(feeling) : null;

    // Parse images — handle both old List<String> and new List<ImageReference>
    final images = _parseImagesField(imagesJson);

    return JournalEntry(
      id: entryId,
      type: EntryType.values[typeIndex],
      date: date,
      headline: decryptedHeadline,
      content: decryptedContent,
      mood: Mood.values[moodIndex],
      feeling: (decryptedFeeling == null || decryptedFeeling.isEmpty)
          ? null
          : decryptedFeeling,
      tags: List<String>.from(jsonDecode(tagsJson)),
      location: locationJson != null
          ? LocationData.fromJson(
              jsonDecode(locationJson!) as Map<String, dynamic>)
          : null,
      timeBucket:
          timeBucketIndex >= 0 ? TimeBucket.values[timeBucketIndex] : null,
      images: images,
      isSpotlight: isSpotlight,
    );
  }

  /// Parse images handling backward compatibility:
  /// - New format: List<ImageReference> JSON
  /// - Old format: List<String> (file paths) → converted to ImageReference(filePath)
  static List<ImageReference> _parseImagesField(String imagesJson) {
    try {
      final decoded = jsonDecode(imagesJson);
      if (decoded is List) {
        if (decoded.isEmpty) return [];

        final first = decoded.first;
        if (first is Map && first.containsKey('source')) {
          // New format: ImageReference objects
          return decoded
              .map((m) => ImageReference.fromJson(m as Map<String, dynamic>))
              .toList();
        } else if (first is String) {
          // Old format: plain file paths
          return decoded
              .map((path) => ImageReference(
                    source: path as String,
                    type: ImageSourceType.filePath,
                  ))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Failed to parse imagesJson: $e');
      return [];
    }
  }

  static Future<ObjectBoxJournalEntry> fromFreezed(
    JournalEntry entry,
  ) async {
    final encryptionService = EncryptionService();

    // Encrypt sensitive fields
    final encryptedHeadline = await encryptionService.encrypt(entry.headline);
    final encryptedContent = await encryptionService.encrypt(entry.content);
    final encryptedFeeling = entry.feeling != null
        ? await encryptionService.encrypt(entry.feeling!)
        : null;

    return ObjectBoxJournalEntry()
      ..entryId = entry.id
      ..typeIndex = entry.type.index
      ..date = entry.date
      ..headline = encryptedHeadline ?? entry.headline
      ..content = encryptedContent ?? entry.content
      ..moodIndex = entry.mood.index
      ..feeling = encryptedFeeling
      ..tagsJson = jsonEncode(entry.tags)
      ..locationJson =
          entry.location != null ? jsonEncode(entry.location!.toJson()) : null
      ..timeBucketIndex = entry.timeBucket?.index ?? -1
      ..imagesJson = jsonEncode(entry.images)
      ..isSpotlight = entry.isSpotlight;
  }
}

@Entity()
class ObjectBoxJournalChunk {
  @Id()
  int id = 0;

  @Unique()
  String chunkId = ''; // `${entryId}:${chunkIndex}:${modelIdHash}`

  @Index()
  String entryId = '';

  int chunkIndex = 0;
  int tokenEstimate = 0;

  /// Encrypted chunk text (at-rest privacy).
  String chunkText = '';

  String embeddingModelId = AiConstants.embeddingModelId;

  @Property(type: PropertyType.floatVector)
  @HnswIndex(
    dimensions: AiConstants.embeddingDimensions,
    distanceType: VectorDistanceType.cosine,
    vectorCacheHintSizeKB: AiConstants.vectorCacheHintSizeKB,
  )
  List<double> embedding = const [];

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();
}

@Entity()
class ObjectBoxEmbeddingJob {
  @Id()
  int id = 0;

  @Unique()
  String jobKey = ''; // `${entryId}:upsert|delete`

  String entryId = '';
  int opType = 0; // 0 = upsert, 1 = delete
  int attempts = 0;
  String? lastError;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();
}

@Entity()
class ObjectBoxAiModel {
  @Id()
  int id = 0;

  @Unique()
  String modelId = '';

  /// 0 = chat, 1 = embedding
  int roleIndex = 0;

  String displayName = '';
  String filePath = '';
  String checksum = '';
  int fileSizeBytes = 0;
  bool isActive = false;
  bool isUsable = true;
  String? lastError;

  @Property(type: PropertyType.date)
  DateTime importedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();
}

@Entity()
class ObjectBoxAiRuntimeConfig {
  /// Single-row pattern: we always use id = 1.
  @Id()
  int id = 1;

  /// 0 = auto, 1 = cpu, 2 = vulkan
  int backendIndex = 0;

  bool autoPolicy = true;
  bool pauseEmbeddingOnLowBattery = true;
  int lowBatteryThreshold = 20;

  /// 0 means auto-tuned by device profile.
  int forcedContextSize = 0;
  int forcedThreads = 0;

  /// -1 means auto, 0 means CPU-only.
  int forcedGpuLayers = -1;

  int maxGenerationTokens = AiConstants.chatMaxOutputTokens;
}

@Entity()
class ObjectBoxRankingCategory {
  @Id()
  int id = 0;

  @Unique()
  String categoryId = ''; // Maps to RankingCategory.id

  String title = '';
  String iconName = '';
  bool isFavorite = false;

  /// Items stored as JSON-encoded list of RankedItem maps.
  String itemsJson = '[]';

  // ── Converters ──────────────────────────────────────────────────────────

  RankingCategory toFreezed() {
    final List<dynamic> decoded = jsonDecode(itemsJson);
    final items = decoded
        .map((m) => RankedItem.fromJson(m as Map<String, dynamic>))
        .toList();

    return RankingCategory(
      id: categoryId,
      title: title,
      iconName: iconName,
      items: items,
      isFavorite: isFavorite,
    );
  }

  static ObjectBoxRankingCategory fromFreezed(RankingCategory category) {
    return ObjectBoxRankingCategory()
      ..categoryId = category.id
      ..title = category.title
      ..iconName = category.iconName
      ..isFavorite = category.isFavorite
      ..itemsJson = jsonEncode(category.items.map((i) => i.toJson()).toList());
  }
}

@Entity()
class ObjectBoxUserSettings {
  /// Single-row pattern: we always use id = 1.
  @Id()
  int id = 1;

  bool securityEnabled = false;
  String username = 'Architect';
  String theme = 'dark';

  // ── Converters ──────────────────────────────────────────────────────────

  UserSettings toFreezed() => UserSettings(
        securityEnabled: securityEnabled,
        username: username,
        theme: theme,
      );

  static ObjectBoxUserSettings fromFreezed(UserSettings settings) {
    return ObjectBoxUserSettings()
      ..securityEnabled = settings.securityEnabled
      ..username = settings.username
      ..theme = settings.theme;
  }
}
