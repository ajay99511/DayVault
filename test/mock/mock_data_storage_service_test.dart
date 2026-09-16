import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/mock/mock_data_loader.dart';
import 'package:memory_palace/mock/mock_data_repository.dart';
import 'package:memory_palace/mock/mock_data_storage_service.dart';
import 'package:memory_palace/mock/mock_dataset.dart';
import 'package:memory_palace/mock/mock_mode_scope.dart';
import 'package:memory_palace/models/paged_result.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/providers/journal_revision_provider.dart';
import 'package:memory_palace/providers/mock_mode_provider.dart';
import 'package:memory_palace/services/storage_service.dart';

/// The demo backend has to behave like the real ones — the whole point is that
/// the app cannot tell the difference — and it has to stay entirely in memory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final referenceNow = DateTime(2026, 6, 15, 12);
  late MockDataset dataset;

  setUpAll(() async {
    dataset = await MockDataLoader().load(now: referenceNow);
  });

  MockDataStorageService service() => MockDataStorageService(dataset);

  group('reads', () {
    test('the feed excludes private entries by default', () async {
      final entries = await service().getJournal();
      expect(entries, hasLength(16));
      expect(entries.every((e) => !e.isPrivate), isTrue);
    });

    test('the vault filter returns only private entries', () async {
      final entries =
          await service().getJournal(privacy: PrivacyFilter.onlyPrivate);
      expect(entries, isNotEmpty);
      expect(entries.every((e) => e.isPrivate), isTrue);
    });

    test('entries come back newest first', () async {
      final entries = await service().getJournal();
      for (var i = 1; i < entries.length; i++) {
        expect(entries[i - 1].date.isBefore(entries[i].date), isFalse);
      }
    });

    test('journalCount agrees with getJournal under each filter', () async {
      final s = service();
      for (final filter in PrivacyFilter.values) {
        expect(s.journalCount(privacy: filter),
            (await s.getJournal(privacy: filter)).length);
      }
    });

    test('pagination walks the whole feed exactly once', () async {
      // Keyset pagination is shared with the real backends; this checks the
      // demo data is actually paginable (no duplicate ids, nothing skipped).
      final s = service();
      final seen = <String>[];
      PaginationCursor? cursor;
      do {
        final page = await s.getJournalPage(5, cursor);
        seen.addAll(page.items.map((e) => e.id));
        cursor = page.nextCursor;
      } while (cursor != null);

      expect(seen, hasLength(16));
      expect(seen.toSet(), hasLength(16));
    });

    test('"on this day" surfaces the past-year entries', () async {
      final memories = await service().getOnThisDay(referenceNow);
      expect(memories, hasLength(2));
      expect(memories.every((e) => e.date.year != referenceNow.year), isTrue);
      // Most recent first.
      expect(memories.first.date.isAfter(memories.last.date), isTrue);
    });

    test('tag counts cover only the feed, never the vault', () async {
      final counts = await service().getTagCounts();
      expect(counts, isNotEmpty);

      final feedTagTotal = dataset.feedEntries
          .fold<int>(0, (sum, e) => sum + e.tags.length);
      expect(counts.values.fold<int>(0, (a, b) => a + b), feedTagTotal);
    });
  });

  group('writes', () {
    test('a new entry appears in the feed and the count', () async {
      final s = service();
      await s.saveJournalEntry(JournalEntry(
        id: 'added',
        type: EntryType.story,
        date: referenceNow,
        headline: 'Added during the demo',
        content: 'x',
        mood: Mood.happy,
      ));

      expect(s.journalCount(), 17);
      expect((await s.getJournal()).map((e) => e.id), contains('added'));
    });

    test('saving an existing id updates rather than duplicates', () async {
      final s = service();
      final original = (await s.getJournal()).first;
      await s.saveJournalEntry(original.copyWith(headline: 'Edited'));

      expect(s.journalCount(), 16);
      expect((await s.getJournal()).first.headline, 'Edited');
    });

    test('deleting removes the entry', () async {
      final s = service();
      final target = (await s.getJournal()).first.id;
      await s.deleteJournalEntry(target);

      expect(s.journalCount(), 15);
      expect((await s.getJournal()).map((e) => e.id), isNot(contains(target)));
    });

    test('moving an entry into the vault hides it from the feed', () async {
      final s = service();
      final target = (await s.getJournal()).first;
      await s.saveJournalEntry(target.copyWith(isPrivate: true));

      expect(s.journalCount(), 15);
      expect(s.journalCount(privacy: PrivacyFilter.onlyPrivate), 4);
    });

    test('renaming a tag rewrites every entry carrying it', () async {
      final s = service();
      final counts = await s.getTagCounts();
      final tag = counts.keys.firstWhere((t) => counts[t]! > 1);

      final changed = await s.renameTag(tag, 'renamed');
      expect(changed, greaterThan(1));

      final after = await s.getTagCounts();
      expect(after.containsKey(tag), isFalse);
      expect(after['renamed'], counts[tag]);
    });

    test('reordering a ranking category sticks', () async {
      final s = service();
      final category = (await s.getRankings()).first;
      final reversed = category.items.reversed.toList();

      await s.reorderRankedItems(category.id, reversed);

      final after = (await s.getRankings())
          .firstWhere((c) => c.id == category.id);
      expect(after.items.map((i) => i.id),
          reversed.map((i) => i.id));
    });

    test('vision board edits apply to the right year', () async {
      final s = service();
      final board = s.getVisionBoardForYear(referenceNow.year)!;
      final item = board.items.first;

      s.updateVisionBoardItem(
          referenceNow.year, item.copyWith(isAchieved: !item.isAchieved));

      final after = s.getVisionBoardForYear(referenceNow.year)!;
      expect(after.items.first.isAchieved, !item.isAchieved);
    });

    test('mutations never reach the pristine dataset', () async {
      // Two services built from the same MockDataset must not see each other's
      // edits — otherwise "Reset demo data" would have nothing to restore.
      final first = service();
      await first.deleteJournalEntry((await first.getJournal()).first.id);

      expect(service().journalCount(), 16);
      expect(dataset.journalEntries, hasLength(19));
    });

    test('reset restores everything changed in the session', () async {
      final s = service();
      await s.deleteJournalEntry((await s.getJournal()).first.id);
      await s.saveSettings(const UserSettings(username: 'Changed'));
      await s.saveDraft('d', 'unsaved text');

      s.reset();

      expect(s.journalCount(), 16);
      expect(s.getSettings(), dataset.settings);
      expect(await s.getDraft('d'), isNull);
    });
  });

  group('provider wiring', () {
    ProviderContainer containerWith({required bool enabled}) {
      final container = ProviderContainer(
        overrides: mockModeOverrides(
          repository: MockDataRepository.withDataset(dataset),
          initiallyEnabled: enabled,
        ),
      );
      addTearDown(container.dispose);
      return container;
    }

    test('the storage seam stays null while demo mode is off', () {
      // Null is what makes storageServiceProvider fall through to the real
      // platform backend, so this is the assertion that demo mode is genuinely
      // inert when switched off.
      final container = containerWith(enabled: false);
      expect(container.read(storageBackendOverrideProvider), isNull);
    });

    test('the seam serves the in-memory backend while demo mode is on', () {
      final container = containerWith(enabled: true);
      expect(container.read(storageBackendOverrideProvider),
          isA<MockDataStorageService>());
    });

    test('toggling on swaps the backend and bumps the journal revision', () async {
      final container = containerWith(enabled: false);
      final before = container.read(journalRevisionProvider);

      await container.read(mockModeProvider.notifier).setEnabled(true);

      expect(container.read(mockModeProvider), isTrue);
      expect(container.read(storageBackendOverrideProvider),
          isA<MockDataStorageService>());
      expect(container.read(journalRevisionProvider), greaterThan(before),
          reason: 'screens reload off this counter; without a bump they would '
              'keep rendering the previous backend\'s entries');
    });

    test('toggling off restores the seam to null', () async {
      final container = containerWith(enabled: true);
      await container.read(mockModeProvider.notifier).setEnabled(false);

      expect(container.read(mockModeProvider), isFalse);
      expect(container.read(storageBackendOverrideProvider), isNull);
    });

    test('the demo backend is stable across reads so edits survive', () async {
      final container = containerWith(enabled: true);
      final service =
          container.read(storageBackendOverrideProvider) as MockDataStorageService;
      await service.deleteJournalEntry((await service.getJournal()).first.id);

      expect(
        (container.read(storageBackendOverrideProvider) as MockDataStorageService)
            .journalCount(),
        15,
      );
    });

    test('reset returns the demo session to the pristine fixtures', () async {
      final container = containerWith(enabled: true);
      final service = container.read(mockDataStorageServiceProvider);
      await service.deleteJournalEntry((await service.getJournal()).first.id);

      container.read(mockModeProvider.notifier).resetData();

      expect(container.read(mockDataStorageServiceProvider).journalCount(), 16);
    });
  });
}
