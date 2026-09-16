import 'package:flutter/foundation.dart';

import 'mock_data_loader.dart';
import 'mock_dataset.dart';

/// Caches the parsed [MockDataset] for the lifetime of the process.
///
/// The fixtures are read from assets — an async operation — but
/// `storageServiceProvider` is a synchronous `Provider<StorageService>`. This
/// closes that gap: whoever *enables* mock mode awaits [ensureLoaded] first,
/// and the provider afterwards reads the already-resolved dataset through
/// [dataset]. Concurrent callers share one in-flight load.
class MockDataRepository {
  final MockDataLoader _loader;

  MockDataset? _dataset;
  Future<MockDataset>? _inFlight;

  MockDataRepository({MockDataLoader? loader})
      : _loader = loader ?? MockDataLoader();

  /// A repository pre-populated with [dataset], for tests and previews that
  /// build a dataset directly instead of reading assets.
  factory MockDataRepository.withDataset(MockDataset dataset) =>
      MockDataRepository().._dataset = dataset;

  bool get isLoaded => _dataset != null;

  /// The loaded dataset.
  ///
  /// Throws [StateError] when mock mode was switched on without awaiting
  /// [ensureLoaded]. That is a wiring bug, and an exception naming it is far
  /// more useful than an empty demo that looks like missing fixtures.
  MockDataset get dataset {
    final loaded = _dataset;
    if (loaded == null) {
      throw StateError(
        'Mock dataset requested before it was loaded. Call '
        'MockDataRepository.ensureLoaded() before enabling mock mode.',
      );
    }
    return loaded;
  }

  /// Load the fixtures once. Subsequent calls return the cached dataset.
  ///
  /// [now] only applies to the load that actually reads the fixtures; pass
  /// [forceReload] to re-resolve against a different clock.
  Future<MockDataset> ensureLoaded({
    DateTime? now,
    bool forceReload = false,
  }) {
    if (forceReload) {
      _dataset = null;
      _inFlight = null;
    }

    final cached = _dataset;
    if (cached != null) return Future.value(cached);

    return _inFlight ??= _loader.load(now: now).then((loaded) {
      _dataset = loaded;
      _inFlight = null;
      return loaded;
    }, onError: (Object error, StackTrace stack) {
      // Clear the in-flight future so a later attempt can retry rather than
      // replaying the same failure forever.
      _inFlight = null;
      debugPrint('Mock fixture load failed: $error');
      Error.throwWithStackTrace(error, stack);
    });
  }
}
