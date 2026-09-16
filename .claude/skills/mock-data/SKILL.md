---
name: mock-data
description: Keep DayVault's demo (mock) data pipeline in sync with the code. Use this whenever you add, rename, remove or change a field on a model in lib/models/types.dart; whenever you add a method to StorageService; whenever you touch anything under lib/mock/ or assets/mock/; and whenever someone asks about demo mode, mock mode, sample data, the DEMO DATA banner, or why the app is showing entries that are not theirs.
---

# DayVault mock (demo) data

This project ships a **complete second dataset** behind a toggle. When demo mode
is on, the app serves 16 curated journal entries, a private vault, six ranking
categories, two vision boards and a settings record entirely from memory — and
the user's real data is never read, written or touched.

**The rule this skill exists to enforce:** the fixtures are part of the model
contract. A change to a model, an enum, or a storage method that is not
mirrored in `assets/mock/` is an incomplete change.

## How it fits together

```
assets/mock/*.json          Authored fixtures (the data)
        │                   relative date tokens, one file per model family
        ▼
MockDateResolver            Resolves $date / $year against "now"
        │                   lib/mock/mock_date_resolver.dart
        ▼
MockDataLoader              Parses via the models' real fromJson constructors
        │                   lib/mock/mock_data_loader.dart
        ▼
MockDataset                 Immutable, pristine snapshot
        │                   lib/mock/mock_dataset.dart
        ▼
MockDataStorageService      Mutable in-memory StorageService over a copy of it
        │                   lib/mock/mock_data_storage_service.dart
        ▼
storageBackendOverrideProvider   The seam, declared inert in
                                 lib/services/storage_service.dart and wired by
                                 lib/mock/mock_mode_scope.dart
```

`storageServiceProvider` watches that seam, so every screen, provider and
service in the app gets demo data with **zero screen-level changes**. Nothing
outside `lib/mock/` and `lib/config/feature_flags.dart` knows demo mode exists.

## Files

| Path | Role |
|---|---|
| `assets/mock/journal_entries.json` | 16 feed entries + 3 vault entries |
| `assets/mock/ranking_categories.json` | 6 categories with items and drift history |
| `assets/mock/vision_boards.json` | Current-year and previous-year boards |
| `assets/mock/user_settings.json` | Demo profile |
| `lib/mock/mock_fixtures.dart` | Fixture paths, root keys, `fixtureVersion` |
| `lib/mock/mock_date_resolver.dart` | `$date` / `$year` token resolution |
| `lib/mock/mock_data_loader.dart` | Asset read → typed models, fails loudly |
| `lib/mock/mock_dataset.dart` | Immutable parsed snapshot |
| `lib/mock/mock_data_repository.dart` | Process-lifetime cache of the snapshot |
| `lib/mock/mock_data_storage_service.dart` | In-memory `StorageService` |
| `lib/mock/mock_mode_scope.dart` | `mockModeOverrides()` — the one wiring call |
| `lib/mock/mock_mode_preference.dart` | Persists the toggle (secure storage) |
| `lib/mock/mock_mode_banner.dart` | The always-on `DEMO DATA` marker |
| `lib/mock/mock_mode_guard.dart` | Refuses backup export/import during a demo |
| `lib/mock/mock_mode_settings_section.dart` | Profile → DEMO MODE controls |
| `lib/providers/mock_mode_provider.dart` | `mockModeProvider` + notifier |
| `lib/config/feature_flags.dart` | `--dart-define` defaults |
| `test/mock/*` | The contract tests that make drift fail loudly |

## Checklist: I changed a model

Adding a field to `JournalEntry` already means editing four places in
`entry_editor.dart` and the hand-rolled serializers in `backup_service.dart`.
**The fixtures are the fifth.**

1. Add the field to the relevant `assets/mock/*.json` records.
   - A field with a `@Default` is optional in JSON, but add it anyway on at
     least two records — the demo exists to *show* the field, and a field that
     never appears in demo data is a field nobody sees when reviewing the UI.
   - A **required** field breaks the load immediately. `MockDataLoadException`
     names the file and index.
2. Give it realistic values, not `"test"` / `"foo"`. This data is what the app
   looks like in screenshots, reviews and demos.
3. Run `flutter test test/mock/` — this is the gate.
4. If the new field drives a visible surface (a filter, a chip, a chart), add
   an assertion to `test/mock/mock_fixtures_test.dart` that at least one
   fixture exercises it, the way `isSpotlight` / `images` / `history` do.

## Checklist: I changed something else

| Change | What else to do |
|---|---|
| New `StorageService` method | Implement it in `MockDataStorageService`. The compiler enforces this — it is an `extends`, not a mixin. |
| New enum value (`Mood`, `EntryType`, `TimeBucket`) | Use it in at least one fixture if it is meant to be selectable. |
| Renamed a `RankingCategory` default id | Update `ranking_categories.json` — `IdentityScreen` opens on the `movies` id. |
| New `visionBoardCategories` entry | Add a fixture item using it; the test asserts every item's category is known. |
| New `categoryIcons` key | Fine to ignore, but the test asserts every fixture `iconName` resolves. |
| Fixture *shape* change (new root key, new token) | Bump `MockFixtures.supportedVersion` and every file's `fixtureVersion`. |
| New fixture file | Add it to `MockFixtures`, read it in `MockDataLoader.load`, expose it on `MockDataset`, and update the count in the "every declared fixture file is actually read" test. No pubspec edit needed — `assets/mock/` is registered as a directory. |

## Authoring rules

**Dates are always relative.** Never write a literal date for anything the user
should see as recent. Use the tokens:

