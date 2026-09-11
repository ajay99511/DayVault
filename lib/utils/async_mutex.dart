import 'dart:async';

/// Runs async operations one at a time, in the order they were requested.
///
/// Dart's single-threaded event loop prevents *data races*, but not
/// *interleaving*: any `await` is a yield point, so two overlapping
/// read-modify-write sequences can both read the old value and the second write
/// silently discards the first. That is a lost update, and it needs a lock like
/// any other concurrent system.
///
/// The concrete case this was written for: the journal draft index is stored as
/// one JSON blob, and the entry editor autosaves on a timer while other flows
/// can trigger a save at the same moment. Both would read the same id list,
/// each append its own id, and the later write would drop the earlier id —
/// leaving an encrypted draft blob in secure storage that nothing could ever
/// find or clear.
///
/// A failing action completes only *its own* future with the error; the queue
/// keeps running, so one failure cannot wedge every later caller.
class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  /// Number of operations queued or running. Exposed for tests and diagnostics.
  int get pending => _pending;
  int _pending = 0;

  /// Queue [action], resolving with its result once every earlier action has
  /// finished. Actions never overlap.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending++;

    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        // Complete this caller's future with the error but let the chain
        // continue, so a single failure does not block the queue forever.
        completer.completeError(error, stackTrace);
      } finally {
        _pending--;
      }
    });

    return completer.future;
  }
}
