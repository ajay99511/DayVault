import 'package:flutter/material.dart';

/// Brand & neutral palette — the raw, brightness-independent ingredients of the
/// design system.
///
/// These are *primitives*: screens should not consume most of them directly.
/// Instead, semantic [AppTokens] map these primitives to roles (surfaces, text
/// tiers, etc.) that flip between light and dark. The brand accents
/// ([indigo]/[fuchsia]/[emerald]/[amber]/[rose]) live in both modes and are the
/// one group that *is* meant to be referenced widely.
class AppPalette {
  AppPalette._();

  // ─── Brand accents (mode-independent) ─────────────────────────────────────
  static const indigo = Color(0xFF6366F1);
  static const fuchsia = Color(0xFFD946EF);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);

  // ─── Dark neutral ramp (today's "slate" surfaces) ─────────────────────────
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  // Pure white used as the "ink-on-dark" primary.
  static const white = Color(0xFFFFFFFF);
}