```json
"date":  { "$date": { "days": -3, "hour": 21, "minute": 40 } }
"date":  { "$date": { "years": -1, "hour": 19 } }
"year":  { "$year": { "years": 0 } }
```

Fields: `years`, `months`, `days` (calendar offsets, any sign) and
`hour` / `minute` (absolute, defaulting to 09:00). Offsets apply to calendar
*components*, not as a `Duration`, so `years: -1` lands on the same month and
day — which is what makes "On this day" work across a leap year. An unknown
field or a non-integer value throws; fixtures are source code, not input.

**Invariants the tests hold you to** (`test/mock/mock_fixtures_test.dart`):

- Exactly **16** non-private feed entries, plus private vault entries.
- An unbroken run of entries on today and the three days before, so the streak
  is non-zero.
- Exactly two entries at the same month/day in past years, for "On this day".
- No entry dated on a future *day*.
- At least 8 distinct moods; examples of spotlight, tags, images, location,
  feeling and time bucket.
- Ranks are a contiguous `1..n` per category; ids unique; ratings in `0..5`.
- At least one item with ≥2 history snapshots (drift chart).
- A vision board for the current year, mixing achieved and outstanding items.
- `securityEnabled` and `biometricsEnabled` are **false** — demo mode must
  never put a PIN wall in front of fabricated data.
- Every record round-trips through `jsonEncode`/`jsonDecode`.

**Images are `webUrl` references only.** Gallery asset ids and file paths do
not resolve on someone else's device. Use HTTPS URLs on a host in
`defaultTrustedDomains` (`lib/services/image_service.dart`) so demo data never
normalises a source the real editor would reject. Demo images need network;
they fall back to the placeholder offline.

**Ids are stable and namespaced** — `mock-entry-01`, `mock-rank-movie-01`,
`mock-vision-01`. Tests and bug reports reference them. Never renumber.

**Write like a person, not a fixture generator.** Specific, ordinary, slightly
imperfect. This is the app's shop window.

## Turning it on

```bash
# Runtime, on any build: Profile → DEMO MODE → Show demo data. Persists.

# Launch straight into it:
flutter run --dart-define=DAYVAULT_MOCK_DATA=true

# Ship a build that can never enter demo mode:
flutter build apk --dart-define=DAYVAULT_MOCK_DATA_TOGGLE=false
```

## The isolation rule: content vs. device

Demo mode substitutes **journal content only**. Two providers encode that, and
picking the wrong one is the single most dangerous mistake available in this
codebase:

| Provider | Use it for | Demo mode |
|---|---|---|
| `storageServiceProvider` | Journal entries, tags, rankings, vision boards, drafts, the display name — anything that *is* the demo | Substituted |
| `platformStorageServiceProvider` | The app lock (`securityEnabled`), biometric enrolment, the theme, real-data maintenance | **Never** substituted |

`ref.read(storageServiceProvider)` is the idiom everywhere else, so reaching for
it on a device-level value is an easy and serious slip. Three real bugs came from
exactly that, and all three are now regression-tested in
`test/mock/mock_mode_isolation_test.dart`:

1. **PIN-lock bypass.** `RootOrchestrator` read `securityEnabled` through the
   substitutable provider. Demo mode's fixture says `securityEnabled: false`, so
   a demo-mode launch skipped the lock screen — and the user could then switch
   demo mode off from Profile and read the real journal, never having entered
   the PIN.
2. **Security-flag divergence.** `PinSetupScreen` / `PinManagementScreen` set the
   real PIN (always real, via `SecurityService`) but wrote `securityEnabled` to
   the active backend. Setting up a PIN during a demo left an install with a real
   PIN and `securityEnabled: false` — a silent downgrade.
3. **Theme loss.** The theme was read and written through the substitutable
   provider, so entering demo mode replaced the user's choice with the fixture's,
   and changing it during a demo appeared to work and reverted on restart.

A fourth class is blocked rather than routed, because there is no correct
backend for it — see `lib/mock/mock_mode_guard.dart`: **backup export** (would
write a real-looking file full of fixtures, which a later restore merges into
real data) and **backup import/restore** (would write into a store discarded on
restart, looking exactly like losing the backup).

`test/mock/mock_mode_isolation_test.dart` also runs a **source-level** check over
`main.dart`, `pin_setup_screen.dart`, `pin_management_screen.dart`,
`lock_screen.dart` and `theme_provider.dart`, asserting none of them mention
`storageServiceProvider` outside a comment. If you add a device-level read
somewhere new, add the file to that list.

## Safety properties — do not regress these

- **Demo mode never touches real storage.** `MockDataStorageService` holds
  lists and maps; no ObjectBox, no localStorage, no secure storage, no files.
  While it is on, the platform backend is never constructed at all.
- **Demo data never survives a restart.** It lives in the provider cache.
  Only the *toggle* is persisted.
- **Demo mode is always visibly labelled** by `MockModeBanner`. A screenshot
  or bug report built on fabricated entries is worse than useless. Do not make
  the banner dismissible or conditional.
- **A broken fixture never blocks launch.** `hydrateMockMode()` in `main.dart`
  downgrades to real data. The test suite is what makes the failure loud.
- **The app lock behaves identically either way.** Demo mode can never answer
  "is this install PIN-protected?".
- **Backups cannot cross the boundary** in either direction.

## Shipping it

The fixtures are **release assets and must be committed** — they are registered
under `flutter: assets:` and bundled into every APK/IPA, which is what makes the
in-app toggle work on a downloaded build. `assets/mock/` is roughly 39 KB; the
mock backend is a few KB of Dart. Nothing is tree-shaken out when the toggle is
off, and that is intended: the runtime toggle needs both present.

Verify packaging with `flutter build bundle` and check
`build/flutter_assets/assets/mock/`.
