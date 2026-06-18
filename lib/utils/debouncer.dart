import 'dart:async';
import 'package:flutter/foundation.dart';

/// Collapses a burst of rapid calls into a single deferred action.
///
/// Each [run] cancels any pending action and schedules a new one [delay] later,
/// so only the final call in a burst actually fires. Call [dispose] from the
/// owner's `dispose()` to cancel any in-flight timer.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Whether an action is currently scheduled but not yet fired.
  bool get isActive => _timer?.isActive ?? false;

  /// Schedule [action], replacing any previously scheduled (un-fired) action.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending action without firing it.
  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
