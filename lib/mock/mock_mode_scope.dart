import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the type returned by overrideWith/overrideWithValue) lives in
// the misc barrel in Riverpod 3, not the main one.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../providers/mock_mode_provider.dart';
import '../services/storage_service.dart';
import 'mock_data_repository.dart';

/// The overrides that plug mock ("demo") mode into a [ProviderScope].
///
/// One call in `main()` wires the whole feature: it seeds the toggle with the
/// preference read at bootstrap, shares the already-warmed fixture repository,
/// and connects [storageBackendOverrideProvider] — the inert seam declared by
/// the storage layer — to the in-memory backend.
///
/// Keeping the wiring here, rather than inside `services/storage_service.dart`,
/// is what lets the storage layer stay ignorant of demo mode: without this
/// call the seam stays null and the app is an ordinary build reading real data.
List<Override> mockModeOverrides({
  required MockDataRepository repository,
  required bool initiallyEnabled,
}) {
  return [
    mockDataRepositoryProvider.overrideWithValue(repository),
    mockModeInitialValueProvider.overrideWithValue(initiallyEnabled),
    storageBackendOverrideProvider.overrideWith(
      (ref) => ref.watch(mockModeProvider)
          ? ref.watch(mockDataStorageServiceProvider)
          : null,
    ),
  ];
}
