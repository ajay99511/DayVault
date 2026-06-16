import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/providers/stats_provider.dart';
import 'package:memory_palace/screens/profile_screen.dart';
import 'package:memory_palace/services/storage_service.dart';

/// Minimal fake that only implements the members [StatsNotifier] and
/// [ProfileScreen] touch; everything else routes through [noSuchMethod].
class _FakeStorageService implements StorageService {
  _FakeStorageService({this.journal = const [], this.throwOnGetJournal = false});

  final List<JournalEntry> journal;
  final bool throwOnGetJournal;
  int getJournalCalls = 0;

  @override
  Future<List<JournalEntry>> getJournal() async {
    getJournalCalls++;
    if (throwOnGetJournal) {
      throw StateError('boom');
    }
    return journal;
  }

  @override
  UserSettings getSettings() => const UserSettings();

  @override
  Future<UserSettings> saveSettings(UserSettings settings) async => settings;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  // Req 1.2 — stats are computed once and cached until invalidated.
  group('StatsNotifier caching', () {
    test('calls getJournal exactly once across multiple reads', () async {
      final fake = _FakeStorageService(journal: const []);
      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      // Multiple reads of the same provider instance.
      await container.read(statsProvider.future);
      await container.read(statsProvider.future);
      container.read(statsProvider);

      expect(fake.getJournalCalls, 1);
    });

    test('recomputes after invalidation', () async {
      final fake = _FakeStorageService(journal: const []);
      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(statsProvider.future);
      container.invalidate(statsProvider);
      await container.read(statsProvider.future);

      expect(fake.getJournalCalls, 2);
    });
  });

  // Req 1.7 — error state renders zero/empty-state cards, not a crash.
  group('ProfileScreen stats error handling', () {
    testWidgets('renders empty-state cards when stats fail', (tester) async {
      final fake = _FakeStorageService(throwOnGetJournal: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      // Let the failing async build resolve (avoid pumpAndSettle — the loading
      // shimmer animates indefinitely).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Empty-state markers from JournalStats.empty.
      expect(find.text('—'), findsOneWidget); // average mood empty state
      expect(find.text('No tags yet'), findsOneWidget);
      // Non-blocking failure notification.
      expect(find.text('Could not load your insights'), findsOneWidget);
    });
  });
}
