class JournalStats {
  final int streak;
  final int totalEntries;
  final double averageMood;
  final int totalWordCount;
  final int journalAgeInDays;
  final List<String> topTags;

  const JournalStats({
    required this.streak,
    required this.totalEntries,
    required this.averageMood,
    required this.totalWordCount,
    required this.journalAgeInDays,
    required this.topTags,
  });

  static const empty = JournalStats(
    streak: 0,
    totalEntries: 0,
    averageMood: -1.0,
    totalWordCount: 0,
    journalAgeInDays: 0,
    topTags: [],
  );
}
