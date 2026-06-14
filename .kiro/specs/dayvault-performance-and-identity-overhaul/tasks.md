# Implementation Plan: DayVault Performance and Identity Overhaul

## Overview

This plan converts the six-category overhaul (profile/identity, rendering performance, data layer performance, state management, resource leaks, and security hardening) — plus four additional requirements discovered during code review (backup image serialization fix, username profile management, backup restore UI, and spotlight/tag filtering) — into incremental Dart/Flutter coding tasks. Each task builds on the previous ones, wiring all changes into the existing DayVault codebase without breaking any existing functionality.

---

## Tasks

- [ ] 1. Add data models and update pubspec dependencies
  - [ ] 1.1 Add `flutter_image_compress` and `image` packages to `pubspec.yaml`; remove `device_info_plus`, `battery_plus`, and `system_info2`; add `fake_async` to dev dependencies
    - Edit `pubspec.yaml`: add `flutter_image_compress: ^2.4.0`, add `image: ^4.2.0` (Dart image library), delete the three obsolete packages (`device_info_plus`, `battery_plus`, `system_info2`)
    - Add `fake_async: ^1.3.2` to `dev_dependencies` (required for task 4.6 idle animation timer tests)
    - Run `flutter pub get` and confirm the dependency tree resolves without conflicts
    - _Requirements: 2.1, 2.2_

  - [ ] 1.2 Create `lib/models/stats.dart` with the `JournalStats` data class
    - Define all six fields: `streak`, `totalEntries`, `averageMood`, `totalWordCount`, `journalAgeInDays`, `topTags`
    - Provide a `const JournalStats.empty()` factory that satisfies all zero-state display values from Req 1.3
    - `averageMood` is `-1.0` in empty state (maps to "—" in the UI)
    - _Requirements: 1.1, 1.3_

  - [ ] 1.3 Create `lib/models/paged_result.dart` with `PaginationCursor` and `PagedResult<T>`
    - `PaginationCursor` wraps `int _lastId` with a private constructor (only `StorageService` may create instances)
    - `PagedResult<T>` holds `List<T> items` and `PaginationCursor? nextCursor`
    - _Requirements: 6.1_

  - [ ] 1.4 Add `BackupStage` enum and `ChangePinResult` class to their respective service files
    - Add `enum BackupStage { idle, serializing, encrypting, writing, reading, decrypting, restoring }` to `lib/services/backup_service.dart`
    - Add `class ChangePinResult { final bool success; final String? error; }` to `lib/services/security_service.dart`
    - Add `static const String _rekeyPendingKey = 'rekey_pending'` private constant to `SecurityService` (for crash-recovery guard in `changePin`)
    - _Requirements: 15.3, 15.4, 16_

  - [ ] 1.5 Create `lib/providers/` directory with provider barrel file
    - Create `lib/providers/` directory
    - Create `lib/providers/providers.dart` as a barrel export file (will export `stats_provider.dart`, `auth_provider.dart`, `backup_provider.dart` as they are created)
    - This directory is required before tasks 2.1 and 7.5 can write their provider files
    - _Requirements: 1.1, 11.1_

- [ ] 2. StatsProvider — journaling statistics computation
  - [ ] 2.1 Create `lib/providers/stats_provider.dart` implementing `StatsNotifier` as a Riverpod `AsyncNotifier`
    - Implement `build()` to call `storageServiceProvider`'s `getJournal()` once and pass entries to `_computeStats()`
    - Implement `_computeStats(List<JournalEntry> entries)` in a single `fold()` pass that computes all six stats
    - Streak calculation: consecutive calendar days ending today or yesterday
    - Top-3 tags: frequency descending, alpha-sorted on tie; at most 3 results
    - Expose `void invalidate()` to reset cached data; call `ref.invalidateSelf()`
    - After creating this file run `flutter pub run build_runner build --delete-conflicting-outputs` to generate `stats_provider.g.dart`
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ]* 2.2 Write property test for stats computation (Property 1)
    - **Property 1: Stats computation is correct for any entry collection**
    - Generate lists of 0–500 `JournalEntry` objects with random moods, dates, tags, and content
    - Assert `totalEntries == entries.length`, `totalWordCount` equals manual whitespace-split count, `averageMood` equals arithmetic mean of `mood.index` values (or -1.0 if empty), `journalAgeInDays` uses oldest entry date, `topTags` has at most 3 items alpha-sorted on tie
    - Include streak-specific edge cases as unit tests alongside the property test: single entry today, single entry yesterday, single entry two days ago, gap in consecutive days, all entries on the same day
    - **Validates: Requirements 1.1, 1.3**

  - [ ] 2.3 Refactor `ProfileScreen` to remove device diagnostics and display `StatsProvider` output
    - Delete all imports of `device_info_plus`, `battery_plus`, `system_info2`
    - Delete `_initSystemInfo()`, `_startMetricsTimer()`, `_updateMetrics()`, `Timer`, `Battery`, `DeviceInfoPlugin`, `SysInfo` fields and methods
    - Delete the "REAL-TIME DIAGNOSTICS" section and its stat cards
    - Replace the header card with `settings.username ?? 'Journaler'` (Req 2.3) — the full inline edit affordance is added in task 2.5
    - Watch `statsNotifierProvider`; display shimmer on loading, 6 stat cards on data, empty-state on error, non-blocking `SnackBar` on error
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.7, 2.3_

  - [ ]* 2.4 Write unit tests for `StatsNotifier` caching and error handling
    - Verify provider calls `getJournal()` exactly once for multiple `ref.read` calls (Req 1.2)
    - Verify `ProfileScreen` renders empty-state cards when `StatsNotifier` returns `AsyncValue.error` (Req 1.7)
    - _Requirements: 1.2, 1.7_

  - [ ] 2.5 Add username inline edit to `ProfileScreen` header
    - Replace the static `settings.username ?? 'Journaler'` text in the header with a `Row` containing a `CircleAvatar` (first letter initial), a `Column` (display name + entry count subtitle), and an edit `IconButton`
    - `IconButton.onPressed` calls `_showUsernameEditDialog()` which presents an `AlertDialog` with a `TextField(maxLength: 50)` pre-populated with the current username
    - On SAVE: call `storageService.saveSettings(settings.copyWith(username: trimmedValue.isEmpty ? null : trimmedValue))`; update local state with `setState`
    - On CANCEL or empty save: dismiss dialog with no changes
    - After save, the header updates to show the new name immediately without reloading from storage
    - Verify the updated username persists across app restarts
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5_

