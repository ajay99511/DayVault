import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How the active category's items are ordered for display. [manual] keeps the
/// user's drag-ordered rank; the others are derived (and disable reordering).
enum ItemSort { manual, ratingDesc, dateDesc }

/// The Identity screen's view choices — how the user is *looking* at their
/// rankings, as opposed to the rankings themselves.
@immutable
class IdentityViewState {
  /// Privacy masking: replaces item names, subtitles, notes and cover art with
  /// bullets so the screen can be shown to someone standing nearby.
  ///
  /// **Off by default, on purpose.** Defaulting it on meant every cold start
  /// opened the tab on a wall of `••••••••` that the user had to find and
  /// switch off before the screen was usable — and, because it also disables
  /// search, before most of the screen worked at all. It is a thing you reach
  /// for in a moment, not a posture the app should assume; once switched on it
  /// is remembered, which is what makes defaulting it off safe.
  final bool masked;

  /// Restrict the category tabs to the ones marked favourite.
  final bool favoritesOnly;

  /// Ordering applied to the active category's items.
  final ItemSort sort;

  /// Category id to reopen on, or null to fall back to the first one.
  ///
  /// Held as an id rather than a tab index because categories can be added,
  /// deleted and filtered between sessions; a stale id simply misses and the
  /// screen falls back, whereas a stale index would silently open the wrong
  /// category.
  final String? activeCategoryId;

  const IdentityViewState({
    this.masked = false,
    this.favoritesOnly = false,
    this.sort = ItemSort.manual,
    this.activeCategoryId,
  });

  static const IdentityViewState defaults = IdentityViewState();

  IdentityViewState copyWith({
    bool? masked,
    bool? favoritesOnly,
    ItemSort? sort,
    String? activeCategoryId,
  }) {
    return IdentityViewState(
      masked: masked ?? this.masked,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sort: sort ?? this.sort,
      activeCategoryId: activeCategoryId ?? this.activeCategoryId,
    );
  }

  Map<String, dynamic> toJson() => {
        'masked': masked,
        'favoritesOnly': favoritesOnly,
        // Stored by name, not index, so reordering the enum can never silently
        // reinterpret a saved value as a different sort.
        'sort': sort.name,
        'activeCategoryId': activeCategoryId,
      };

  /// Tolerant of missing, null and wrong-typed fields: a preference blob
  /// written by an older build must degrade to defaults, never throw.
  factory IdentityViewState.fromJson(Map<String, dynamic> json) {
    final rawSort = json['sort'];
    return IdentityViewState(
      masked: json['masked'] is bool ? json['masked'] as bool : false,
      favoritesOnly:
          json['favoritesOnly'] is bool ? json['favoritesOnly'] as bool : false,
      sort: ItemSort.values.firstWhere(
        (s) => s.name == rawSort,
        orElse: () => ItemSort.manual,
      ),
      activeCategoryId:
          json['activeCategoryId'] is String && (json['activeCategoryId'] as String).isNotEmpty
              ? json['activeCategoryId'] as String
              : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IdentityViewState &&
      other.masked == masked &&
      other.favoritesOnly == favoritesOnly &&
      other.sort == sort &&
      other.activeCategoryId == activeCategoryId;

  @override
  int get hashCode =>
      Object.hash(masked, favoritesOnly, sort, activeCategoryId);
}

/// Persists [IdentityViewState] across restarts.
///
/// Stored outside `StorageService` deliberately. These are facts about the
/// device and the person holding it — which tab they left open, whether they
/// want names hidden — not journal content, so they must survive a demo-mode
/// switch in both directions: turning demo mode on must not hand the user the
/// fixtures' view state, and a choice made during a demo must not be discarded
/// with the demo data. Routing them through `storageServiceProvider` would do
/// exactly the wrong thing on both counts, and routing them through
/// `platformStorageServiceProvider` would mean widening `UserSettings` (and
/// therefore the ObjectBox entity, the web backend and the mock fixtures) for
/// four pieces of view state.
///
/// `flutter_secure_storage` is used because it is already a dependency on
/// every target this app ships to — not because any of this is a secret; the
/// same reasoning as `MockModePreference`.
///
/// Every operation is best-effort. Losing this preference costs the user their
/// last tab and sort order; it must never keep the screen from rendering.
class IdentityViewPreferences {
  static const String storageKey = 'dv_identity_view_prefs';

  final FlutterSecureStorage _storage;

  const IdentityViewPreferences({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<IdentityViewState> read() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null) return IdentityViewState.defaults;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return IdentityViewState.defaults;
      return IdentityViewState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('Identity view preferences unreadable, using defaults: $e');
      return IdentityViewState.defaults;
    }
  }

  Future<void> write(IdentityViewState state) async {
    try {
      await _storage.write(
          key: storageKey, value: jsonEncode(state.toJson()));
    } catch (e) {
      // The in-memory state has already changed, so the current session is
      // correct either way; only its survival across restarts is lost.
      debugPrint('Identity view preferences could not be persisted: $e');
    }
  }
}

/// Injection point for [IdentityViewPreferences] so tests can substitute a
/// fake without a platform channel.
final identityViewPreferencesProvider = Provider<IdentityViewPreferences>(
  (ref) => const IdentityViewPreferences(),
);
