/// Canonical locations and root keys of the mock fixture files.
///
/// Every reference to a fixture path goes through here so adding a fixture is
/// a single-file change and a typo is a compile error rather than a runtime
/// "asset not found".
library;

class MockFixtures {
  const MockFixtures._();

  static const String directory = 'assets/mock';

  static const String journalEntries = '$directory/journal_entries.json';
  static const String rankingCategories = '$directory/ranking_categories.json';
  static const String visionBoards = '$directory/vision_boards.json';
  static const String userSettings = '$directory/user_settings.json';

  /// Every fixture the loader reads, in load order. Tests iterate this so a
  /// newly added fixture is covered without editing the test.
  static const List<String> all = [
    journalEntries,
    rankingCategories,
    visionBoards,
    userSettings,
  ];

  // ─── Root keys inside each fixture document ───────────────────────────────

  /// Bumped whenever the fixture *shape* changes in a way a stale checkout
  /// would misread. The loader rejects anything it does not recognise, so a
  /// half-updated fixture fails loudly at load instead of rendering wrong.
  static const String versionKey = 'fixtureVersion';
  static const int supportedVersion = 1;

  static const String entriesKey = 'entries';
  static const String categoriesKey = 'categories';
  static const String boardsKey = 'boards';
  static const String settingsKey = 'settings';
}
