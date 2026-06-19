import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography. UI text is Outfit; long-form "story" headlines use Libre
/// Baskerville (applied directly at call sites that want the editorial look).
///
/// Text scaling is intentionally *not* clamped here — screens should lay out so
/// that the user's chosen text size is respected.
class AppTypography {
  AppTypography._();

  /// Outfit-based [TextTheme] with ink color applied for the given brightness's
  /// primary text color.
  static TextTheme textTheme(Brightness brightness, Color primary) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.outfitTextTheme(base).apply(
      bodyColor: primary,
      displayColor: primary,
    );
  }
}
