import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';
import '../models/objectbox_models.dart';

enum InitResult { success, migrationRequired, fatalError }

class ObjectBoxInitOutcome {
  final InitResult result;
  final String? backupPath;
  final String? errorMessage;
  const ObjectBoxInitOutcome(this.result, {this.backupPath, this.errorMessage});
}

/// Singleton wrapper that initialises and exposes the ObjectBox Store.
class ObjectBoxService {
  static ObjectBoxService? _instance;
  late final Store store;

  ObjectBoxService._();

  static const List<Map<String, String>> _defaultCategoryDefs = [
    {'id': 'movies',      'title': 'Movies',      'iconName': 'movie'},
    {'id': 'restaurants', 'title': 'Restaurants', 'iconName': 'restaurant'},
    {'id': 'places',      'title': 'Places',      'iconName': 'place'},
    {'id': 'people',      'title': 'People',      'iconName': 'person'},
    {'id': 'books',       'title': 'Books',       'iconName': 'book'},
  ];

  /// How many times a failing open is retried before the store is considered
  /// genuinely unopenable. Transient failures dominate in practice — a file
  /// lock held by an exiting instance of the app, an antivirus scanner, a
  /// momentary I/O error — and every one of those used to cost the user their
  /// entire journal.
  static const int _openAttempts = 3;

  /// Call once at app startup (before runApp).
  ///
  /// **This method never destroys or moves user data.** An earlier version
  /// renamed the whole database directory away on *any* exception, before the
  /// user had been asked anything and with no code anywhere that could put it
  /// back — so one transient file lock permanently orphaned the journal. The
  /// only destructive step now lives in [reinitializeAfterConsent], behind an
  /// explicit confirmation.
  static Future<ObjectBoxInitOutcome> init() async {
    if (_instance != null) return const ObjectBoxInitOutcome(InitResult.success);

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/objectbox';
    final existedBefore = await Directory(dbPath).exists();

    Object? lastError;
    for (var attempt = 0; attempt < _openAttempts; attempt++) {
      try {
        await _openAndAdopt(dbPath);
        return const ObjectBoxInitOutcome(InitResult.success);
      } catch (e, st) {
        lastError = e;
        debugPrint('ObjectBox open attempt ${attempt + 1} failed: $e\n$st');
        if (attempt < _openAttempts - 1) {
          // Exponential backoff: 200ms, 400ms. Long enough for a lock held by
          // a closing process to clear, short enough not to stall startup.
          await Future<void>.delayed(
            Duration(milliseconds: 200 * (1 << attempt)),
          );
        }
      }
    }

    if (!existedBefore) {
      // Nothing existed to migrate, so this is not a data-compatibility
      // problem — the device could not create a store at all (permissions,
      // disk space). Offering to "start fresh" would be meaningless.
      return ObjectBoxInitOutcome(
        InitResult.fatalError,
        errorMessage: 'Could not create the local database: $lastError',
      );
    }

    // The data is still exactly where it was. Propose — but do not perform —
    // moving it aside, and let the user decide.
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    return ObjectBoxInitOutcome(
      InitResult.migrationRequired,
      backupPath: '${dir.path}/objectbox_rescue_$stamp',
      errorMessage: lastError?.toString(),
    );
  }

  /// Open the store at [dbPath], adopt it as the singleton and seed defaults.
  static Future<void> _openAndAdopt(String dbPath) async {
    final store = await openStore(directory: dbPath);
    _instance = ObjectBoxService._()..store = store;
    await _seedDefaultsIfNeeded();
  }

  /// Move the unopenable database aside and start fresh — **only** after the
  /// user has explicitly consented, having been shown [rescuePath].
  ///
  /// The move happens here rather than in [init] so that declining the prompt
  /// genuinely leaves the data untouched. Returns normally on success; on
  /// failure the original database is left in place and the error propagates,
  /// because a half-done rescue is worse than a refused one.
  static Future<void> reinitializeAfterConsent(String rescuePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/objectbox';

    final existing = Directory(dbPath);
    if (await existing.exists()) {
      // rename() is atomic within a volume, so there is no window where the
      // data exists in neither place.
      await existing.rename(rescuePath);
    }

    await _openAndAdopt(dbPath);
  }

  static Future<void> _seedDefaultsIfNeeded() async {
    final box = _instance!.store.box<ObjectBoxRankingCategory>();
    if (box.count() > 0) return; // already seeded

    for (final def in _defaultCategoryDefs) {
      final cat = ObjectBoxRankingCategory()
        ..categoryId = def['id']!
        ..title = def['title']!
        ..iconName = def['iconName']!
        ..isFavorite = false
        ..itemsJson = '[]';
      box.put(cat);
    }
  }

  /// Access the singleton after init().
  ///
  /// Throws rather than asserting: assertions are stripped from release builds,
  /// so a real ordering mistake would have surfaced in production as an opaque
  /// null dereference instead of this message.
  static ObjectBoxService get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'ObjectBoxService.init() must complete successfully before instance '
        'is used.',
      );
    }
    return instance;
  }

  /// Close the store (for testing or app shutdown)
  static Future<void> close() async {
    if (_instance != null) {
      _instance!.store.close();
      _instance = null;
    }
  }
}
