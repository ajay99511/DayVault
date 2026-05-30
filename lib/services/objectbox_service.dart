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

  /// Call once at app startup (before runApp).
  static Future<ObjectBoxInitOutcome> init() async {
    if (_instance != null) return const ObjectBoxInitOutcome(InitResult.success);

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/objectbox';

    try {
      final store = await openStore(directory: dbPath);
      _instance = ObjectBoxService._()..store = store;
      await _seedDefaultsIfNeeded();
      return const ObjectBoxInitOutcome(InitResult.success);
    } catch (e, st) {
      debugPrint('ObjectBox init failed: $e\n$st');

      // Attempt backup before any destructive action
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${dir.path}/objectbox_backup_$timestamp';
      try {
        if (await Directory(dbPath).exists()) {
          await Directory(dbPath).rename(backupPath);
        } else {
          // If the directory doesn't exist, we can just open a fresh store
          final store = await openStore(directory: dbPath);
          _instance = ObjectBoxService._()..store = store;
          await _seedDefaultsIfNeeded();
          return const ObjectBoxInitOutcome(InitResult.success);
        }
      } catch (backupErr) {
        debugPrint('Backup failed: $backupErr');
        return ObjectBoxInitOutcome(
          InitResult.fatalError,
          errorMessage: 'Could not back up database: $backupErr',
        );
      }

      return ObjectBoxInitOutcome(
        InitResult.migrationRequired,
        backupPath: backupPath,
      );
    }
  }

  /// Called by RootOrchestrator after user grants consent.
  static Future<void> reinitializeAfterConsent(String backupPath) async {
    // backupPath already moved away; just open a fresh store
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/objectbox';
    final store = await openStore(directory: dbPath);
    _instance = ObjectBoxService._()..store = store;
    await _seedDefaultsIfNeeded();
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
  static ObjectBoxService get instance {
    assert(_instance != null, 'ObjectBoxService.init() must be called first');
    return _instance!;
  }

  /// Close the store (for testing or app shutdown)
  static Future<void> close() async {
    if (_instance != null) {
      _instance!.store.close();
      _instance = null;
    }
  }
}
