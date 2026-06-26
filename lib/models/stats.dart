import 'types.dart';

class JournalStats {
  final int streak;
  final int totalEntries;

  /// The single most frequently recorded mood across all entries. Null when
  /// there are no entries. (Replaces a former mean-of-enum-index "average mood",
  /// which was meaningless because the [Mood] enum order is not a valence scale.)
  final Mood? mostFrequentMood;
  final int totalWordCount;
  final int journalAgeInDays;
  final List<String> topTags;

  const JournalStats({
    required this.streak,
    required this.totalEntries,
    required this.mostFrequentMood,
    required this.totalWordCount,
    required this.journalAgeInDays,
    required this.topTags,
  });

  static const empty = JournalStats(
    streak: 0,
    totalEntries: 0,
    mostFrequentMood: null,
    totalWordCount: 0,
    journalAgeInDays: 0,
    topTags: [],
  );
}
