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

  /// Journal headline — stored as plain text (legacy encrypted data auto-decrypted).
  String headline = '';

  /// Journal content — stored as plain text (legacy encrypted data auto-decrypted).
  String content = '';

  /// Stored as enum index.
  int moodIndex = 0;

  /// User's feeling — stored as plain text (legacy encrypted data auto-decrypted).
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

  /// Convert ObjectBox entry to JournalEntry.
  /// 
  /// Auto-detects and decrypts legacy encrypted data. On next save, the entry
  /// will be stored as plain text automatically.
  Future<JournalEntry> toFreezed() async {
    // Auto-detect and decrypt legacy encrypted data
    final plainHeadline = _maybeDecrypt(headline);
    final plainContent = _maybeDecrypt(content);
    final plainFeeling = feeling != null ? _maybeDecrypt(feeling!) : null;

    // Parse images — handle both old List<String> and new List<ImageReference>
    final images = _parseImagesField(imagesJson);

    return JournalEntry(
      id: entryId,
      type: EntryType.values[typeIndex],
      date: date,
      headline: plainHeadline,
      content: plainContent,
      mood: Mood.values[moodIndex],
      feeling: (plainFeeling == null || plainFeeling.isEmpty)
          ? null
          : plainFeeling,
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

  /// Detect if text is encrypted and decrypt it. Returns original text if plain.
  static String _maybeDecrypt(String text) {
    if (text.isEmpty) return '';

    try {
      // Try to decode as base64 — if it fails, it's plain text
      final bytes = base64Decode(text);

      // Too short for any encryption format → plain text
      if (bytes.length < 17) return text;

      // Check for version byte (1 = XOR, 2 = AES)
      final versionByte = bytes[0];
      if (versionByte != 1 && versionByte != 2) return text;

      // Looks encrypted — use EncryptionService to decrypt
      return EncryptionService().decryptSync(text);
    } catch (_) {
      // Not valid base64 → plain text
      return text;
    }
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

  /// Create ObjectBox entry from JournalEntry — stores as plain text.
  static Future<ObjectBoxJournalEntry> fromFreezed(
    JournalEntry entry,
  ) async {
    return ObjectBoxJournalEntry()
      ..entryId = entry.id
      ..typeIndex = entry.type.index
      ..date = entry.date
      ..headline = entry.headline // Plain text, no encryption
      ..content = entry.content // Plain text, no encryption
      ..moodIndex = entry.mood.index
      ..feeling = entry.feeling // Plain text
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

  /// 0 = local GGUF (llama.cpp), 1 = Android AICore
  /// Default to AICore — GGUF retained as backup only (see GGUF_REFERENCE.md).
  int chatEngineIndex = 1;

  /// 0 = auto, 1 = cpu, 2 = vulkan
  int backendIndex = 0;

  /// If true and AICore is selectable, request model download automatically.
  bool aicoreAutoDownload = true;

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
