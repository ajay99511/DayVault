import 'package:isar/isar.dart';
import 'types.dart';

part 'isar_models.g.dart';

// ─── Embedded Objects ────────────────────────────────────────────────────────

@embedded
class IsarLocationData {
  late String name;
  late double latitude;
  late double longitude;

  IsarLocationData();

  LocationData toFreezed() => LocationData(
        name: name,
        latitude: latitude,
        longitude: longitude,
      );

  static IsarLocationData fromFreezed(LocationData data) {
    return IsarLocationData()
      ..name = data.name
      ..latitude = data.latitude
      ..longitude = data.longitude;
  }
}

@embedded
class IsarRankedItem {
  late String itemId; // Avoiding 'id' since Isar uses Id type on collections
  late int rank;
  late String name;
  late double rating;
  late String subtitle;
  late String notes;
  late int dateAddedMs; // Stored as epoch millis

  IsarRankedItem();

  RankedItem toFreezed() => RankedItem(
        id: itemId,
        rank: rank,
        name: name,
        rating: rating,
        subtitle: subtitle,
        notes: notes,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(dateAddedMs),
      );

  static IsarRankedItem fromFreezed(RankedItem item) {
    return IsarRankedItem()
      ..itemId = item.id
      ..rank = item.rank
      ..name = item.name
      ..rating = item.rating
      ..subtitle = item.subtitle
      ..notes = item.notes
      ..dateAddedMs = item.dateAdded.millisecondsSinceEpoch;
  }
}

// ─── Collections ─────────────────────────────────────────────────────────────

@Collection()
class IsarJournalEntry {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String entryId; // Maps to JournalEntry.id

  @enumerated
  late EntryType type;

  late DateTime date;

  late String headline;
  late String content;

  @enumerated
  late Mood mood;

  String? feeling;

  late List<String> tags;

  IsarLocationData? location;

  @enumerated
  TimeBucket? timeBucket;

  late List<String> images;

  late bool isSpotlight;

  JournalEntry toFreezed() => JournalEntry(
        id: entryId,
        type: type,
        date: date,
        headline: headline,
        content: content,
        mood: mood,
        feeling: feeling,
        tags: tags,
        location: location?.toFreezed(),
        timeBucket: timeBucket,
        images: images,
        isSpotlight: isSpotlight,
      );

  static IsarJournalEntry fromFreezed(JournalEntry entry) {
    return IsarJournalEntry()
      ..entryId = entry.id
      ..type = entry.type
      ..date = entry.date
      ..headline = entry.headline
      ..content = entry.content
      ..mood = entry.mood
      ..feeling = entry.feeling
      ..tags = entry.tags
      ..location = entry.location != null
          ? IsarLocationData.fromFreezed(entry.location!)
          : null
      ..timeBucket = entry.timeBucket
      ..images = entry.images
      ..isSpotlight = entry.isSpotlight;
  }
}

@Collection()
class IsarRankingCategory {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String categoryId; // Maps to RankingCategory.id

  late String title;
  late String iconName;

  late List<IsarRankedItem> items;

  RankingCategory toFreezed() => RankingCategory(
        id: categoryId,
        title: title,
        iconName: iconName,
        items: items.map((i) => i.toFreezed()).toList(),
      );

  static IsarRankingCategory fromFreezed(RankingCategory category) {
    return IsarRankingCategory()
      ..categoryId = category.id
      ..title = category.title
      ..iconName = category.iconName
      ..items =
          category.items.map((i) => IsarRankedItem.fromFreezed(i)).toList();
  }
}

@Collection()
class IsarUserSettings {
  // Single-row pattern: always use id = 1
  Id isarId = 1;

  late bool securityEnabled;
  late String username;
  late String theme;

  UserSettings toFreezed() => UserSettings(
        securityEnabled: securityEnabled,
        username: username,
        theme: theme,
      );

  static IsarUserSettings fromFreezed(UserSettings settings) {
    return IsarUserSettings()
      ..securityEnabled = settings.securityEnabled
      ..username = settings.username
      ..theme = settings.theme;
  }
}
