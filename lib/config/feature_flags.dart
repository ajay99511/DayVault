/// Compile-time feature flags.
///
/// Values are read from `--dart-define` at build time so the Dart compiler can
/// tree-shake whole branches out of a release binary when a flag is off.
/// Anything that needs to change *while the app is running* belongs in a
/// provider instead (see `providers/mock_mode_provider.dart`).
library;

class FeatureFlags {
  const FeatureFlags._();

  /// Environment key for the mock-data default. Exposed so tooling, tests and
  /// docs reference one spelling instead of copying the literal around.
  static const String mockDataEnvKey = 'DAYVAULT_MOCK_DATA';

  /// Whether mock (demo) data is the *default* backend for a fresh install.
  ///
  /// Build a demo binary with:
  ///
  ///     flutter run --dart-define=DAYVAULT_MOCK_DATA=true
  ///
  /// This is only the starting value. Once the app has run, the in-app toggle
  /// (Profile → Developer) wins, because its choice is persisted. Off by
  /// default so an ordinary build can never show fabricated entries as if they
  /// were the user's own.
  static const bool mockDataEnabledByDefault =
      bool.fromEnvironment(mockDataEnvKey, defaultValue: false);

  /// Environment key for hiding the in-app toggle.
  static const String mockDataToggleEnvKey = 'DAYVAULT_MOCK_DATA_TOGGLE';

  /// Whether the in-app mock-data toggle is offered in the Profile screen.
  ///
  /// On by default: the whole point of the toggle is flipping between demo and
  /// real data on a device without a rebuild. Ship a store build that cannot
  /// enter demo mode at all with:
  ///
  ///     flutter build apk --dart-define=DAYVAULT_MOCK_DATA_TOGGLE=false
  static const bool mockDataToggleVisible =
      bool.fromEnvironment(mockDataToggleEnvKey, defaultValue: true);
}