- [ ] 3. Checkpoint — stats and dependency changes
  - Ensure `flutter pub get` succeeds, the app compiles on all target platforms, and `ProfileScreen` displays stat cards and the inline username edit button
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Rendering performance — GlassContainer and AnimationController
  - [ ] 4.1 Refine `GlassContainer` in `lib/widgets/glass_widgets.dart` to wrap `BackdropFilter` in `RepaintBoundary` and clamp blur sigma
    - When `useBackdropFilter: true`: widget tree order must be `RepaintBoundary → ClipRRect → BackdropFilter → Container → child`
    - Clamp `blur` to `[8.0, 20.0]` before passing to `ImageFilter.blur`; compute `_clampedBlur = blur.clamp(8.0, 20.0)` at the top of `build()`
    - When `useBackdropFilter: false` (default): do NOT instantiate `BackdropFilter` at all
    - Existing call sites without the parameter remain unaffected (the parameter already defaults to `false`)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ]* 4.2 Write property tests for `GlassContainer` blur clamping (Properties 2 and 3)
    - **Property 2: BackdropFilter absent when `useBackdropFilter: false`** — for any `GlassContainer` with `useBackdropFilter: false`, widget tree contains no `BackdropFilter`
    - **Property 3: Blur sigma clamped to [8.0, 20.0]** — for any `blur` value and `useBackdropFilter: true`, the applied sigmaX/sigmaY equals `blur.clamp(8.0, 20.0)`
    - Run 200 iterations with random `blur` values covering [0.0, 30.0] and boundary values
    - **Validates: Requirements 3.3, 3.5**

  - [ ]* 4.3 Write widget test for `GlassContainer` `RepaintBoundary` placement
    - Pump `GlassContainer(useBackdropFilter: true)` and assert `RepaintBoundary` is the ancestor immediately above `ClipRRect` and `BackdropFilter`
    - **Validates: Requirements 3.1, 3.4**

  - [ ] 4.4 Upgrade `MainShell` to implement `WidgetsBindingObserver` for animation lifecycle management
    - Mixin `WidgetsBindingObserver` into `_MainShellState`
    - In `initState()`: call `WidgetsBinding.instance.addObserver(this)` after existing setup
    - In `dispose()`: call `WidgetsBinding.instance.removeObserver(this)` before existing dispose logic
    - Override `didChangeAppLifecycleState`: call `_bgCtrl.stop()` on paused/inactive; call `_bgCtrl.repeat(reverse: true)` on resumed only if not locked (use `ref.read(authStateProvider)` — not `ref.watch` — to avoid a rebuild subscription)
    - _Requirements: 4.1, 4.2, 4.4, 4.5_

  - [ ] 4.5 Add idle animation cutoff to `LockScreen`
    - Track last user interaction timestamp; use a `Timer` that fires after 5 seconds of inactivity to call `_stopAnimation()`
    - Any PIN digit, backspace, or biometric button tap calls `_resetIdleTimer()` which cancels the previous timer and resumes animation
    - Idle visual state uses static widgets or `AnimatedContainer` driven by `_animating` flag only
    - _Requirements: 4.3_

  - [ ]* 4.6 Write unit test for `LockScreen` idle animation cutoff
    - Use `fake_async` to simulate 5-second idle; verify animation stops
    - Verify a tap resets the timer and animation resumes
    - _Requirements: 4.3_

