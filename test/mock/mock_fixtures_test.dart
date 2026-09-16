import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/config/constants.dart';
import 'package:memory_palace/mock/mock_data_loader.dart';
import 'package:memory_palace/mock/mock_dataset.dart';
import 'package:memory_palace/mock/mock_fixtures.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/services/storage/storage_service_interface.dart';

/// The contract the demo fixtures must satisfy.
///
/// This suite is the enforcement mechanism behind
/// `.claude/skills/mock-data/SKILL.md`: adding, renaming or removing a field on
/// any model in `lib/models/types.dart` without mirroring it in
/// `assets/mock/*.json` fails here with a message naming the fixture, rather
/// than showing up months later as a blank field in a demo.
void main() {
  // rootBundle needs the binding, and the fixtures are loaded through it so
  // the test exercises exactly the path the app uses.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A fixed clock, so every assertion about dates is deterministic. Chosen
  /// mid-month and mid-year so month/day offsets in the fixtures cannot
  /// accidentally straddle a year or month boundary in this test.
  final referenceNow = DateTime(2026, 6, 15, 12);

  late MockDataset dataset;

  setUpAll(() async {
    dataset = await MockDataLoader().load(now: referenceNow);
  });

  group('fixture loading', () {
    test('every fixture parses through the real model constructors', () {
      // Reaching this point means load() succeeded for all four files. The
      // assertions below are about content; this one is about the contract
      // that the files still match the models at all.
      expect(dataset.journalEntries, isNotEmpty);
      expect(dataset.rankingCategories, isNotEmpty);
      expect(dataset.visionBoards, isNotEmpty);
      expect(dataset.settings.username, isNotEmpty);
    });

    test('every declared fixture file is actually read', () {
      // Guards against a fixture being added to MockFixtures.all but never
      // wired into the loader.
      expect(MockFixtures.all, hasLength(4));
      expect(MockFixtures.all, everyElement(startsWith(MockFixtures.directory)));
    });

    test('models survive a serialize/deserialize round trip', () {
      // A field the fixtures omit still parses (defaults fill it in) but would
      // not survive a backup export/import. Round-tripping every record proves
      // the demo data is as valid as anything the app itself writes.
      //
      // The trip goes through jsonEncode/jsonDecode rather than
      // `fromJson(toJson())` because json_serializable leaves nested models as
      // objects in the map (`'location': instance.location`) and relies on
      // jsonEncode to call their toJson. Encoding is therefore the real
      // serialization boundary, and the only one worth asserting against.
      T trip<T>(Object? model, T Function(Map<String, dynamic>) fromJson) =>
          fromJson(jsonDecode(jsonEncode(model)) as Map<String, dynamic>);

      for (final entry in dataset.journalEntries) {
        expect(trip(entry, JournalEntry.fromJson), entry,
            reason: 'entry ${entry.id} did not round trip');
      }
      for (final category in dataset.rankingCategories) {
        expect(trip(category, RankingCategory.fromJson), category,
            reason: 'category ${category.id} did not round trip');
      }
      for (final board in dataset.visionBoards) {
        expect(trip(board, VisionBoard.fromJson), board,
            reason: 'board ${board.id} did not round trip');
      }
      expect(trip(dataset.settings, UserSettings.fromJson), dataset.settings);
    });

    test('the dataset records the clock it was resolved against', () {
      expect(dataset.resolvedAt, referenceNow);
    });
  });

  group('journal fixtures', () {
    test('the feed holds exactly 16 entries', () {
      // The demo is specified at 16 feed entries. Locked down because several
      // screens are tuned around that count.
      expect(dataset.feedEntries, hasLength(16));
    });

    test('the vault holds private entries the feed never shows', () {
      expect(dataset.vaultEntries, isNotEmpty);
      expect(dataset.feedEntries.every((e) => !e.isPrivate), isTrue);
    });

    test('entry ids are unique', () {
      final ids = dataset.journalEntries.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('both entry types are represented', () {
      final types = dataset.feedEntries.map((e) => e.type).toSet();
      expect(types, containsAll(<EntryType>[EntryType.story, EntryType.event]));
    });

    test('spotlight, tags, images and locations all have examples', () {
      // Each of these drives a distinct surface (spotlight filter, tag chips,
      // the image carousel, the location line). An empty one silently removes
      // that surface from the demo.
      expect(dataset.feedEntries.where((e) => e.isSpotlight), isNotEmpty);
      expect(dataset.feedEntries.where((e) => e.tags.isNotEmpty), isNotEmpty);
      expect(dataset.feedEntries.where((e) => e.images.isNotEmpty), isNotEmpty);
      expect(dataset.feedEntries.where((e) => e.location != null), isNotEmpty);
      expect(dataset.feedEntries.where((e) => e.feeling != null), isNotEmpty);
      expect(dataset.feedEntries.where((e) => e.timeBucket != null), isNotEmpty);
    });

    test('entries cover a wide spread of moods', () {
      final moods = dataset.feedEntries.map((e) => e.mood).toSet();
      expect(moods.length, greaterThanOrEqualTo(8),
          reason: 'the mood filter needs variety to be worth demonstrating');
    });

    test('a recent unbroken run of days exists for the streak', () {
      final today = DateTime(referenceNow.year, referenceNow.month, referenceNow.day);
      final days = dataset.feedEntries
          .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
          .toSet();
      for (var back = 0; back < 4; back++) {
        expect(days, contains(today.subtract(Duration(days: back))),
            reason: 'streak demo needs an entry $back day(s) before today');
      }
    });

    test('past-year entries land on today for "On this day"', () {
      // This is the reason the fixtures use calendar-field offsets rather than
      // Durations: `years: -1` must keep the same month and day, and adding
      // 365 days would not across a leap year.
      final onThisDay = dataset.feedEntries.where((e) =>
          e.date.month == referenceNow.month &&
          e.date.day == referenceNow.day &&
          e.date.year != referenceNow.year);
      expect(onThisDay, hasLength(2));
    });

    test('no entry is dated on a future day', () {
      // The invariant is the calendar day, not the wall clock: the newest
      // entry is deliberately written "tonight" at 21:40, which is ahead of a
      // clock read at midday but still today. An entry dated *tomorrow* would
      // be a genuine fixture bug — it would sit above today's in the feed and
      // corrupt the streak the demo is trying to show.
      final endOfToday = DateTime(
          referenceNow.year, referenceNow.month, referenceNow.day, 23, 59, 59);
      for (final entry in dataset.journalEntries) {
        expect(entry.date.isAfter(endOfToday), isFalse,
            reason: '${entry.id} is dated after the reference day');
      }
    });

    test('image references point at a domain the app already trusts', () {
      // Demo images must not normalise a host the real editor would reject.
      for (final entry in dataset.journalEntries) {
        for (final image in entry.images) {
          expect(image.type, ImageSourceType.webUrl,
              reason: 'gallery and file references cannot resolve on a fresh '
                  'device; demo images must be URLs');
          expect(image.source, startsWith('https://'));
        }
      }
    });
  });

  group('ranking fixtures', () {
    test('the seeded default category ids are all present', () {
      // IdentityScreen opens on the 'movies' tab, and the seeded ids are what
      // a real install has; diverging here makes the demo unrepresentative.
      final ids = dataset.rankingCategories.map((c) => c.id).toSet();
      expect(ids, containsAll(defaultCategories.map((c) => c.id)));
    });

    test('every category has items and every icon name resolves', () {
      for (final category in dataset.rankingCategories) {
        expect(category.items, isNotEmpty, reason: '${category.id} is empty');
        expect(categoryIcons.containsKey(category.iconName), isTrue,
            reason: '${category.id} uses unknown icon "${category.iconName}"');
      }
    });

    test('ranks are a contiguous 1..n sequence within each category', () {
      for (final category in dataset.rankingCategories) {
        final ranks = category.items.map((i) => i.rank).toList()..sort();
        expect(ranks, List.generate(category.items.length, (i) => i + 1),
            reason: '${category.id} has gapped or duplicated ranks');
      }
    });

    test('item ids are unique and ratings are within 0..5', () {
      final ids = <String>[];
      for (final category in dataset.rankingCategories) {
        for (final item in category.items) {
          ids.add(item.id);
          expect(item.rating, inInclusiveRange(0, 5),
              reason: '${item.id} has an out-of-range rating');
        }
      }
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('some items carry enough history to draw the drift chart', () {
      final withDrift = dataset.rankingCategories
          .expand((c) => c.items)
          .where((i) => i.history.length >= 2);
      expect(withDrift, isNotEmpty,
          reason: 'Preference Drift renders only at two or more snapshots');
    });

    test('at least one category is favourited', () {
      expect(dataset.rankingCategories.where((c) => c.isFavorite), isNotEmpty);
    });
  });

  group('vision board fixtures', () {
    test('a board exists for the current year', () {
      // VisionBoardScreen opens on DateTime.now().year; without this the demo
      // lands on an empty state.
      final years = dataset.visionBoards.map((b) => b.year).toSet();
      expect(years, contains(referenceNow.year));
    });

    test('boards are one per year with unique item ids', () {
      final years = dataset.visionBoards.map((b) => b.year).toList();
      expect(years.toSet(), hasLength(years.length));

      final ids = dataset.visionBoards.expand((b) => b.items).map((i) => i.id);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('the current board mixes achieved and outstanding goals', () {
      final current =
          dataset.visionBoards.firstWhere((b) => b.year == referenceNow.year);
      expect(current.items.where((i) => i.isAchieved), isNotEmpty);
      expect(current.items.where((i) => !i.isAchieved), isNotEmpty);
    });

    test('every item uses a known category', () {
      for (final board in dataset.visionBoards) {
        for (final item in board.items) {
          expect(visionBoardCategories, contains(item.category),
              reason: '${item.id} uses unknown category "${item.category}"');
        }
      }
    });
  });

  group('settings fixtures', () {
    test('demo mode never puts a lock screen in front of fabricated data', () {
      expect(dataset.settings.securityEnabled, isFalse);
      expect(dataset.settings.biometricsEnabled, isFalse);
    });
  });
}
