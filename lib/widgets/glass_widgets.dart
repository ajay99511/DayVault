import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  /// Lower bound for the backdrop blur sigma (see [build]).
  static const double minBlur = 8.0;

  /// Upper bound for the backdrop blur sigma (see [build]).
  static const double maxBlur = 20.0;

  /// Clamp an arbitrary blur sigma into the GPU-friendly [minBlur, maxBlur]
  /// range. Pure + exposed for property testing.
  static double clampBlur(double blur) => blur.clamp(minBlur, maxBlur);

  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final EdgeInsets padding;
  final Border? border;
  final Gradient? gradient;
  final bool useBackdropFilter;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 12,
    this.opacity = 0.05,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.border,
    this.gradient,
    this.useBackdropFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
      ),
      child: child,
    );

    if (!useBackdropFilter) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: container,
      );
    }

    // Clamp the blur sigma to a sane GPU-friendly range. Very low values are
    // imperceptible (wasted layer) and very high values are expensive on
    // lower-end devices; [minBlur, maxBlur] keeps the effect within budget.
    final clampedBlur = clampBlur(blur);

    // RepaintBoundary isolates the (expensive) BackdropFilter into its own
    // composited layer so unrelated repaints elsewhere in the tree do not force
    // the blur to be re-rasterized.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: clampedBlur, sigmaY: clampedBlur),
          child: container,
        ),
      ),
    );
  }
}

class AnimatedOrb extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const AnimatedOrb({
    super.key,
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