- [ ] 5. Data layer performance — pagination, off-thread encryption, calendar pre-computation
  - [ ] 5.1 Implement cursor-based pagination in `StorageService` — `getJournalPage` method
    - Add `getJournalPage(int pageSize, [PaginationCursor? cursor])` returning `Future<PagedResult<JournalEntry>>`
    - Throw `ArgumentError` for `pageSize` outside `[1, 100]`
    - When `cursor == null`: return the most recent entries; when `cursor` provided: filter to records with `id < cursor._lastId`
    - Use ObjectBox query with date-descending order and `limit(pageSize + 1)` to detect additional pages
    - Return `nextCursor == null` when no further pages exist; return empty list and `null` cursor when all entries are exhausted
    - Retain existing `getJournal()` method unchanged — it is still used by `StatsNotifier` and `changePin` re-encryption
    - _Requirements: 6.1, 6.2, 6.3, 6.6_

  - [ ]* 5.2 Write property test for pagination round-trip invariant (Property 5)
    - **Property 5: Pagination round-trip invariant**
    - For any in-memory entry list and page sizes 1–100, verify concatenation of all pages equals `getJournal()` result in identical order
    - **Validates: Requirements 6.5**

  - [ ]* 5.3 Write unit tests for `getJournalPage` error cases
    - Assert `ArgumentError` for `pageSize = 0`, `pageSize = 101`, `pageSize = -1`
    - Assert first-page behavior with `cursor == null`
    - Assert empty list + `null` cursor when exactly `pageSize` entries remain and cursor is advanced
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ] 5.4 Implement infinite-scroll pagination in `JournalScreen`
    - Replace full-list load with initial call to `getJournalPage(pageSize: 20, cursor: null)` in `initState()`
    - Add `ScrollController` with a listener that triggers `_loadNextPage()` when within 5 items of list end
    - `_loadNextPage()` appends results to the displayed list and advances `_cursor`; sets `_hasMore = false` when `nextCursor == null`
    - On failure: retain current list, show non-blocking `SnackBar`, preserve last valid cursor for retry
    - _Requirements: 6.4, 6.7, 19.1_

  - [ ] 5.5 Move encryption/decryption off the main isolate in `StorageService` using `compute()`
    - Define top-level `_isolateEncrypt(_EncryptPayload p)` and `_isolateDecrypt(_DecryptPayload p)` functions (records, isolate-safe)
    - In `saveJournalEntry()`: wrap content encryption in `await compute(_isolateEncrypt, ...)`
    - In `getJournal()`: ensure batch decryption uses `compute(_batchDecryptEntries, ...)` (verify or add if missing)
    - In `saveDraft()`: the current call `EncryptionService().encrypt(draftData)` runs on the main thread — wrap it in `await compute(_isolateEncrypt, ...)` (Req 7.7)
    - When key is unavailable (`null`): return raw stored bytes without attempting decryption (Req 7.4)
    - If `compute()` fails: propagate as failed `Future`; do not return partial results
    - `EncryptionService` must not be called from any widget `build()` method
    - _Requirements: 7.1, 7.2, 7.4, 7.5, 7.6, 7.7_

  - [ ]* 5.6 Write property test for encryption round-trip (Property 6)
    - **Property 6: Encryption round-trip**
    - For any non-empty plaintext string and a random 32-byte AES key, `decrypt(encrypt(plaintext)) == plaintext` using AES-256-GCM
    - **Validates: Requirements 7.3**

  - [ ] 5.7 Implement calendar pre-computation in `CalendarScreen`
    - Add `Map<DateTime, List<JournalEntry>> _entriesByDate = {}` field
    - Implement `_buildDateMap(List<JournalEntry> entries)` using a single `fold()` call keyed by `DateTime(year, month, day)`
    - Call `_buildDateMap` immediately after `_loadData()` completes and after any entry mutation
    - Replace all per-render list scans with `_entriesByDate[key] ?? const []` O(1) lookup
    - _Requirements: 8.1, 8.2, 8.4, 19.2_

  - [ ]* 5.8 Write property test for calendar date map correctness (Property 7)
    - **Property 7: Calendar date map correctness**
    - For any list of `JournalEntry` objects, `_buildDateMap(entries)[d]` equals the sublist of all entries with date zeroed to midnight equal to `d`, and no entry is absent
    - **Validates: Requirements 8.3**

