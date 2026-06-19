import 'package:flutter/material.dart';

/// Centralized motion language. Keeping durations/curves in one place makes the
/// app feel consistent and lets us honor the OS "reduce motion" setting in a
/// single, testable spot.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  /// Long, ambient loop (e.g. background orbs).
  static const Duration ambient = Duration(seconds: 10);

  static const Curve standard = Curves.easeInOut;
  static const Curve emphasized = Curves.easeOutCubic;

  /// True when the user has asked the platform to minimize non-essential
  /// motion. Decorative/looping animations should be skipped or frozen when
  /// this is set.
  static bool reduceMotion(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return false;
    return mq.disableAnimations || mq.accessibleNavigation;
  }
}
