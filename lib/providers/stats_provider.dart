import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/stats.dart';
import '../models/types.dart';
import '../services/storage_service.dart';

part 'stats_provider.g.dart';

@riverpod
class StatsNotifier extends _$StatsNotifier {
  @override
  Future<JournalStats> build() async {
    final entries = await ref.read(storageServiceProvider).getJournal();
    return computeStats(entries);
  }

  void invalidate() => ref.invalidateSelf();

  /// Pure, side-effect-free statistics computation over [entries].
  ///
  /// Exposed as `static` so it can be unit/property tested directly without
  /// constructing the Riverpod provider graph (see test/stats_provider_test).
  static JournalStats computeStats(List<JournalEntry> entries) {
    if (entries.isEmpty) return JournalStats.empty;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int totalWordCount = 0;
    double moodSum = 0;
    DateTime? oldestDate;
    final tagFreq = <String, int>{};

    for (final e in entries) {
      totalWordCount += e.content.trim().isEmpty
          ? 0
          : e.content.trim().split(RegExp(r'\s+')).length;
      moodSum += e.mood.index.toDouble();
      final entryDay = DateTime(e.date.year, e.date.month, e.date.day);
      if (oldestDate == null || entryDay.isBefore(oldestDate)) {
        oldestDate = entryDay;
      }
      for (final tag in e.tags) {
        tagFreq[tag] = (tagFreq[tag] ?? 0) + 1;
      }
    }

    final averageMood = moodSum / entries.length;
    final journalAgeInDays = oldestDate == null
        ? 0
        : todayDate.difference(oldestDate).inDays;

    final topTags = (tagFreq.entries.toList()
          ..sort((a, b) {
            final cmp = b.value.compareTo(a.value);
            return cmp != 0 ? cmp : a.key.compareTo(b.key);
          }))
        .take(3)
        .map((e) => e.key)
        .toList();

    return JournalStats(
      streak: _computeStreak(entries, todayDate),
      totalEntries: entries.length,
      averageMood: averageMood,
      totalWordCount: totalWordCount,
      journalAgeInDays: journalAgeInDays,
      topTags: topTags,
    );
  }

  static int _computeStreak(List<JournalEntry> entries, DateTime todayDate) {
    final dates = entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;
    if (dates.first.isBefore(todayDate.subtract(const Duration(days: 1)))) {
      return 0;
    }

    DateTime expected = todayDate;
    if (dates.first == todayDate.subtract(const Duration(days: 1))) {
      expected = dates.first;
    }

    int streak = 0;
    for (final date in dates) {
      if (date == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (date.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }
}
