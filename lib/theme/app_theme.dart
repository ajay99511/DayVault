import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] for both brightnesses from the design tokens.
///
/// Both themes carry an [AppTokens] extension (read via `context.tokens`) and a
/// seeded Material 3 [ColorScheme], so standard Material widgets (dialogs,
/// switches, snackbars, chips) pick up the brand automatically while bespoke
/// glass widgets read the richer semantic tokens.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark, AppTokens.dark);
  static ThemeData get light => _build(Brightness.light, AppTokens.light);

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.indigo,
      brightness: brightness,
    ).copyWith(
      surface: tokens.surfaceBase,
      error: tokens.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.surfaceBase,
      textTheme: AppTypography.textTheme(brightness, tokens.textPrimary),
      extensions: [tokens],
      dividerColor: tokens.divider,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.accent,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
