// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LocationData _$LocationDataFromJson(Map<String, dynamic> json) =>
    _LocationData(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$LocationDataToJson(_LocationData instance) =>
    <String, dynamic>{
      'name': instance.name,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

_JournalEntry _$JournalEntryFromJson(Map<String, dynamic> json) =>
    _JournalEntry(
      id: json['id'] as String,
      type: $enumDecode(_$EntryTypeEnumMap, json['type']),
      date: DateTime.parse(json['date'] as String),
      headline: json['headline'] as String,
      content: json['content'] as String,
      mood: $enumDecode(_$MoodEnumMap, json['mood']),
      feeling: json['feeling'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      location: json['location'] == null
          ? null
          : LocationData.fromJson(json['location'] as Map<String, dynamic>),
      timeBucket: $enumDecodeNullable(_$TimeBucketEnumMap, json['timeBucket']),
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isSpotlight: json['isSpotlight'] as bool? ?? false,
    );

Map<String, dynamic> _$JournalEntryToJson(_JournalEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$EntryTypeEnumMap[instance.type]!,
      'date': instance.date.toIso8601String(),
      'headline': instance.headline,
      'content': instance.content,
      'mood': _$MoodEnumMap[instance.mood]!,
      'feeling': instance.feeling,
      'tags': instance.tags,
      'location': instance.location,
      'timeBucket': _$TimeBucketEnumMap[instance.timeBucket],
      'images': instance.images,
      'isSpotlight': instance.isSpotlight,
    };

const _$EntryTypeEnumMap = {
  EntryType.story: 'story',
  EntryType.event: 'event',
};

const _$MoodEnumMap = {
  Mood.euphoric: 'euphoric',
  Mood.happy: 'happy',
  Mood.productive: 'productive',
  Mood.neutral: 'neutral',
  Mood.tired: 'tired',
  Mood.sad: 'sad',
  Mood.anxious: 'anxious',
  Mood.angry: 'angry',
  Mood.excited: 'excited',
  Mood.relaxed: 'relaxed',
  Mood.social: 'social',
  Mood.bored: 'bored',
  Mood.creative: 'creative',
};

const _$TimeBucketEnumMap = {
  TimeBucket.midnight: 'midnight',
  TimeBucket.earlyMorning: 'earlyMorning',
  TimeBucket.morning: 'morning',
  TimeBucket.afternoon: 'afternoon',
  TimeBucket.evening: 'evening',
  TimeBucket.night: 'night',
};

_RankedItem _$RankedItemFromJson(Map<String, dynamic> json) => _RankedItem(
      id: json['id'] as String,
      rank: (json['rank'] as num).toInt(),
      name: json['name'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      subtitle: json['subtitle'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      dateAdded: DateTime.parse(json['dateAdded'] as String),
    );

Map<String, dynamic> _$RankedItemToJson(_RankedItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rank': instance.rank,
      'name': instance.name,
      'rating': instance.rating,
      'subtitle': instance.subtitle,
      'notes': instance.notes,
      'dateAdded': instance.dateAdded.toIso8601String(),
    };

_RankingCategory _$RankingCategoryFromJson(Map<String, dynamic> json) =>
    _RankingCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      iconName: json['iconName'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => RankedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$RankingCategoryToJson(_RankingCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'iconName': instance.iconName,
      'items': instance.items,
    };

_UserSettings _$UserSettingsFromJson(Map<String, dynamic> json) =>
    _UserSettings(
      securityEnabled: json['securityEnabled'] as bool? ?? false,
      username: json['username'] as String? ?? 'Architect',
      theme: json['theme'] as String? ?? 'dark',
    );

Map<String, dynamic> _$UserSettingsToJson(_UserSettings instance) =>
    <String, dynamic>{
      'securityEnabled': instance.securityEnabled,
      'username': instance.username,
      'theme': instance.theme,
    };
