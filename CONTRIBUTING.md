# Contributing to DayVault

Thanks for helping improve DayVault. This guide covers how to get set up, the
rules specific to this codebase, and what a pull request needs before it can be
merged.

By taking part you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).
**Security issues are not reported here.** Follow [SECURITY.md](SECURITY.md).

---

## Ways to contribute

- **Report a bug** or **suggest a feature** using the issue forms. Blank issues
  are turned off so reports arrive with the details needed to act on them.
- **Fix something.** For anything beyond a small fix, open an issue first so we
  can agree on the approach before you spend time on it.
- **Improve the docs**, including this file, when something here is wrong or
  unclear.

## Getting set up

**Prerequisites**

| For | You need |
|---|---|
| Everything | Flutter, stable channel, 3.47 or newer (`flutter --version`) |
| Android | Android SDK and JDK 17 |
| Windows | Visual Studio 2022 with the *Desktop development with C++* workload |
| iOS / macOS | Xcode |

**First run**

```bash
git clone https://github.com/ajay99511/DayVault.git
cd DayVault
flutter pub get
flutter run
```

To explore every screen without entering your own data, turn on demo mode:
Profile → **DEMO MODE**, or `flutter run --dart-define=DAYVAULT_MOCK_DATA=true`.
See [docs/MOCK_DATA.md](docs/MOCK_DATA.md).

## Workflow

1. Branch from `main`, using the commit type as a prefix:
   `feat/…`, `fix/…`, `docs/…`, `chore/…`, `refactor/…`.
2. Keep each pull request to **one concern**. A dependency upgrade, a reformat
   and a feature are three pull requests, because a diff that mixes them can't
   be reviewed or reverted cleanly.
3. Run the checks below locally before pushing.
4. Open the pull request. The template fills in automatically; complete it.

### Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/), with an
optional scope:

```
feat(identity): add favourites filter
fix(vault): keep private flag when editing an entry
chore(deps): bump file_picker to 13
build(android): move to AGP 9.1
```

Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`,
`chore`. Write the subject in the imperative ("add", not "added"), and use the
body to explain *why* when it isn't obvious.

## Checks

CI runs these on every push and pull request
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)). They must pass before
merge:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # must produce no diff
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

`dart format` also runs, but it doesn't block merges yet, because much of the
existing code predates it. Format the files you change (`dart format <file>`),
and don't reformat files you aren't otherwise touching.

**Tests.** New services need unit tests; new screens and widgets need widget
tests for their main states. A bug fix should come with a test that fails
without it.

## Project rules

These are specific to DayVault. Each one exists because getting it wrong has
caused a real bug.

### Model changes must update the demo fixtures

The app ships a second, complete dataset in `assets/mock/` that is served when
demo mode is on. **If you add, rename or remove a field on a model in
`lib/models/types.dart`, add an enum value, or add a `StorageService` method,
update the fixtures in the same pull request** and run:

```bash
flutter test test/mock/
```

A model change that isn't reflected in the fixtures fails there, naming the
file and the record. [docs/MOCK_DATA.md](docs/MOCK_DATA.md) explains the token
format and the invariants.

### A new `JournalEntry` field touches five places

1. `lib/models/types.dart`, then `dart run build_runner build`
2. `lib/screens/entry_editor.dart`: the state field, its initialiser, the
   control, and the `JournalEntry` built on save
3. `lib/services/backup_service.dart`: the hand-written serializers
4. `lib/screens/journal_viewer_screen.dart`, if it should be displayed
5. `assets/mock/journal_entries.json`

If you miss step 2, edits silently drop the field. If you miss step 3, backups
silently lose it.

### Generated code is committed

Freezed, json_serializable, Riverpod and ObjectBox output (`*.g.dart`,
`*.freezed.dart`, `lib/objectbox-model.json`) is checked in. After changing an
annotated source file, regenerate it and commit the result. CI fails if
regenerating changes anything.

### Pick the right storage provider

| Provider | Use it for | In demo mode |
|---|---|---|
| `storageServiceProvider` | Journal content: entries, tags, rankings, vision boards, drafts, display name | Replaced by fixtures |
| `platformStorageServiceProvider` | Facts about this install: app lock, biometrics, theme | **Never** replaced |

Reading a device setting through `storageServiceProvider` once let a demo-mode
launch skip the PIN screen. `test/mock/mock_mode_isolation_test.dart` enforces
this split. If you add a device-level read in a new file, add that file to its
list.

### Images are references, never copies

An entry stores an asset id, URL or file path. The app never copies an image
into its own storage and never deletes a user's file.

### Cross-screen refresh goes through `journalRevisionProvider`

The main tabs live in an `IndexedStack` and stay mounted, so they don't reload
when you navigate to them. After changing journal data, bump
`journalRevisionProvider` so the other screens pick up the change.

### Theming is token-driven

Use the tokens in `lib/theme/` rather than hard-coded colours. Content tabs
follow the theme; the editor, viewer, lock and PIN screens are intentionally
always dark.

## Troubleshooting

- **Windows build: "Permission denied" copying a DLL, or a "corrupt PDB" error.**
  A `dayvault.exe` from a previous run is still alive, or a build was
  interrupted. Close the app, delete `build/windows`, and rebuild.
- **Android: `INSTALL_FAILED_INSUFFICIENT_STORAGE`.** The emulator is out of
  space. Wipe its data from Android Studio's Device Manager, or raise its
  internal storage.
- **Kotlin "unresolved reference" inside a plugin after upgrading packages.**
  The incremental build cache is stale. Run `flutter clean` and rebuild.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
