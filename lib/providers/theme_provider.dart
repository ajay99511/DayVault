import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// App theme mode (System / Light / Dark), persisted in [UserSettings.theme].
///
/// Initializes from saved settings on first build and writes any change back
/// through [StorageService] so the choice survives restarts. Defaults to dark
/// to preserve the app's historical behavior when no preference is stored.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      final settings = ref.read(storageServiceProvider).getSettings();
      return _decode(settings.theme);
    } catch (_) {
      // Storage not ready (e.g. failed init) — fall back to dark.
      return ThemeMode.dark;
    }
  }

  /// Update the active mode and persist it.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final storage = ref.read(storageServiceProvider);
    final settings = storage.getSettings();
    await storage.saveSettings(settings.copyWith(theme: _encode(mode)));
  }

  static ThemeMode _decode(String value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
