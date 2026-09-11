import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic counter bumped on every journal create/update/delete.
///
/// Screens that render journal data (`JournalScreen`, `CalendarScreen`,
/// `IdentityScreen`, `ProfileScreen`, the vault) watch this and reload, so a
/// mutation made from one surface refreshes the others even while they are
/// kept alive in the background by the shell's `IndexedStack`.
///
/// This lives in `providers/` rather than in the storage contract. It is a
/// presentation concern — "something changed, re-read" — and putting it beside
/// the `StorageService` interface made the most stable file in the app depend
/// on the state-management library, which is the wrong direction: dependencies
/// should point from volatile to stable.
final journalRevisionProvider =
    NotifierProvider<JournalRevisionNotifier, int>(JournalRevisionNotifier.new);

class JournalRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signal that journal data changed so dependent screens reload.
  void bump() => state++;
}
