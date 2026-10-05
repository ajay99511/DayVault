import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/mock/mock_data_loader.dart';
import 'package:memory_palace/mock/mock_data_repository.dart';
import 'package:memory_palace/mock/mock_dataset.dart';
import 'package:memory_palace/mock/mock_mode_preference.dart';
import 'package:memory_palace/mock/mock_mode_scope.dart';
import 'package:memory_palace/providers/mock_mode_provider.dart';
import 'package:memory_palace/screens/identity_screen.dart';
import 'package:memory_palace/services/identity_view_preferences.dart';

/// The Identity screen's view state: privacy masking must start off, and every
/// view choice must survive a restart.
///
/// Driven through the demo fixtures because they are the only ranking data a
/// test can rely on; what is under test is the screen, not the backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDataset dataset;

  setUpAll(() async {
    dataset = await MockDataLoader().load(now: DateTime.now());
  });

  Widget harness(IdentityViewPreferences prefs) {
    return ProviderScope(
      overrides: [
        ...mockModeOverrides(
          repository: MockDataRepository.withDataset(dataset),
          initiallyEnabled: true,
        ),
        // Both preferences live on the secure-storage platform channel, which
        // does not exist under flutter_test.
        mockModePreferenceProvider
            .overrideWithValue(const _InMemoryMockModePreference()),
        identityViewPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: IdentityScreen()),
    );
  }

  /// Pump past the preference read, the rankings load and the tab animation
  /// without `pumpAndSettle`, which the cover images' retry timers can outlast.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group('privacy mode is not the default', () {
    testWidgets('a fresh install opens with names visible', (tester) async {
      await tester.pumpWidget(harness(_FakePreferences()));
      await settle(tester);

      expect(find.text('In the Mood for Love'), findsOneWidget);
      expect(find.text('••••••••'), findsNothing);
    });

    testWidgets('search is offered on a fresh install', (tester) async {
      // Masking makes the query inert, so the search affordance disappearing
      // is the visible symptom of the screen having opened masked.
      await tester.pumpWidget(harness(_FakePreferences()));
      await settle(tester);

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('view state survives a restart', () {
    testWidgets('masking, once chosen, is restored', (tester) async {
      await tester.pumpWidget(
        harness(_FakePreferences(const IdentityViewState(masked: true))),
      );
      await settle(tester);

      expect(find.text('In the Mood for Love'), findsNothing);
      expect(find.text('••••••••'), findsWidgets);
      // And the inert search button is not offered while masked.
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('the screen reopens on the category it was left on',
        (tester) async {
      await tester.pumpWidget(harness(
        _FakePreferences(const IdentityViewState(activeCategoryId: 'books')),
      ));
      await settle(tester);

      expect(find.text('Piranesi'), findsOneWidget);
      expect(find.text('In the Mood for Love'), findsNothing);
    });

    testWidgets('a stale category id falls back to the first category',
        (tester) async {
      await tester.pumpWidget(harness(_FakePreferences(
        const IdentityViewState(activeCategoryId: 'deleted-last-week'),
      )));
      await settle(tester);

      expect(find.text('In the Mood for Love'), findsOneWidget);
    });

    testWidgets('the favourites filter is restored', (tester) async {
      await tester.pumpWidget(
        harness(_FakePreferences(const IdentityViewState(favoritesOnly: true))),
      );
      await settle(tester);

      // Movies, Restaurants and Books are the favourite fixtures; Places is
      // not, so its tab must be gone.
      expect(find.text('BOOKS'), findsOneWidget);
      expect(find.text('PLACES'), findsNothing);
    });

    testWidgets('a restored sort actually reorders the list', (tester) async {
      await tester.pumpWidget(harness(
        _FakePreferences(const IdentityViewState(sort: ItemSort.dateDesc)),
      ));
      await settle(tester);

      // Paddington 2 is ranked #6 by hand but added most recently, and Past
      // Lives is #3 but older — so "recently added" has to invert them.
      // Both land near the top of this sort, where the list is on screen.
      expect(
        tester.getTopLeft(find.text('Paddington 2')).dy,
        lessThan(tester.getTopLeft(find.text('Past Lives')).dy),
      );
    });

    testWidgets('manual sort keeps the drag handles', (tester) async {
      await tester.pumpWidget(harness(_FakePreferences()));
      await settle(tester);

      expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);
    });

    testWidgets('a restored derived sort also disables manual reordering',
        (tester) async {
      // Dragging under a derived sort would write a rank order the user never
      // chose, so the handles have to come off with the sort restored — not
      // only when it is picked from the menu.
      await tester.pumpWidget(harness(
        _FakePreferences(const IdentityViewState(sort: ItemSort.ratingDesc)),
      ));
      await settle(tester);

      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    });
  });

  group('choices are written through', () {
    testWidgets('turning privacy mode on is persisted', (tester) async {
      final prefs = _FakePreferences();
      await tester.pumpWidget(harness(prefs));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await settle(tester);

      expect(prefs.written.last.masked, isTrue);
    });

    testWidgets('switching category is persisted', (tester) async {
      final prefs = _FakePreferences();
      await tester.pumpWidget(harness(prefs));
      await settle(tester);

      // The second tab; the later ones sit off the edge of the test viewport.
      await tester.tap(find.text('RESTAURANTS'));
      await settle(tester);

      expect(prefs.written.last.activeCategoryId, 'restaurants');
    });
  });
}

/// Records what the screen chose to remember and replays a starting state.
class _FakePreferences implements IdentityViewPreferences {
  final IdentityViewState initial;
  final List<IdentityViewState> written = [];

  _FakePreferences([this.initial = IdentityViewState.defaults]);

  @override
  Future<IdentityViewState> read() async => initial;

  @override
  Future<void> write(IdentityViewState state) async => written.add(state);
}

class _InMemoryMockModePreference implements MockModePreference {
  const _InMemoryMockModePreference();

  @override
  Future<bool> read() async => false;

  @override
  Future<void> write(bool enabled) async {}
}
