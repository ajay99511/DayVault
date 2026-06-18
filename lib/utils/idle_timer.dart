import 'dart:async';
import 'package:flutter/foundation.dart';

/// Fires [onIdle] once [timeout] elapses without a [poke].
///
/// Each [poke] restarts the countdown, so the callback only runs after a full
/// quiet period. Used to wind down idle UI work (e.g. stop an animation /
/// clear a partially-entered PIN) when the user walks away. Call [dispose] from
/// the owner's `dispose()`.
class IdleTimer {
  final Duration timeout;
  final VoidCallback onIdle;
  Timer? _timer;

  IdleTimer({required this.timeout, required this.onIdle});

  /// Whether the idle countdown is currently running.
  bool get isActive => _timer?.isActive ?? false;

  /// Register activity — restarts the idle countdown.
  void poke() {
    _timer?.cancel();
    _timer = Timer(timeout, onIdle);
  }

  /// Stop the countdown without firing [onIdle].
  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
