# DayVault — working notes for agents

A Flutter offline-first journal / quantified-self app. Riverpod for state,
ObjectBox on native, localStorage on web, freezed + json_serializable for models.

## This project ships mock (demo) data

There is a **second, complete dataset** behind a feature toggle. With demo mode
on, every screen is served curated fixtures from memory instead of the user's
real data; with it off, nothing changes from an ordinary build.

- Fixtures: `assets/mock/*.json`
- Pipeline and backend: `lib/mock/`
- Toggle: Profile → **DEMO MODE**, or `--dart-define=DAYVAULT_MOCK_DATA=true`
- Contract tests: `test/mock/`

**Whenever you add, rename or remove a field on a model in
`lib/models/types.dart`, add a `StorageService` method, or add an enum value,
you must update the fixtures in the same change.** Read
`.claude/skills/mock-data/SKILL.md` before doing so — it has the checklists,
the relative-date token format, and the invariants the tests enforce.

Run `flutter test test/mock/` to check. A model change that is not mirrored in
the fixtures fails there with the offending file and record index.

The fixtures are **release assets and are committed on purpose** — they ship in
every APK so the in-app toggle works on a downloaded build.

### Two storage providers: pick the right one

| Provider | For | Demo mode |
|---|---|---|
| `storageServiceProvider` | Journal entries, tags, rankings, vision boards, drafts, display name | Substituted |
| `platformStorageServiceProvider` | App lock (`securityEnabled`), biometrics, theme, real-data maintenance | **Never** substituted |

`ref.read(storageServiceProvider)` is the idiom everywhere else, which makes this
an easy slip with serious consequences — reading `securityEnabled` through the
substitutable provider once let a demo-mode launch skip the PIN screen entirely.
`test/mock/mock_mode_isolation_test.dart` enforces the split both behaviourally
and at source level; if you add a device-level read in a new file, add that file
to the list there.

## Adding a field to `JournalEntry` touches five places

1. `lib/models/types.dart` (then `dart run build_runner build`)
2. `lib/screens/entry_editor.dart` — state field, initialiser, the editor
   control, and the `JournalEntry` construction on save
3. `lib/services/backup_service.dart` — the hand-rolled serializers
4. `lib/screens/journal_viewer_screen.dart` if it should be displayed
5. `assets/mock/journal_entries.json` — see above

## Other things worth knowing

- **Images are reference-only.** Entries store an asset id, URL or file path;
  the app never copies a file into its own storage and never deletes one.
- **Journal content is stored as plain text** by design. The Privacy Vault
  separates entries behind a passcode rather than encrypting them. Legacy
  encrypted rows are migrated to plain text once per launch.
- **`journalRevisionProvider`** is how a mutation on one screen reaches the
  others — they live in an `IndexedStack` and stay mounted, so they reload off
  that counter rather than on navigation.
- **Theming is token-driven** (`lib/theme/`). Content tabs are themed; the
  editor, viewer, lock and PIN screens are intentionally always dark.
- **Windows builds fail with "Permission denied" copying a DLL** when a
  `dayvault.exe` from a previous run is still alive. Kill it first, or your
  edits silently do nothing.

## Verification

```bash
flutter analyze
flutter test
```
