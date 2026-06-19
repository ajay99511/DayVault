import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Semantic design tokens that resolve per [Brightness].
///
/// Widgets read these via `context.tokens` (see [AppTokensX]) rather than
/// hardcoding colors, so the entire UI flips coherently between light and dark
/// and animates across the transition. The [dark] values are authored to
/// reproduce the app's existing look exactly; [light] is the "frosted daylight"
/// counterpart.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Surfaces
  final Color surfaceBase; // scaffold / base background
  final Color surfaceGlassFill; // fill behind frosted glass
  final Color glassBorder;
  final Color glassGradientHi;
  final Color glassGradientLo;
  final Color divider;

  // Text tiers
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Brand / status
  final Color accent;
  final List<Color> accentGradient;
  final Color success;
  final Color warning;
  final Color danger;

  /// Ambient glow color used by orbs / shadows (accent-tinted).
  final Color glow;

  const AppTokens({
    required this.surfaceBase,
    required this.surfaceGlassFill,
    required this.glassBorder,
    required this.glassGradientHi,
    required this.glassGradientLo,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accent,
    required this.accentGradient,
    required this.success,
    required this.warning,
    required this.danger,
    required this.glow,
  });

  /// Dark theme — reproduces the existing aurora-glass look 1:1.
  static const dark = AppTokens(
    surfaceBase: AppPalette.slate950,
    surfaceGlassFill: Color(0x0DFFFFFF), // white @ 0.05
    glassBorder: Color(0x1AFFFFFF), // white @ 0.10
    glassGradientHi: Color(0x12FFFFFF), // white @ 0.07
    glassGradientLo: Color(0x08FFFFFF), // white @ 0.03
    divider: Color(0x1AFFFFFF), // white @ 0.10
    textPrimary: AppPalette.white,
    textSecondary: Color(0xB3FFFFFF), // white @ 0.70
    textTertiary: Color(0x8AFFFFFF), // white @ 0.54
    textDisabled: Color(0x3DFFFFFF), // white @ 0.24
    accent: AppPalette.indigo,
    accentGradient: [AppPalette.indigo, AppPalette.fuchsia],
    success: AppPalette.emerald,
    warning: AppPalette.amber,
    danger: AppPalette.rose,
    glow: AppPalette.indigo,
  );

  /// Light theme — "frosted daylight": soft slate base, translucent white glass,
  /// dark ink text tiers tuned for a legible (~4.5:1) baseline.
  static const light = AppTokens(
    surfaceBase: AppPalette.slate100,
    surfaceGlassFill: Color(0x99FFFFFF), // white @ 0.60
    glassBorder: Color(0x14000000), // black @ 0.08
    glassGradientHi: Color(0xB3FFFFFF), // white @ 0.70
    glassGradientLo: Color(0x66FFFFFF), // white @ 0.40
    divider: Color(0x14000000), // black @ 0.08
    textPrimary: AppPalette.slate900,
    textSecondary: AppPalette.slate600,
    textTertiary: AppPalette.slate500,
    textDisabled: AppPalette.slate400,
    accent: AppPalette.indigo,
    accentGradient: [AppPalette.indigo, AppPalette.fuchsia],
    success: AppPalette.emerald,
    warning: AppPalette.amber,
    danger: AppPalette.rose,
    glow: AppPalette.indigo,
  );

  @override
  AppTokens copyWith({
    Color? surfaceBase,
    Color? surfaceGlassFill,
    Color? glassBorder,
    Color? glassGradientHi,
    Color? glassGradientLo,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? accent,
    List<Color>? accentGradient,
    Color? success,
    Color? warning,
    Color? danger,
    Color? glow,
  }) {
    return AppTokens(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceGlassFill: surfaceGlassFill ?? this.surfaceGlassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassGradientHi: glassGradientHi ?? this.glassGradientHi,
      glassGradientLo: glassGradientLo ?? this.glassGradientLo,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      accentGradient: accentGradient ?? this.accentGradient,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      glow: glow ?? this.glow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceGlassFill: Color.lerp(surfaceGlassFill, other.surfaceGlassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassGradientHi: Color.lerp(glassGradientHi, other.glassGradientHi, t)!,
      glassGradientLo: Color.lerp(glassGradientLo, other.glassGradientLo, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGradient: [
        Color.lerp(accentGradient.first, other.accentGradient.first, t)!,
        Color.lerp(accentGradient.last, other.accentGradient.last, t)!,
      ],
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

/// Ergonomic access: `context.tokens.textPrimary`.
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.dark;
}
