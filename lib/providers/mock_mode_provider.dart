import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/feature_flags.dart';
import '../mock/mock_data_repository.dart';
import '../mock/mock_data_storage_service.dart';
import '../mock/mock_mode_preference.dart';
import 'journal_revision_provider.dart';
import 'stats_provider.dart';

/// Mock ("demo") mode: the app reads a curated fixture set instead of the
/// user's own data.
///
/// The switch itself lives here rather than in `StorageService` because it is
/// an application-level decision about *which* backend to use, and because
/// flipping it has to fan out to the screens (reload) and to the stats cache
/// (recompute). The backend implementations stay unaware that demo mode
/// exists.
///
/// See `.claude/skills/mock-data/SKILL.md` for the rules on keeping the
/// fixtures in step with the models.

/// Holds the parsed fixtures for the process.
///
/// Overridden in `main()` with the instance that was pre-warmed during
/// bootstrap, so a demo launch has its data ready before the first frame.
final mockDataRepositoryProvider = Provider<MockDataRepository>(
  (ref) => MockDataRepository(),
);

/// Persistence for the user's demo-mode choice.
final mockModePreferenceProvider = Provider<MockModePreference>(
  (ref) => const MockModePreference(),
);

/// The value [MockModeNotifier] starts from.
///
/// Overridden in `main()` with the persisted preference read at bootstrap.
/// Defaulting to the compile-time flag keeps tests and any code path that
/// builds a bare `ProviderScope` working without extra setup.
final mockModeInitialValueProvider = Provider<bool>(
  (ref) => FeatureFlags.mockDataEnabledByDefault,
);

/// Whether mock data is currently being served.
final mockModeProvider = NotifierProvider<MockModeNotifier, bool>(
  MockModeNotifier.new,
);

class MockModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(mockModeInitialValueProvider);

  /// Turn demo mode on or off.
  ///
  /// Enabling awaits the fixture load *before* flipping the flag, so
  /// `storageServiceProvider` never observes mock mode without a dataset
  /// behind it. A load failure leaves the app on real data and rethrows —
  /// broken fixtures are a developer error worth surfacing, not something to
  /// swallow into an empty-looking demo.
  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;

    if (enabled) {
      await ref.read(mockDataRepositoryProvider).ensureLoaded();
    }

    state = enabled;
    _notifyDataChanged();

    // Deliberately not awaited. Remembering the choice across restarts is a
    // convenience; the session is already correct without it, and the write
    // goes over a platform channel that is absent in tests and can stall on a
    // device with a misbehaving keystore. Blocking the toggle on it would let
    // a storage problem freeze a UI that has already done its job. Failures
    // are swallowed inside write().
    unawaited(ref.read(mockModePreferenceProvider).write(enabled));
  }

  /// Throw away every change made during this demo session and restore the
  /// pristine fixtures. No-op when demo mode is off.
  void resetData() {
    if (!state) return;
    ref.read(mockDataStorageServiceProvider).reset();
    _notifyDataChanged();
  }

  /// Tell every journal-backed screen to re-read, and drop the cached stats.
  ///
  /// Screens hold their data in local state and reload on
  /// [journalRevisionProvider]; without this the previous backend's entries
  /// would stay on screen until the next navigation.
  void _notifyDataChanged() {
    ref.read(journalRevisionProvider.notifier).bump();
    ref.invalidate(statsProvider);
  }
}

/// The in-memory backend serving the fixtures.
///
/// Cached by Riverpod, so the working copy — and therefore everything created
/// or edited during a demo — survives for as long as demo mode stays on.
/// Constructing it throws if the fixtures were never loaded; [MockModeNotifier]
/// guarantees that cannot happen by loading before it flips the flag.
final mockDataStorageServiceProvider = Provider<MockDataStorageService>(
  (ref) => MockDataStorageService(ref.watch(mockDataRepositoryProvider).dataset),
);
