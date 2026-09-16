# Demo (mock) data

DayVault can fill itself with a curated sample dataset so you can explore every
screen, record a walkthrough, or check a UI change against realistic content —
without typing a single entry.

While demo mode is on, **your own data is not read, written or touched.** The
demo backend is entirely in-memory; the real storage layer is not even
constructed. Switching back returns your journal exactly as it was.

---

## Turning it on

### On a device, no rebuild

**Profile → DEMO MODE → Show demo data.**

The choice persists across restarts, and a `DEMO DATA` badge sits at the top of
every screen for as long as it is on.

### At launch

```bash
flutter run --dart-define=DAYVAULT_MOCK_DATA=true
```

This only sets the *default* for a fresh install; once you have used the in-app
toggle, your choice wins.

### Never

```bash
flutter build apk --dart-define=DAYVAULT_MOCK_DATA_TOGGLE=false
```

Compiles the toggle out entirely, and forces demo mode off regardless of any
previously stored preference. Use this for store builds.

---

## What you get

| Surface | Demo content |
|---|---|
| Journal | 16 entries — 9 stories, 7 events — across the last two months and two past years |
| Privacy Vault | 3 private entries, hidden from the feed, stats and tags |
| On this day | 2 entries dated today in previous years |
| Streak | An unbroken run ending today |
| Filters | 11 moods, ~14 tags, spotlighted entries, both entry types |
| Images | Photo references on 6 entries (needs network) |
| Calendar | Entries spread across ~9 weeks for the consistency chart |
| Identity | 6 ranking categories, 29 items, ratings, notes, drift history |
| Vision board | Current year (8 goals, 3 achieved) and last year (4, all achieved) |
| Profile | A demo display name; security deliberately off |

Everything is **fully interactive**. Create, edit, delete, tag, vault, reorder,
reset — it all behaves exactly as it does on real data.

## What demo mode deliberately will not do

Demo mode replaces journal **content** and nothing else. Everything about your
device stays real and untouched:

- **Your PIN still applies.** If the app is PIN-locked it stays PIN-locked, demo
  mode or not. Demo mode cannot answer "is this install protected?".
- **Your theme is yours.** Entering demo mode does not change it, and changing
  it during a demo persists for real.
- **Biometric enrolment and PIN changes are real**, because they always were —
  the matching settings are written to real storage alongside them.

Two things are switched off while demo data is on, because there is no honest
way to do them:

- **Exporting a backup**, which would produce a file indistinguishable from a
  real backup but full of sample entries — and restoring it later would merge
  those samples into your actual journal.
- **Restoring a backup**, which would load into the in-memory store and vanish
  on restart, looking exactly like losing the backup.

Both tell you why and point you at the toggle.

## What happens to your demo edits

They live only in memory:

- **Reset demo data** (Profile → DEMO MODE) restores the original fixtures.
- Restarting the app does the same.
- Turning demo mode off discards them.

Nothing you do in demo mode is ever written to disk.

---

## For contributors

The fixtures live in `assets/mock/` and are part of the model contract: if you
change a model in `lib/models/types.dart`, update them in the same change.

`flutter test test/mock/` is the gate — it parses every fixture through the
models' real `fromJson` constructors, round-trips them, and asserts the demo
invariants (16 feed entries, a live streak, "On this day" matches, contiguous
ranks, a current-year vision board, and so on).

The full checklist, the relative-date token format and the design rationale are
in [`.claude/skills/mock-data/SKILL.md`](../.claude/skills/mock-data/SKILL.md).

### Packaging

The fixtures are committed and registered under `flutter: assets:` as a
directory, so they are bundled into every release build — that is what lets the
in-app toggle work on a downloaded APK with no rebuild. Roughly 39 KB of JSON.
Verify with `flutter build bundle` and check `build/flutter_assets/assets/mock/`.

Nothing is tree-shaken when the toggle is off; the runtime toggle needs both
backends present. Use `--dart-define=DAYVAULT_MOCK_DATA_TOGGLE=false` for a build
that cannot enter demo mode at all.

### How the swap works

`lib/services/storage_service.dart` declares an inert seam:

```dart
final storageBackendOverrideProvider = Provider<StorageService?>((ref) => null);

final storageServiceProvider = Provider<StorageService>((ref) {
  return ref.watch(storageBackendOverrideProvider) ??
      createPlatformStorageService();
});
```

`main()` calls `mockModeOverrides()` from `lib/mock/mock_mode_scope.dart`, which
connects that seam to the in-memory backend when `mockModeProvider` is on.
Because every screen already reads through `storageServiceProvider`, the whole
feature required **no changes to any screen's data code** — the storage layer
itself stays unaware that demo mode exists.