- [ ] 6. Checkpoint — data layer
  - Ensure `JournalScreen` infinite scroll works, `CalendarScreen` month navigation uses map lookup, and all encryption remains functional
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. State management — search debouncing, EntryEditor decomposition, spotlight and tag filter
  - [ ] 7.1 Implement search debouncing in `JournalScreen`
    - Add `Timer? _debounce` field; cancel and restart a 300 ms timer on every keystroke in the search field
    - On timer fire: apply case-insensitive partial-match filter against `headline` and `content` fields exactly once
    - When search field is cleared: cancel pending timer and restore the full unfiltered list within 50 ms
    - When field contains only whitespace: treat as empty and show full list
    - _Requirements: 9.1, 9.2, 9.3, 9.5_

  - [ ]* 7.2 Write property test for search debounce idempotence (Property 8)
    - **Property 8: Search debounce idempotence**
    - For any query `q` and entry collection `E`, the debounce-fired result equals a direct single-pass filter with `q` and `E`
    - **Validates: Requirements 9.4**

  - [ ] 7.3 Decompose `EntryEditor` into independently stateful sub-widgets (including SpotlightToggle)
    - Extract `MoodSelector` as a `StatefulWidget` with `selectedMood` state and `onChanged` callback
    - Extract `TagPicker` as a `StatefulWidget` with `tags` list state and `onChanged` callback
    - Extract `ImageSection` as a `StatefulWidget` with `images` list state and `onChanged` callback; compression is initiated inside `ImageSection`, not the parent (see Req 10.3 isolation rule)
    - Extract `SpotlightToggle` as a `StatelessWidget` receiving `isSpotlight` bool and `ValueChanged<bool> onChanged`; renders a filled `Icons.star_rounded` (amber) when true, outline star (slate) when false; parent stores `_isSpotlight` and toggles it via callback (Req 23.1)
    - Extract `_AutoSaveIndicator` as a `StatelessWidget` accepting `isSaving` and `hasChanges`
    - Parent `EntryEditor` passes values down via constructor and receives mutations via callbacks
    - Parent's `setState()` scope limited to `_isSaving`, `_hasChanges`, and type toggle
    - Preserve all existing functionality: auto-save drafts, gallery/URL/file image picking, type switching, mood selection, time bucket, save/cancel
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 23.1, 19.1_

  - [ ]* 7.4 Write widget tests for `EntryEditor` rebuild isolation
    - Change mood → verify only `MoodSelector` rebuilds; headline `TextField` is not rebuilt (use key-based build counter)
    - Add/remove image → verify only `ImageSection` rebuilds; mood and headline widgets are not rebuilt
    - Add/remove tag → verify only `TagPicker` rebuilds; mood, image, and headline widgets are not rebuilt
    - Toggle spotlight → verify only `SpotlightToggle` rebuilds; mood, image, tag, and headline widgets are not rebuilt
    - _Requirements: 10.2, 10.3, 10.6, 23.2_

  - [ ] 7.5 Isolate authentication state into a narrow `authStateProvider`
    - Create `final authStateProvider = StateProvider<bool>((ref) => false)` in the providers directory
    - Replace `bool isAuthenticated` + `setState()` in `RootOrchestrator` with a `Consumer` that watches `authStateProvider`
    - `LockScreen` calls `ref.read(authStateProvider.notifier).state = true` on successful unlock
    - `MainShell._isUnlocked` derives from `authStateProvider` (already referenced in Req 4.2 task)
    - `JournalScreen`, `CalendarScreen`, `IdentityScreen`, and `ProfileScreen` must NOT watch `authStateProvider`
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [ ]* 7.6 Write widget test for `authStateProvider` state isolation
    - Pump the full widget tree; toggle `authStateProvider`; assert `JournalScreen`, `CalendarScreen`, `IdentityScreen`, and `ProfileScreen` undergo zero rebuilds as a direct result
    - _Requirements: 11.2, 11.4_

  - [ ] 7.7 Add spotlight toggle and tag filter chips to `JournalScreen`
    - Add `bool _spotlightOnly = false` and `final Set<String> _selectedTags = {}` fields
    - Compute `_allTags` from the loaded entry list: `entries.expand((e) => e.tags).toSet()`
    - Add a horizontally scrollable filter-chip row below the search bar: one "Spotlight" chip (star icon, toggles `_spotlightOnly`) and one chip per tag in `_allTags` (toggles membership in `_selectedTags`)
    - Replace the current search-only filter with a composed `_filteredEntries` getter that applies search query, spotlight filter, and tag filter in sequence (all active filters use AND semantics)
    - Chips are only rendered when tags exist in the loaded data; the chip row is hidden if there are no tags and spotlight is not manually triggered
    - _Requirements: 23.3, 23.4, 23.5, 23.6_

  - [ ]* 7.8 Write unit tests for spotlight and tag filter behavior
    - Verify spotlight filter correctly hides non-spotlight entries (Req 23.3)
    - Verify tag filter with multiple selected tags uses AND semantics (Req 23.4)
    - Verify combined search + spotlight + tag filters are applied in sequence (Req 23.5)
    - _Requirements: 23.3, 23.4, 23.5_

