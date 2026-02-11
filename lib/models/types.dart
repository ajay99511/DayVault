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

class LocationData {
  final String name;
  final double latitude;
  final double longitude;

  LocationData({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class JournalEntry {
  final String id;
  final EntryType type;
  final DateTime date;
  final String headline;
  final String content;
  final Mood mood;
  final String? feeling;
  final List<String> tags;
  final LocationData? location;
  final TimeBucket? timeBucket;
  final List<String> images;
  final bool isSpotlight;

  JournalEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.headline,
    required this.content,
    required this.mood,
    this.feeling,
    this.tags = const [],
    this.location,
    this.timeBucket,
    this.images = const [],
    this.isSpotlight = false,
  });
}

class RankedItem {
  final String id;
  final int rank;
  final String name;
  final DateTime dateAdded;

  RankedItem({
    required this.id,
    required this.rank,
    required this.name,
    required this.dateAdded,
  });
}

class RankingCategory {
  final String id;
  final String title;
  final String iconName; // Mapping to Flutter Icons manually
  final List<RankedItem> items;

  RankingCategory({
    required this.id,
    required this.title,
    required this.iconName,
    required this.items,
  });
}

class UserSettings {
  final bool securityEnabled;
  final String username;
  final String theme;

  UserSettings({
    this.securityEnabled = false,
    this.username = 'Architect',
    this.theme = 'dark',
  });
}
