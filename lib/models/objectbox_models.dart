import 'dart:convert';
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

  JournalEntry toFreezed() {
    return JournalEntry(
      id: entryId,
      type: EntryType.values[typeIndex],
      date: date,
      headline: headline,
      content: content,
      mood: Mood.values[moodIndex],
      feeling: feeling,
      tags: List<String>.from(jsonDecode(tagsJson)),
      location: locationJson != null
          ? LocationData.fromJson(
              jsonDecode(locationJson!) as Map<String, dynamic>)
          : null,
      timeBucket:
          timeBucketIndex >= 0 ? TimeBucket.values[timeBucketIndex] : null,
      images: List<String>.from(jsonDecode(imagesJson)),
      isSpotlight: isSpotlight,
    );
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