- [ ] 8. Checkpoint — state management
  - Verify search debounce timing, `EntryEditor` sub-widget isolation, spotlight toggle, tag filter chips, and lock/unlock flow work end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Resource leak fixes
  - [ ] 9.0 Fix data-loss bug in `BackupService._serializeEntry` — backup image serialization (CRITICAL)
    - **Bug:** `_serializeEntry` currently passes `entry.images` directly to `jsonEncode` without calling `.toJson()` on each element. Since `ImageReference` is a Freezed class, `jsonEncode` calls its `.toString()` method, which outputs `{}` for each image — silently discarding all image data on every backup export
    - **Fix:** Change `'images': entry.images,` to `'images': entry.images.map((i) => i.toJson()).toList(),`
    - No change needed to `_deserializeEntry`; the `_parseBackupImages` method already handles the correct `Map` format
    - Add a targeted unit test: serialize one `JournalEntry` with a known `ImageReference`, call `json.decode` on the result, and assert the `'images'` key contains a non-empty `List<Map>` with the expected `source`, `type`, and other fields
    - This is a pre-release blocker — it must be done before task 9.6 (backup off-thread) to avoid entrenching the bug in a new code path
    - _Requirements: 20.1, 20.2, 20.3_

  - [ ] 9.1 Fix `TabController` listener leak in `IdentityScreen`
    - **Bug description (critical):** The current code adds the `TabController` listener **inside `build()`** via a `Builder` widget — NOT in `initState()`. Every widget rebuild calls `tabController.addListener(() { ... })` with a new anonymous closure. Because the listener is anonymous and its reference is never stored, it can never be removed. This means the controller accumulates unbounded listeners, and each rebuild causes all previously accumulated listeners to fire on every tab change.
    - **Fix:** Use `didChangeDependencies()` (not `initState()`) because `DefaultTabController.of(context)` requires a valid inherited-widget context. Extract the logic as follows:
      1. Add `TabController? _tabCtrl` and `VoidCallback? _tabListener` fields to `_IdentityScreenState`
      2. In `didChangeDependencies()`: read the controller via `DefaultTabController.of(context)`; if it differs from `_tabCtrl`, remove `_tabListener` from the old controller, construct a named `_tabListener = () { ... }` that guards with `mounted` and `!indexIsChanging` checks, add it to the new controller, and update `_tabCtrl`
      3. In `dispose()`: call `_tabCtrl?.removeListener(_tabListener!)` before `super.dispose()`
      4. Remove the entire `Builder` widget from `build()` — the tab selection sync now happens in `didChangeDependencies` and the listener
    - Guard against duplicate registration: the `if (newCtrl != _tabCtrl)` check in `didChangeDependencies` ensures the listener is added at most once per controller instance
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 19.5_

  - [ ]* 9.2 Write unit test for duplicate `TabController` listener registration
    - Rebuild `IdentityScreen` multiple times and verify the `TabController` has exactly one listener registered after N rebuilds
    - Verify the listener is removed from the controller after `dispose()`
    - _Requirements: 12.3, 12.4_

  - [ ] 9.3 Ensure `PageController` disposal in `CalendarScreen` and `MainShell`
    - Confirm (and add if absent) `_pageController.dispose()` in `CalendarScreen.dispose()` before `super.dispose()` — the current code already has this, but verify it is still present after task 5.7 refactoring
    - Confirm `_pageController` is initialized exactly once in `initState()` and never re-assigned in `build()`
    - Confirm (and add if absent) any `PageController` owned by `MainShell` is disposed in `MainShell.dispose()`
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [ ] 9.4 Implement orphaned image file cleanup in `StorageService.deleteJournalEntry`
    - After removing the DB record, iterate `entry.images`; skip non-`filePath` types and null/empty sources
    - For each `filePath` image: attempt `File(img.source).delete()`; attempt to delete the thumbnail at `StorageService.thumbnailPath(img.source)`
    - On individual file deletion failure: log the error and continue; do not abort the loop
    - Do not attempt deletion for `galleryAsset` or `webUrl` types
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [ ]* 9.5 Write unit tests for orphaned image cleanup
    - Verify `galleryAsset` and `webUrl` images are never passed to `File.delete()` (Req 14.5)
    - Verify a failed deletion does not abort deletion of subsequent images in the list (Req 14.3)
    - Verify null/empty `source` paths are skipped without error (Req 14.4)
    - _Requirements: 14.3, 14.4, 14.5_

  - [ ] 9.6 Move `BackupService` export and import off the main isolate with staged progress
    - Implement `backupProgressProvider = StateProvider<BackupStage?>((ref) => null)` in `lib/providers/providers.dart`
    - In `exportToFile()`: set progress to `serializing` → `compute(_serializeData, ...)` → set `encrypting` → `compute(_encryptData, ...)` → set `writing` → `compute(_writeFile, ...)` → set `null`
    - In `importFromJson()`: set progress to `reading` → `compute(_readFile, filePath)` → set `decrypting` → `compute(_decryptData, ...)` → set `restoring` → `compute(_deserializeAndRestore, ...)` → set `null`
    - **Critical:** Each of the three import/export stages must be a **separate** `compute()` call with a main-thread `backupProgressProvider` update between calls — combining stages into one isolate prevents the UI from seeing intermediate stage transitions
    - Return `BackupResult(success: false, error: ...)` on corrupted/truncated input instead of throwing
    - `ProfileScreen` watches `backupProgressProvider` and shows a stage-name overlay while non-null
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.6, 19.7_

  - [ ]* 9.7 Write unit tests for backup off-thread staged progress
    - Verify `exportToFile()` transitions through `serializing → encrypting → writing → null` in order (Req 15.3)
    - Verify `importFromJson()` transitions through `reading → decrypting → restoring → null` in order (Req 15.4)
    - Verify `importFromJson()` returns `BackupResult(success: false)` on corrupted JSON input (Req 15.6)
    - _Requirements: 15.3, 15.4, 15.6_

  - [ ]* 9.8 Write property test for backup round-trip invariant (Property 9)
    - **Property 9: Backup round-trip**
    - For any list of `JournalEntry` objects, serialize via `exportToFile()` then import via `importFromJson()`; assert the result list has the same count and identical field values (`id`, `type`, `date`, `headline`, `content`, `mood`, `feeling`, `tags`, `location`, `timeBucket`, `images`, `isSpotlight`) for every entry
    - Pay special attention to the `images` field — each `ImageReference` must round-trip correctly, confirming the fix from task 9.0 is in effect
    - **Validates: Requirements 15.5, 20.3**

  - [ ] 9.9 Add restore button to the Manage Backups sheet in `ProfileScreen`
    - In the Manage Backups `ListView.builder`, add a restore `IconButton` (emerald `Icons.restore`) alongside the existing delete button for each backup row
    - On tap: close the sheet, show a confirmation `AlertDialog` explaining the restore is a merge (existing entries are not deleted), wait for user confirmation
    - On confirm: call `backupService.importEncryptedFile(backup.path)` for encrypted backups or `backupService.importFromJson(content)` for plain backups
    - On success: call `ref.invalidate(statsNotifierProvider)` to refresh stats, show an emerald `SnackBar` with the result message
    - On failure: show a rose `SnackBar` with the error message
    - The restore button is placed to the left of the delete button; both buttons are visible without horizontal scrolling in the row
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5_

