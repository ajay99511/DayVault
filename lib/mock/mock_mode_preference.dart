import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/feature_flags.dart';

/// Persists whether mock (demo) data is switched on.
///
/// Stored outside [StorageService] on purpose: the storage service is the very
/// thing this preference selects, so keeping the choice inside it would mean
/// demo mode remembering its own state in demo data. `flutter_secure_storage`
/// is used because it is already a dependency on every target this app ships
/// to — not because the value is a secret.
///
/// Every operation is best-effort. Losing this preference downgrades to the
/// compile-time default ([FeatureFlags.mockDataEnabledByDefault]), which is a
/// cosmetic loss; it must never keep the app from starting.
class MockModePreference {
  static const String storageKey = 'dv_mock_data_enabled';

  final FlutterSecureStorage _storage;

  const MockModePreference({FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  Future<bool> read() async {
    // The toggle being compiled out is a hard override: a build that cannot
    // enter demo mode must not start in it because of a stale stored value.
    if (!FeatureFlags.mockDataToggleVisible) {
      return FeatureFlags.mockDataEnabledByDefault;
    }
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null) return FeatureFlags.mockDataEnabledByDefault;
      return raw == 'true';
    } catch (e) {
      debugPrint('Mock mode preference unreadable, using compile-time default: $e');
      return FeatureFlags.mockDataEnabledByDefault;
    }
  }

  Future<void> write(bool enabled) async {
    try {
      await _storage.write(key: storageKey, value: enabled ? 'true' : 'false');
    } catch (e) {
      // The in-memory toggle has already flipped, so the current session is
      // correct either way; only the choice's survival across restarts is lost.
      debugPrint('Mock mode preference could not be persisted: $e');
    }
  }
}
