import 'package:freezed_annotation/freezed_annotation.dart';

part 'types.freezed.dart';
part 'types.g.dart';

enum Mood {
  euphoric,
  happy,
  productive,
  neutral,
  tired,
  sad,
  anxious,
  angry,
  excited,
  relaxed,
  social,
  bored,
  creative,
}

enum TimeBucket { midnight, earlyMorning, morning, afternoon, evening, night }

enum EntryType { story, event }

/// Source type for image references in journal entries.
/// - galleryAsset: Reference by persistent asset ID (photo_manager, no copy)
/// - webUrl: Reference by URL (cached_network_image, auto LRU cache)
/// - filePath: Reference by absolute file path (FileImage, no copy)
enum ImageSourceType { galleryAsset, webUrl, filePath }

/// A reference to an image without duplicating the actual file.
/// Stores only the identifier (asset ID, URL, or file path) and metadata.
@freezed
abstract class ImageReference with _$ImageReference {
  const factory ImageReference({
    /// The source identifier: asset ID, URL string, or absolute file path.
    required String source,
    /// How this image was sourced (determines rendering strategy).
    required ImageSourceType type,
    /// Optional display name or caption.
    String? displayName,
  }) = _ImageReference;

  factory ImageReference.fromJson(Map<String, dynamic> json) =>
      _$ImageReferenceFromJson(json);
}

/// A named place attached to an entry. Coordinate capture (lat/long, maps) was
/// never implemented — the editor only ever recorded a free-text place name —
/// so the unused coordinate fields were removed. Old data / backups that still
/// carry `latitude`/`longitude` keys deserialize fine; those keys are ignored.
@freezed
abstract class LocationData with _$LocationData {
  const factory LocationData({
    required String name,
  }) = _LocationData;

  factory LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);
}

@freezed
abstract class JournalEntry with _$JournalEntry {
  const factory JournalEntry({
    required String id,
    required EntryType type,
    required DateTime date,
    required String headline,
    required String content,
    required Mood mood,
    String? feeling,
    @Default([]) List<String> tags,
    LocationData? location,
    TimeBucket? timeBucket,
    @Default([]) List<ImageReference> images,
    @Default(false) bool isSpotlight,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
}

/// A timestamped rank position, recorded each time an item is manually
/// reordered. Powers "Preference Drift" — how a ranking evolves over time.
@freezed
abstract class RankSnapshot with _$RankSnapshot {
  const factory RankSnapshot({
    required DateTime date,
    required int rank,
  }) = _RankSnapshot;

  factory RankSnapshot.fromJson(Map<String, dynamic> json) =>
      _$RankSnapshotFromJson(json);
}

@freezed
abstract class RankedItem with _$RankedItem {
  const factory RankedItem({
    required String id,
    required int rank,
    required String name,
    @Default(0) double rating, // 0 – 5 star rating
    @Default('') String subtitle, // e.g. director, author, cuisine type
    @Default('') String notes, // free-form personal notes
    required DateTime dateAdded,
    ImageReference? image, // optional cover art (reference-only, like journal)
    @Default([]) List<RankSnapshot> history, // rank-over-time for drift
  }) = _RankedItem;

  factory RankedItem.fromJson(Map<String, dynamic> json) =>
      _$RankedItemFromJson(json);
}

@freezed
abstract class RankingCategory with _$RankingCategory {
  const factory RankingCategory({
    required String id,
    required String title,
    required String iconName,
    @Default([]) List<RankedItem> items,
    @Default(false) bool isFavorite,
    @Default(0) int colorValue, // ARGB accent; 0 = use theme accent
  }) = _RankingCategory;

  factory RankingCategory.fromJson(Map<String, dynamic> json) =>
      _$RankingCategoryFromJson(json);
}

@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default(false) bool securityEnabled,
    @Default(false) bool biometricsEnabled,
    @Default('Architect') String username,
    @Default('dark') String theme,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}
