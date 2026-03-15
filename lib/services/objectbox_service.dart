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
    final store = await openStore(directory: '${dir.path}/objectbox');

    _instance = ObjectBoxService._()..store = store;
    return _instance!;
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
