import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/main.dart';
import 'package:memory_palace/mock/mock_data_loader.dart';
import 'package:memory_palace/mock/mock_data_repository.dart';
import 'package:memory_palace/mock/mock_dataset.dart';
import 'package:memory_palace/mock/mock_mode_guard.dart';
import 'package:memory_palace/mock/mock_mode_preference.dart';
import 'package:memory_palace/mock/mock_mode_scope.dart';
import 'package:memory_palace/models/paged_result.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/providers/mock_mode_provider.dart';
import 'package:memory_palace/providers/theme_provider.dart';
import 'package:memory_palace/screens/lock_screen.dart';
import 'package:memory_palace/services/storage_service.dart';

/// The isolation contract: demo mode may replace journal **content** and
/// nothing else.
///
/// Each test here corresponds to a way the first implementation leaked, and is
/// the reason the device-level reads were split onto
/// [platformStorageServiceProvider]. Treat a failure here as a security or
/// data-integrity regression, not a cosmetic one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDataset dataset;

  setUpAll(() async {
    dataset = await MockDataLoader().load(now: DateTime.now());
  });

  /// A stand-in for the real on-device backend. Records what gets written to it
  /// so a test can assert demo data never arrives here.
  late _RecordingStorage realStorage;

  setUp(() => realStorage = _RecordingStorage());

  List<Override> overrides({required bool demoEnabled}) => [
        ...mockModeOverrides(
          repository: MockDataRepository.withDataset(dataset),
          initiallyEnabled: demoEnabled,
        ),
        platformStorageServiceProvider.overrideWithValue(realStorage),
        mockModePreferenceProvider
            .overrideWithValue(const _InMemoryPreference()),
      ];

  ProviderContainer containerWith({required bool demoEnabled}) {
    final container =
        ProviderContainer(overrides: overrides(demoEnabled: demoEnabled));
    addTearDown(container.dispose);
    return container;
  }

  group('the app lock cannot be bypassed by demo mode', () {
    testWidgets('LockScreen still gates a PIN-protected install', (tester) async {
      // The original bug: the gate read securityEnabled through
      // storageServiceProvider, so demo mode's `securityEnabled: false`
      // satisfied it. The app opened straight into demo data with no PIN — and
      // the Profile toggle then exposed the real journal, still unlocked.
      realStorage.settings = const UserSettings(securityEnabled: true);

      await tester.pumpWidget(ProviderScope(
        overrides: overrides(demoEnabled: true),
        child: const MaterialApp(home: RootOrchestrator()),
      ));
      await tester.pump();

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });

    testWidgets('an unprotected install still opens straight to the shell',
        (tester) async {
      realStorage.settings = const UserSettings(securityEnabled: false);

      await tester.pumpWidget(ProviderScope(
        overrides: overrides(demoEnabled: true),
        child: const MaterialApp(home: RootOrchestrator()),
      ));
      await tester.pump();

      expect(find.byType(MainShell), findsOneWidget);
    });
  });

  group('device settings stay on real storage', () {
    test('the theme is read from real storage, not the fixtures', () {
      // The fixture settings say 'dark'. If the theme were read through the
      // substitutable provider, entering demo mode would silently override a
      // user who had chosen light.
      realStorage.settings = const UserSettings(theme: 'light');
      final container = containerWith(demoEnabled: true);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('a theme change during a demo persists to real storage', () async {
      realStorage.settings = const UserSettings(theme: 'dark');
      final container = containerWith(demoEnabled: true);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);

      expect(realStorage.settings.theme, 'light');
      // And it must not have carried the fixture profile across with it.
      expect(realStorage.settings.username, isNot(dataset.settings.username));
    });

    test('content settings still follow the active backend', () {
      // The display name is content, so the demo profile is exactly what should
      // show — this is the other half of the split, and it must keep working.
      realStorage.settings = const UserSettings(username: 'Real Person');
      final container = containerWith(demoEnabled: true);

      expect(container.read(storageServiceProvider).getSettings().username,
          dataset.settings.username);
      expect(
          container.read(platformStorageServiceProvider).getSettings().username,
          'Real Person');
    });
  });

  group('real storage is never touched while demo mode is on', () {
    test('journal writes go nowhere near the platform backend', () async {
      final container = containerWith(demoEnabled: true);
      final storage = container.read(storageServiceProvider);

      await storage.saveJournalEntry(JournalEntry(
        id: 'demo-write',
        type: EntryType.story,
        date: DateTime.now(),
        headline: 'Written during a demo',
        content: 'x',
        mood: Mood.happy,
      ));
      await storage.deleteJournalEntry('mock-entry-01');
      await storage.saveSettings(const UserSettings(username: 'Demo Edit'));

      expect(realStorage.writtenEntries, isEmpty);
      expect(realStorage.deletedEntryIds, isEmpty);
      expect(realStorage.settingsWrites, isEmpty);
    });

    test('real entries are invisible while demo mode is on', () async {
      realStorage.entries = [
        JournalEntry(
          id: 'real-entry',
          type: EntryType.story,
          date: DateTime.now(),
          headline: 'A real private thought',
          content: 'x',
          mood: Mood.neutral,
        ),
      ];
      final container = containerWith(demoEnabled: true);

      final visible = await container.read(storageServiceProvider).getJournal();
      expect(visible.map((e) => e.id), isNot(contains('real-entry')));
    });

    test('turning demo mode off returns the real backend untouched', () async {
      realStorage.entries = [
        JournalEntry(
          id: 'real-entry',
          type: EntryType.story,
          date: DateTime.now(),
          headline: 'A real private thought',
          content: 'x',
          mood: Mood.neutral,
        ),
      ];
      final container = containerWith(demoEnabled: true);
      await container
          .read(storageServiceProvider)
          .deleteJournalEntry('real-entry');

      await container.read(mockModeProvider.notifier).setEnabled(false);

      final visible = await container.read(storageServiceProvider).getJournal();
      expect(visible.map((e) => e.id), ['real-entry']);
      expect(realStorage.deletedEntryIds, isEmpty);
    });
  });

  group('device-level code never reads the substitutable provider', () {
    // A source-level check, because this is the rule that is easy to break by
    // habit: `ref.read(storageServiceProvider)` is the idiom everywhere else in
    // the app, and reaching for it in one of these files reintroduces exactly
    // the divergence the split was made to prevent. Behavioural tests cover the
    // paths that exist today; this covers the ones someone adds tomorrow.
    const deviceOnlyFiles = [
      // The app-lock gate and the one-shot real-data migration.
      'lib/main.dart',
      // Sets the real PIN; the matching securityEnabled flag must go with it.
      'lib/screens/pin_setup_screen.dart',
      // Changes/removes the real PIN, biometric enrolment.
      'lib/screens/pin_management_screen.dart',
      // Decides whether to offer biometric unlock.
      'lib/screens/lock_screen.dart',
      // The theme is a device preference.
      'lib/providers/theme_provider.dart',
    ];

    for (final path in deviceOnlyFiles) {
      test('$path uses platformStorageServiceProvider only', () {
        final source = File(path).readAsStringSync();
        final offending = RegExp(r'(?<!platform)[Ss]torageServiceProvider')
            .allMatches(source)
            // Doc comments legitimately name the other provider to explain why.
            .where((m) => !_isInComment(source, m.start))
            .map((m) => m.group(0))
            .toList();

        expect(offending, isEmpty,
            reason: '$path must read device-level settings through '
                'platformStorageServiceProvider. Demo mode substitutes '
                'storageServiceProvider, so using it here lets fabricated '
                'settings answer questions about the real install.');
      });
    }
  });

  group('backup operations are refused during a demo', () {
    // Driven through a tap rather than a build, because the guard reports by
    // showing a SnackBar — which is exactly what a real caller does from an
    // onTap handler, and what cannot be done during a build.
    Widget guardHarness({required bool demoEnabled, required List<bool> calls}) {
      return ProviderScope(
        overrides: overrides(demoEnabled: demoEnabled),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (inner) => TextButton(
                  onPressed: () => calls.add(
                    MockModeGuard.blocks(inner, ref, operation: 'Export'),
                  ),
                  child: const Text('Export'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the guard blocks and explains while demo mode is on',
        (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(guardHarness(demoEnabled: true, calls: calls));
      await tester.tap(find.text('Export'));
      await tester.pump();

      expect(calls, [true]);
      expect(find.textContaining('unavailable while demo data is on'),
          findsOneWidget);
    });

    testWidgets('the guard is transparent while demo mode is off',
        (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(guardHarness(demoEnabled: false, calls: calls));
      await tester.tap(find.text('Export'));
      await tester.pump();

      expect(calls, [false]);
      expect(find.textContaining('unavailable'), findsNothing);
    });
  });
}

/// True when the character at [offset] sits on a `//` comment line.
bool _isInComment(String source, int offset) {
  final lineStart = source.lastIndexOf('\n', offset) + 1;
  return source.substring(lineStart, offset).trimLeft().startsWith('//');
}

class _InMemoryPreference extends MockModePreference {
  const _InMemoryPreference();

  @override
  Future<bool> read() async => false;

  @override
  Future<void> write(bool enabled) async {}
}

/// Minimal in-memory stand-in for the platform backend that records writes.
///
/// Hand-written rather than generated so the recording assertions above read as
/// plain state checks, and so the unimplemented surface fails loudly if a test
/// starts exercising a path it was never meant to.
class _RecordingStorage extends StorageService {
  UserSettings settings = const UserSettings();
  List<JournalEntry> entries = [];

  final List<JournalEntry> writtenEntries = [];
  final List<String> deletedEntryIds = [];
  final List<UserSettings> settingsWrites = [];

  @override
  UserSettings getSettings() => settings;

  @override
  Future<UserSettings> saveSettings(UserSettings next) async {
    settingsWrites.add(next);
    settings = next;
    return next;
  }

  @override
  Future<List<JournalEntry>> getJournal({
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  }) async =>
      entries;

  @override
  int journalCount({PrivacyFilter privacy = PrivacyFilter.excludePrivate}) =>
      entries.length;

  @override
  Future<void> saveJournalEntry(JournalEntry entry) async {
    writtenEntries.add(entry);
    entries.add(entry);
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    deletedEntryIds.add(entryId);
    entries.removeWhere((e) => e.id == entryId);
  }

  @override
  Future<PagedResult<JournalEntry>> getJournalPage(
    int pageSize, [
    PaginationCursor? cursor,
    PrivacyFilter privacy = PrivacyFilter.excludePrivate,
  ]) async =>
      PagedResult(items: entries);

  @override
  Future<List<JournalEntry>> getOnThisDay(DateTime reference) async => const [];

  @override
  Future<void> putManyJournalEntries(List<JournalEntry> batch) async {
    writtenEntries.addAll(batch);
  }

  @override
  Future<int> migrateLegacyEncryptedEntries() async => 0;

  @override
  Future<Map<String, int>> getTagCounts() async => const {};

  @override
  Future<int> renameTag(String from, String to) async => 0;

  @override
  Future<int> deleteTag(String tag) async => 0;

  @override
  Future<List<RankingCategory>> getRankings() async => const [];

  @override
  Future<List<RankingCategory>> getFavoriteRankings() async => const [];

  @override
  Future<void> addRankingCategory(RankingCategory category) async {}

  @override
  Future<void> deleteRankingCategory(String categoryId) async {}

  @override
  Future<void> updateRankingCategory(RankingCategory category) async {}

  @override
  Future<void> addRankedItem(String categoryId, RankedItem item) async {}

  @override
  Future<void> deleteRankedItem(String categoryId, String itemId) async {}

  @override
  Future<void> reorderRankedItems(
      String categoryId, List<RankedItem> reordered) async {}

  @override
  List<VisionBoard> getVisionBoards() => const [];

  @override
  VisionBoard? getVisionBoardForYear(int year) => null;

  @override
  VisionBoard getOrCreateVisionBoard(int year) =>
      VisionBoard(id: 'real-$year', year: year, createdAt: DateTime.now());

  @override
  void saveVisionBoard(VisionBoard board) {}

  @override
  void addVisionBoardItem(int year, VisionBoardItem item) {}

  @override
  void updateVisionBoardItem(int year, VisionBoardItem item) {}

  @override
  void deleteVisionBoardItem(int year, String itemId) {}

  @override
  void mergeVisionBoard(VisionBoard imported) {}

  @override
  Future<void> saveDraft(String draftId, String draftData) async {}

  @override
  Future<String?> getDraft(String draftId) async => null;

  @override
  Future<void> deleteDraft(String draftId) async {}

  @override
  Future<List<String>> getAllDraftIds() async => const [];

  @override
  Future<void> clearAllDrafts() async {}

  @override
  Future<void> setOnThisDayDismissed(DateTime day) async {}

  @override
  Future<bool> isOnThisDayDismissed(DateTime day) async => false;
}
