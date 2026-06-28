import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'types.dart';
import '../services/encryption_service.dart';

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
    final plainHeadline = await EncryptionService().decrypt(headline);
    final plainContent = await EncryptionService().decrypt(content);
    final plainFeeling = feeling != null ? await EncryptionService().decrypt(feeling!) : null;

    return toFreezedFromDecrypted({
      'headline': plainHeadline,
      'content': plainContent,
      'feeling': plainFeeling,
    });
  }

  /// Convert ObjectBox entry to JournalEntry using pre-decrypted fields.
  JournalEntry toFreezedFromDecrypted(Map<String, dynamic> decrypted) {
    // Parse images — handle both old List<String> and new List<ImageReference>
    final images = _parseImagesField(imagesJson);

    return JournalEntry(
      id: entryId,
      type: EntryType.values[typeIndex],
      date: date,
      headline: decrypted['headline'] as String? ?? headline,
      content: decrypted['content'] as String? ?? content,
      mood: Mood.values[moodIndex],
      feeling: (decrypted['feeling'] == null || (decrypted['feeling'] as String).isEmpty)
          ? null
          : decrypted['feeling'] as String,
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

  Map<String, dynamic> toRawMap() {
    return {
      'entryId': entryId,
      'headline': headline,
      'content': content,
      'feeling': feeling,
    };
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
class ObjectBoxRankingCategory {
  @Id()
  int id = 0;

  @Unique()
  String categoryId = ''; // Maps to RankingCategory.id

  String title = '';
  String iconName = '';
  bool isFavorite = false;

  /// ARGB accent color; 0 means "use the theme accent".
  int colorValue = 0;

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
      colorValue: colorValue,
    );
  }

  static ObjectBoxRankingCategory fromFreezed(RankingCategory category) {
    return ObjectBoxRankingCategory()
      ..categoryId = category.id
      ..title = category.title
      ..iconName = category.iconName
      ..isFavorite = category.isFavorite
      ..colorValue = category.colorValue
      ..itemsJson = jsonEncode(category.items.map((i) => i.toJson()).toList());
  }
}

@Entity()
class ObjectBoxVisionBoard {
  @Id()
  int id = 0;

  @Unique()
  String boardId = '';

  int year = 0;
  String itemsJson = '[]';

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  VisionBoard toFreezed() {
    final List<dynamic> decoded = jsonDecode(itemsJson);
    final items = decoded
        .map((m) => VisionBoardItem.fromJson(m as Map<String, dynamic>))
        .toList();
    return VisionBoard(
      id: boardId,
      year: year,
      items: items,
      createdAt: createdAt,
    );
  }

  static ObjectBoxVisionBoard fromFreezed(VisionBoard board) {
    return ObjectBoxVisionBoard()
      ..boardId = board.id
      ..year = board.year
      ..itemsJson = jsonEncode(board.items.map((i) => i.toJson()).toList())
      ..createdAt = board.createdAt;
  }
}

@Entity()
class ObjectBoxUserSettings {
  /// Single-row pattern: we always use id = 1.
  @Id()
  int id = 1;

  bool securityEnabled = false;
  bool biometricsEnabled = false;
  String username = 'Architect';
  String theme = 'dark';

  // ── Converters ──────────────────────────────────────────────────────────

  UserSettings toFreezed() => UserSettings(
        securityEnabled: securityEnabled,
        biometricsEnabled: biometricsEnabled,
        username: username,
        theme: theme,
      );

  static ObjectBoxUserSettings fromFreezed(UserSettings settings) {
    return ObjectBoxUserSettings()
      ..securityEnabled = settings.securityEnabled
      ..biometricsEnabled = settings.biometricsEnabled
      ..username = settings.username
      ..theme = settings.theme;
  }
}