- [ ] 10. Checkpoint — resource leaks
  - Verify Identity/Calendar/Main controllers are cleaned up; verify backup progress overlay renders correctly; verify restore button triggers the correct confirmation and import flow; verify backup image serialization is fixed
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Security hardening — salt rotation, exponential backoff, parallel reads, and image compression
  - [ ] 11.1 Add `StorageService.getObjectBoxIdForEntry` and `putManyJournalEntries` for atomic batch updates
    - Implement `Future<int?> getObjectBoxIdForEntry(String entryId)` that queries ObjectBox for the entry with the given domain `entryId` string and returns its integer ObjectBox ID (or `null` if not found)
    - Implement `Future<void> putManyJournalEntries(List<JournalEntry> entries)` using a single ObjectBox `putMany()` transaction
    - Inside `putManyJournalEntries`: call `getObjectBoxIdForEntry(ob.entryId)` for each entry to preserve existing ObjectBox integer IDs, so entries are updated in-place rather than inserted as duplicates
    - `getObjectBoxIdForEntry` must be implemented before `putManyJournalEntries` can be implemented
    - _Requirements: 16_

  - [ ] 11.2 Implement salt rotation, crash-recovery flag, and atomic re-encryption in `SecurityService.changePin`
    - Follow the 12-step algorithm from the design:
      1. Write `_rekeyPendingKey = 'true'` to FlutterSecureStorage (crash-recovery flag)
      2. Verify old PIN → if fails, delete `_rekeyPendingKey`, return failure
      3. Snapshot old secrets via parallel reads (`Future.wait`)
      4. Load all entries via `storageService.getJournal()`
      5. Generate `newPinSalt`, `newEncSalt`
      6. Derive `newEncKey` off-thread via `compute(_pbkdf2Derive, ...)`
      7. Re-encrypt all entries off-thread via `compute(_reEncryptEntries, ...)`
      8. Write new salts and hash to SecureStorage via `Future.wait` **BEFORE** DB write
      9. Save re-encrypted entries via `storageService.putManyJournalEntries(reEncrypted)` **AFTER** SecureStorage
      10. Update `_cachedEncryptionKey = newEncKey`
      11. Delete `_rekeyPendingKey`
      12. Return success
    - On step 8 or 9 failure: restore old secrets from snapshot via `Future.wait`; delete `_rekeyPendingKey`; return `ChangePinResult(success: false)`
    - Implement `Future<bool> hasInterruptedRekey()` that reads `_rekeyPendingKey` and returns `true` if present
    - `RootOrchestrator` (or app startup) must call `hasInterruptedRekey()` and present a recovery screen if `true`
    - Change return type from `PinVerificationResult` to `ChangePinResult` at all call sites in `PinManagementScreen`
    - When `newPin == oldPin`: still generate and persist new salts and new hash (full re-key)
    - When `oldPin` verification fails: delete `_rekeyPendingKey` and return failure immediately
    - _Requirements: 16.1, 16.2, 16.3, 16.6, 16.7, 16.8, 16.9_

  - [ ]* 11.3 Write property tests for PIN change salt invariants (Properties 10 and 11)
    - **Property 10: New salt invariant after `changePin`** — after any successful `changePin(old, new)`, `_saltKey` value differs from pre-call value and is non-empty
    - **Property 11: PIN change round-trip and old-PIN rejection** — after successful `changePin(old, new)`, `verifyPin(new)` returns success and `verifyPin(old)` returns failure
    - **Validates: Requirements 16.3, 16.4, 16.5**

  - [ ]* 11.4 Write unit tests for `changePin` rollback, crash-recovery, and edge cases
    - Verify rollback restores `verifyPin(oldPin)` to success when a storage write fails mid-way (Req 16.6)
    - Verify `changePin(old, old)` (same PIN) generates new salts (Req 16.8)
    - Verify `changePin` with wrong `oldPin` does not modify any stored values and deletes `_rekeyPendingKey` (Req 16.7)
    - Verify `hasInterruptedRekey()` returns `true` when `_rekeyPendingKey` is present and `false` when absent (Req 16.9)
    - Verify `_rekeyPendingKey` is deleted on successful `changePin` completion (Req 16.9)
    - _Requirements: 16.6, 16.7, 16.8, 16.9_

  - [ ] 11.5 Implement exponential backoff with persisted `lockout_cycle_count` in `SecurityService`
    - Add `static const String lockoutCycleKey = 'lockout_cycle_count'` to `SecurityConstants` in `lib/config/constants.dart`
    - **Note:** The existing field is `SecurityConstants.maxAttempts` (not `maxPinAttempts`) — use `maxAttempts` throughout; do not create a duplicate field
    - In `_handleFailedAttempt`: when `remainingAttempts <= 0` (i.e., `SecurityConstants.maxAttempts` reached), read `SecurityConstants.lockoutCycleKey` (default `'0'`), increment, persist, compute duration as `min(3600, base × 2^(cycleCount - 1))`
    - In `_resetAttempts`: include `_storage.write(key: SecurityConstants.lockoutCycleKey, value: '0')` in the `Future.wait` alongside existing resets
    - Also reset `SecurityConstants.lockoutCycleKey` to `'0'` in `resetPinViaSecurityQuestions` and `resetPinViaBiometric` success paths
    - **Lockout timestamp storage format:** Keep the existing `millisecondsSinceEpoch.toString()` format — do NOT change to ISO8601, to preserve backward compatibility with existing stored lockout state
    - `LockScreen` displays countdown, decrementing by 1 each second until 0 (Req 17.6)
    - _Requirements: 17.1, 17.2, 17.3, 17.5, 17.7, 17.8_

  - [ ]* 11.6 Write property test for lockout duration formula correctness and monotonicity (Property 12)
    - **Property 12: Lockout duration formula correctness and monotonicity**
    - For any `n >= 1`, `lockoutDuration(n) == min(3600, base × 2^(n-1))`; for all `n >= 1`, `lockoutDuration(n+1) >= lockoutDuration(n)`
    - Verify cap at 3600 seconds regardless of cycle count
    - **Validates: Requirements 17.2, 17.3, 17.4**

  - [ ]* 11.7 Write unit tests for exponential backoff edge cases
    - Verify `lockout_cycle_count` resets to 0 on successful PIN verification (Req 17.5)
    - Verify `lockout_cycle_count` resets to 0 on biometric/security-question PIN reset (Req 17.7)
    - Verify lockout expiry resets the per-cycle attempt counter but not `lockout_cycle_count` (Req 17.8)
    - _Requirements: 17.5, 17.7, 17.8_

  - [ ] 11.8 Parallelize `FlutterSecureStorage` reads in `SecurityService.verifyPin` and `initialize`
    - In `verifyPin`: replace four sequential `await _storage.read(...)` calls with one `await Future.wait([read pinHash, read salt, read attemptCount, read lockoutUntil])`
    - In `initialize`: replace two sequential reads of `_saltKey` and `_encryptionSaltKey` with `await Future.wait([read salt, read encSalt])`; generate and persist both if absent — the current code only initializes `_saltKey` and leaves `_encryptionSaltKey` uninitialized here
    - If any read in a `Future.wait` call throws, propagate failure as a failed `Future`; do not return partial or default result
    - _Requirements: 18.1, 18.2, 18.4_

  - [ ]* 11.9 Write property test for parallel reads equivalence (Property 13)
    - **Property 13: Parallel reads produce equivalent results**
    - For any combination of stored values, `verifyPin(pin)` using `Future.wait` returns identical `PinVerificationResult` to the sequential implementation given the same inputs
    - **Validates: Requirements 18.1, 18.3**

  - [ ]* 11.10 Write unit test for `Future.wait` failure propagation in `verifyPin`
    - Simulate one storage read throwing; verify `verifyPin` fails the future rather than returning a partial result
    - _Requirements: 18.4_

