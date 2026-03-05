import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_models.dart';

/// Singleton wrapper that initialises and exposes the Isar DB instance.
class IsarService {
  static IsarService? _instance;
  late final Isar isar;

  IsarService._();

  /// Call once at app startup (before runApp).
  static Future<IsarService> init() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    final isarInstance = await Isar.open(
      [
        IsarJournalEntrySchema,
        IsarRankingCategorySchema,
        IsarUserSettingsSchema,
      ],
      directory: dir.path,
    );

    _instance = IsarService._()..isar = isarInstance;
    return _instance!;
  }

  /// Access the singleton after init().
  static IsarService get instance {
    assert(_instance != null, 'IsarService.init() must be called first');
    return _instance!;
  }
}
