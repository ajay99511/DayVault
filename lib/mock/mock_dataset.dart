import 'package:flutter/foundation.dart';

import '../models/types.dart';

/// An immutable, fully-parsed snapshot of the demo fixtures.
///
/// This is the boundary between the *fixture* layer (JSON on disk, relative
/// date tokens, parsing) and the *serving* layer ([MockDataStorageService],
/// which mutates a working copy of this snapshot in memory). Keeping the
/// pristine snapshot immutable is what makes "Reset demo data" a one-liner:
/// throw the working copy away and take a fresh copy of this.
@immutable
class MockDataset {
  /// Every journal entry, private ones included. Callers filter by
  /// `isPrivate` exactly as the real backends do.
  final List<JournalEntry> journalEntries;

  final List<RankingCategory> rankingCategories;

  final List<VisionBoard> visionBoards;

  final UserSettings settings;

  /// The instant the relative date tokens were resolved against. Held so a
  /// long-lived process can tell how stale its demo data is, and so tests can
  /// assert the fixtures were built from the clock they injected.
  final DateTime resolvedAt;

  const MockDataset({
    required this.journalEntries,
    required this.rankingCategories,
    required this.visionBoards,
    required this.settings,
    required this.resolvedAt,
  });

  /// Entries that appear in the ordinary journal feed (the vault is separate).
  Iterable<JournalEntry> get feedEntries =>
      journalEntries.where((e) => !e.isPrivate);

  /// Entries locked behind the Privacy Vault.
  Iterable<JournalEntry> get vaultEntries =>
      journalEntries.where((e) => e.isPrivate);

  @override
  String toString() => 'MockDataset(entries: ${journalEntries.length}, '
      'categories: ${rankingCategories.length}, '
      'boards: ${visionBoards.length}, resolvedAt: $resolvedAt)';
}