- [ ] 12. Image compression and thumbnail generation
  - [ ] 12.1 Add image compression in `ImageSection` sub-widget before constructing `ImageReference`
    - Import `flutter_image_compress` inside `ImageSection` (not in the parent `EntryEditor`, to preserve rebuild isolation)
    - For `filePath`-type images picked from camera or gallery, call `FlutterImageCompress.compressAndGetFile(originalPath, outputPath, quality: 80, minWidth: 1920, minHeight: 1920, keepExif: false)` before creating `ImageReference`
    - Fall back to original file if compression returns `null`
    - Only applies to `filePath` source type; `galleryAsset` and `webUrl` are not compressed
    - _Requirements: 5.3_

  - [ ]* 12.2 Write property test for image compression never increasing file size (Property 4)
    - **Property 4: Image compression never increases file size**
    - For any valid JPEG/PNG byte array `b`, `compress(b).length <= b.length` after applying `FlutterImageCompress` at quality 80 with max long-edge 1920
    - Use a set of real and synthetically generated JPEG/PNG test images
    - **Validates: Requirements 5.5**

  - [ ] 12.3 Add thumbnail generation in `StorageService.saveJournalEntry`
    - Import `package:image/image.dart as img` and `package:path/path.dart as p`
    - After saving the entry to ObjectBox, call `_generateThumbnail(filePath)` for each new `filePath` image without awaiting its completion (fire-and-forget, errors are caught and logged)
    - `_generateThumbnail` wraps the CPU-bound decode+resize work in `compute(_isolateGenerateThumbnail, payload)` to avoid blocking the UI thread; the top-level `_isolateGenerateThumbnail` function reads the file, decodes with `img.decodeImage`, resizes to max long-edge 300 px, and writes `img.encodeJpg(quality: 75)` to the thumbnail path
    - Use `StorageService.thumbnailPath(originalPath)` backed by `p.join(p.dirname(originalPath), '${p.basenameWithoutExtension(originalPath)}_thumb.jpg')` — do NOT use `.replaceAll('.jpg', '')`, which fails for non-`.jpg` extensions
    - If thumbnail generation fails: log error, do not rethrow, entry is saved regardless
    - Expose `static String thumbnailPath(String originalPath)` on `StorageService` for use by widget code and cleanup in `deleteJournalEntry`
    - _Requirements: 5.4_

  - [ ] 12.4 Update `ImageThumbnailWidget` to use thumbnails and apply `cacheWidth`/`cacheHeight` constraints
    - For `filePath` images in list-view cards: check `File(StorageService.thumbnailPath(img.source)).existsSync()` and load thumbnail via `Image.file` if present; fall back to full-resolution image if no thumbnail exists
    - Pass `cacheWidth: 400, cacheHeight: 400` to every `Image.file` call (for file-path images) and `Image.memory` call (for gallery asset thumbnails)
    - _Requirements: 5.1, 5.2, 5.6_

  - [ ]* 12.5 Write unit tests for `ImageThumbnailWidget` fallback behavior
    - Verify thumbnail is loaded when `_thumb.jpg` exists at expected path
    - Verify fallback to full-resolution image with cacheWidth/cacheHeight constraints when no thumbnail exists
    - _Requirements: 5.6_

