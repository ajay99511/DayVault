import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/mock/mock_data_loader.dart';
import 'package:memory_palace/mock/mock_data_repository.dart';
import 'package:memory_palace/mock/mock_dataset.dart';
import 'package:memory_palace/mock/mock_mode_banner.dart';
import 'package:memory_palace/mock/mock_mode_preference.dart';
import 'package:memory_palace/mock/mock_mode_scope.dart';
import 'package:memory_palace/providers/mock_mode_provider.dart';
import 'package:memory_palace/screens/journal_screen.dart';

/// End-to-end check that demo mode actually reaches the screens.
///
/// The unit tests prove the backend serves the fixtures; this proves the
/// provider swap is wired all the way through to rendered pixels, which is the
/// thing that would silently break if `storageBackendOverrideProvider` were
/// ever bypassed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDataset dataset;

  setUpAll(() async {
    dataset = await MockDataLoader().load(now: DateTime.now());
  });

  Widget harness({required bool enabled, required Widget child}) {
    return ProviderScope(
      overrides: [
        ...mockModeOverrides(
          repository: MockDataRepository.withDataset(dataset),
          initiallyEnabled: enabled,
        ),
        // Keep the toggle off the secure-storage platform channel, which does
        // not exist under flutter_test.
        mockModePreferenceProvider.overrideWithValue(const _InMemoryPreference()),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('the journal renders the demo entries when demo mode is on',
      (tester) async {
    await tester.pumpWidget(harness(enabled: true, child: const JournalScreen()));
    await tester.pump(); // resolve the async first-page load

    // The newest fixture entry, straight from assets/mock/journal_entries.json.
    expect(
      find.text('The quiet win at the end of a loud week'),
      findsOneWidget,
    );
    // A private entry must never surface in the feed.
    expect(find.text('The conversation I keep rehearsing'), findsNothing);
  });

  testWidgets('the DEMO DATA banner tracks the toggle', (tester) async {
    await tester.pumpWidget(
      harness(enabled: true, child: const Scaffold(body: MockModeBanner())),
    );
    expect(find.text('DEMO DATA'), findsOneWidget);

    // Flip through the notifier rather than rebuilding the scope: this is the
    // path the Profile toggle takes, and the banner has to react to it live.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MockModeBanner)));
    await container.read(mockModeProvider.notifier).setEnabled(false);
    await tester.pump();

    expect(find.text('DEMO DATA'), findsNothing);
  });
}

class _InMemoryPreference extends MockModePreference {
  const _InMemoryPreference();

  @override
  Future<bool> read() async => false;

  @override
  Future<void> write(bool enabled) async {}
}
