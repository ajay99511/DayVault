## Summary

<!-- What does this change do, and why? One or two sentences a reviewer can
     read before the diff. Link the issue it resolves, if any. -->

Closes #

## Type of change

- [ ] `feat` — new user-facing capability
- [ ] `fix` — bug fix
- [ ] `refactor` / `perf` — no behaviour change intended
- [ ] `build` / `chore` / `ci` — toolchain, dependencies, CI
- [ ] `docs` / `test` only

## How it was verified

<!-- What did you run, and on what? "Tests pass" is not enough for UI or
     platform changes — say what you clicked through. -->

- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes
- [ ] Ran the app on: <!-- Android / iOS / Windows / macOS / Linux / Web -->

<!-- For UI changes, add before/after screenshots below. -->

## Project checklist

Tick what applies; delete the rest. See [CONTRIBUTING.md](../CONTRIBUTING.md#project-rules)
for why each one matters.

- [ ] **Model / enum / `StorageService` change** — fixtures in `assets/mock/`
      updated and `flutter test test/mock/` passes
- [ ] **New `JournalEntry` field** — threaded through the editor, the backup
      serializers and the viewer
- [ ] **Generated code** — re-ran `dart run build_runner build` and committed
      the output
- [ ] **Device-level setting** (app lock, biometrics, theme) — read through
      `platformStorageServiceProvider`, never `storageServiceProvider`
- [ ] **Security-sensitive** (PIN, vault, backup encryption, secure storage) —
      described the risk and how it was tested below
- [ ] **Stored-data change** — existing installs migrate without data loss

## Risk and rollout

<!-- Anything a reviewer should look at closely, any data migration, and how to
     back the change out if it goes wrong. Write "Low — <why>" if there is
     nothing to say. -->