- [ ] 13. Final checkpoint — full integration
  - Verify the complete flow: PIN setup → create entries with images and spotlight marks → calendar view → journal scroll pagination → tag/spotlight filter → backup export → confirm backup image data is intact → backup restore (merge) → verify entries remain intact → change PIN → verify all entries remain readable under new PIN
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after each major category
- Property tests validate universal correctness properties (13 properties from design + Property 9 backup round-trip)
- Unit and widget tests validate specific examples and edge cases
- The design uses Dart/Flutter throughout; all code examples use Dart idioms
- **Task 9.0 is a pre-release blocker** — it must be done before task 9.6 to avoid entrenching the backup image serialization bug in the new off-thread code path
- Task 1.5 (create `lib/providers/`) must be completed before tasks 2.1 and 7.5 can write their provider files
- `getObjectBoxIdForEntry` (task 11.1) must be implemented before `putManyJournalEntries` (also task 11.1)
- `putManyJournalEntries` (task 11.1) must be completed before `changePin` re-encryption (task 11.2)
- Image compression (task 12.1) and thumbnail generation (task 12.3) are independent and can proceed in parallel
- `SecurityConstants.maxAttempts` is the existing field name — do NOT create `maxPinAttempts`
- Thumbnail path helper uses `package:path` — do NOT use `.replaceAll('.jpg', '')` (fails for non-.jpg files)
- After creating any Riverpod code-gen provider file, run `flutter pub run build_runner build --delete-conflicting-outputs`
- Task 9.1 uses `didChangeDependencies` (not `initState`) because `DefaultTabController.of(context)` requires inherited-widget context; using `initState` would throw because the inherited widget is not yet accessible at that lifecycle stage
- Image compression in task 12.1 belongs inside `ImageSection` (not the parent `EntryEditor`) to preserve rebuild isolation per Req 10.3

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5"] },
    { "id": 1, "tasks": ["2.1", "5.1", "7.5", "9.0", "9.1", "9.3"] },
    { "id": 2, "tasks": ["2.2", "2.3", "4.1", "5.2", "5.3", "5.5", "5.7", "7.1", "7.3", "9.4", "9.6", "11.1"] },
    { "id": 3, "tasks": ["2.4", "2.5", "4.2", "4.3", "4.4", "5.4", "5.6", "5.8", "7.2", "7.4", "7.6", "7.7", "9.2", "9.5", "9.7", "9.8", "9.9", "11.2", "12.1", "12.3"] },
    { "id": 4, "tasks": ["4.5", "4.6", "7.8", "11.3", "11.4", "11.5", "11.8", "12.4"] },
    { "id": 5, "tasks": ["11.6", "11.7", "11.9", "11.10", "12.2", "12.5"] }
  ]
}
```
