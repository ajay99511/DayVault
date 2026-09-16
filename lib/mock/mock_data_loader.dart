import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/types.dart';
import 'mock_dataset.dart';
import 'mock_date_resolver.dart';
import 'mock_fixtures.dart';

/// Thrown when a fixture is missing, malformed, or does not match the models.
///
/// Deliberately fatal. The fixtures are part of the source tree, so a failure
/// here means a developer changed a model without updating the demo data —
/// the one thing this whole pipeline exists to catch. Falling back to an empty
/// dataset would hide it behind an empty-looking demo.
class MockDataLoadException implements Exception {
  final String fixture;
  final String message;
  final Object? cause;

  const MockDataLoadException(this.fixture, this.message, [this.cause]);

  @override
  String toString() => 'MockDataLoadException($fixture): $message'
      '${cause == null ? '' : '\nCaused by: $cause'}';
}

/// Reads the JSON fixtures and turns them into a typed [MockDataset].
///
/// Parsing goes through the models' own generated `fromJson` constructors
/// rather than a bespoke reader. That is the point: the fixtures exercise the
/// same serialization contract as backups and the web backend, so a field that
/// is added to a model and forgotten in the fixtures shows up as a parse
/// failure in `test/mock/mock_fixtures_test.dart` instead of as a silently
/// missing value in a demo.
class MockDataLoader {
  final AssetBundle _bundle;

  MockDataLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Load and parse every fixture.
  ///
  /// [now] is the instant relative date tokens resolve against; tests pass a
  /// fixed clock so assertions are deterministic.
  Future<MockDataset> load({DateTime? now}) async {
    final resolver = MockDateResolver(reference: now);

    final entries = await _readList(
      MockFixtures.journalEntries,
      MockFixtures.entriesKey,
      resolver,
      JournalEntry.fromJson,
    );
    final categories = await _readList(
      MockFixtures.rankingCategories,
      MockFixtures.categoriesKey,
      resolver,
      RankingCategory.fromJson,
    );
    final boards = await _readList(
      MockFixtures.visionBoards,
      MockFixtures.boardsKey,
      resolver,
      VisionBoard.fromJson,
    );
    final settings = await _readObject(
      MockFixtures.userSettings,
      MockFixtures.settingsKey,
      resolver,
      UserSettings.fromJson,
    );

    return MockDataset(
      journalEntries: List.unmodifiable(entries),
      rankingCategories: List.unmodifiable(categories),
      visionBoards: List.unmodifiable(boards),
      settings: settings,
      resolvedAt: resolver.reference,
    );
  }

  Future<Map<String, dynamic>> _readDocument(
    String path,
    MockDateResolver resolver,
  ) async {
    final String raw;
    try {
      raw = await _bundle.loadString(path);
    } catch (e) {
      throw MockDataLoadException(
        path,
        'Fixture could not be read. Is it registered under `flutter: assets:` '
        'in pubspec.yaml?',
        e,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw MockDataLoadException(path, 'Fixture is not valid JSON.', e);
    }

    final Map<String, dynamic> document;
    try {
      document = resolver.resolveDocument(decoded, source: path);
    } on MockDateTokenException catch (e) {
      throw MockDataLoadException(path, e.message, e);
    }

    final version = document[MockFixtures.versionKey];
    if (version != MockFixtures.supportedVersion) {
      throw MockDataLoadException(
        path,
        'Unsupported ${MockFixtures.versionKey}: $version '
        '(this build reads ${MockFixtures.supportedVersion}).',
      );
    }
    return document;
  }

  Future<List<T>> _readList<T>(
    String path,
    String key,
    MockDateResolver resolver,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final document = await _readDocument(path, resolver);
    final raw = document[key];
    if (raw is! List) {
      throw MockDataLoadException(path, 'Expected a list under "$key".');
    }

    final result = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) {
        throw MockDataLoadException(path, '"$key"[$i] is not a JSON object.');
      }
      try {
        result.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        throw MockDataLoadException(
          path,
          '"$key"[$i] does not match the $T model. A model field was likely '
          'added, renamed or removed without updating this fixture.',
          e,
        );
      }
    }
    return result;
  }

  Future<T> _readObject<T>(
    String path,
    String key,
    MockDateResolver resolver,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final document = await _readDocument(path, resolver);
    final raw = document[key];
    if (raw is! Map) {
      throw MockDataLoadException(path, 'Expected a JSON object under "$key".');
    }
    try {
      return fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      throw MockDataLoadException(
        path,
        '"$key" does not match the $T model. A model field was likely added, '
        'renamed or removed without updating this fixture.',
        e,
      );
    }
  }
}
