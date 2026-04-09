import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../objectbox.g.dart';

/// Singleton wrapper that initialises and exposes the ObjectBox Store.
class ObjectBoxService {
  static ObjectBoxService? _instance;
  late final Store store;

  ObjectBoxService._();

  /// Call once at app startup (before runApp).
  static Future<ObjectBoxService> init() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/objectbox';

    try {
      final store = await openStore(directory: dbPath);
      _instance = ObjectBoxService._()..store = store;
      return _instance!;
    } catch (e, st) {
      debugPrint('ObjectBox init failed: $e\n$st');

      // Schema mismatch — delete the database and recreate
      debugPrint('Deleting corrupted database at $dbPath');
      await _deleteDatabase(dbPath);

      debugPrint('Reinitializing ObjectBox with fresh database');
      final store = await openStore(directory: dbPath);
      _instance = ObjectBoxService._()..store = store;
      return _instance!;
    }
  }

  /// Delete the ObjectBox database directory recursively.
  static Future<void> _deleteDatabase(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
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
