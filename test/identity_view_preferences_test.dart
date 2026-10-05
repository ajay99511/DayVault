import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/identity_view_preferences.dart';

/// The Identity screen's view state is remembered between launches, so the
/// decoding side has to survive anything an older build (or a corrupted
/// keystore) might hand it. A throw here would take the whole screen down.
void main() {
  // So the secure-storage failure under test is the missing platform channel
  // rather than an uninitialised binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('defaults', () {
    test('privacy masking is off', () {
      // The point of the change: the screen must not open on a wall of
      // bullets that the user has to switch off before it is usable.
      expect(IdentityViewState.defaults.masked, isFalse);
    });

    test('nothing else is pre-selected either', () {
      const d = IdentityViewState.defaults;
      expect(d.favoritesOnly, isFalse);
      expect(d.sort, ItemSort.manual);
      expect(d.activeCategoryId, isNull);
    });
  });

  group('serialisation', () {
    test('round-trips every field', () {
      const state = IdentityViewState(
        masked: true,
        favoritesOnly: true,
        sort: ItemSort.ratingDesc,
        activeCategoryId: 'books',
      );

      expect(
        IdentityViewState.fromJson(jsonDecode(jsonEncode(state.toJson()))),
        state,
      );
    });

    test('the sort is stored by name, not by ordinal', () {
      // Stored as an index, reordering the enum would silently reinterpret
      // every saved preference as a different sort.
      expect(
        const IdentityViewState(sort: ItemSort.dateDesc).toJson()['sort'],
        'dateDesc',
      );
    });

    test('an unknown sort name falls back to manual', () {
      expect(
        IdentityViewState.fromJson(const {'sort': 'ratingAscending'}).sort,
        ItemSort.manual,
      );
    });

    test('missing fields fall back to the defaults', () {
      expect(
          IdentityViewState.fromJson(const <String, dynamic>{}),
          IdentityViewState.defaults);
    });

    test('wrong-typed fields fall back rather than throwing', () {
      final state = IdentityViewState.fromJson(const {
        'masked': 'yes',
        'favoritesOnly': 1,
        'sort': 7,
        'activeCategoryId': 42,
      });

      expect(state, IdentityViewState.defaults);
    });

    test('an empty category id is treated as no category', () {
      expect(
        IdentityViewState.fromJson(const {'activeCategoryId': ''})
            .activeCategoryId,
        isNull,
      );
    });
  });

  group('reading', () {
    test('an absent platform channel yields the defaults, not a throw', () async {
      // There is no secure-storage channel under flutter_test, so this
      // exercises the same path a device with a misbehaving keystore takes.
      final prefs = await const IdentityViewPreferences().read();
      expect(prefs, IdentityViewState.defaults);
    });

    test('writing without a platform channel is swallowed', () async {
      await expectLater(
        const IdentityViewPreferences().write(
          const IdentityViewState(masked: true),
        ),
        completes,
      );
    });
  });

  group('copyWith', () {
    test('replaces only what it is given', () {
      const base = IdentityViewState(
        masked: true,
        favoritesOnly: true,
        sort: ItemSort.dateDesc,
        activeCategoryId: 'movies',
      );

      expect(base.copyWith(masked: false).masked, isFalse);
      expect(base.copyWith(masked: false).activeCategoryId, 'movies');
      expect(base.copyWith(sort: ItemSort.manual).favoritesOnly, isTrue);
    });
  });
}
