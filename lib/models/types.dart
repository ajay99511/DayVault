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

@freezed
abstract class LocationData with _$LocationData {
  const factory LocationData({
    required String name,
    required double latitude,
    required double longitude,
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
    @Default([]) List<String> images,
    @Default(false) bool isSpotlight,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
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
  }) = _RankingCategory;

  factory RankingCategory.fromJson(Map<String, dynamic> json) =>
      _$RankingCategoryFromJson(json);
}

@freezed
abstract class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default(false) bool securityEnabled,
    @Default('Architect') String username,
    @Default('dark') String theme,
  }) = _UserSettings;

  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);
}
