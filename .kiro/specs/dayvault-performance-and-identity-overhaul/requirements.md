# Requirements Document

## Introduction

DayVault is a Flutter-based quantified self journaling app. A thorough architectural analysis has identified six categories of critical issues that degrade user experience, waste resources, and introduce security risks. This feature overhaul addresses all of them:

1. **Identity/Profile screen** shows irrelevant device diagnostics instead of journaling insights.
2. **Rendering and GPU overhead** from unguarded `BackdropFilter` glassmorphism and a continuous idle animation.
3. **Data layer performance** — all entries loaded at once, crypto on the UI thread, O(n²) calendar filtering.
4. **State management** — monolithic rebuilds on every keystroke or field change.
5. **Memory and resource leaks** — unremoved listeners, orphaned image files, synchronous backup.
6. **Security hardening** — salt reuse on PIN change, no exponential backoff on failed attempts.

Additionally, four **functional gaps** discovered during code review are addressed here as blocking issues for a stable release:

7. **Backup image serialization bug** — `BackupService._serializeEntry` passes `List<ImageReference>` objects directly into `jsonEncode` without calling `.toJson()`, silently producing `{}` for every image. This is a data-loss defect.
8. **Username profile management** — `UserSettings.username` exists in the data model but has no edit UI; the profile header shows the device name instead.
9. **Backup restore UI** — `BackupService.importEncryptedFile` exists but is not reachable from the UI; the "Manage Backups" sheet has no restore button.
10. **Spotlight and tag filter** — `JournalEntry.isSpotlight` and `tags` are persisted but never surfaced as entry-editor controls or journal-screen filters, making them dead fields.

All existing features (journaling, rankings, security, backup/restore) must continue to function correctly after every change.

---

## Glossary

- **Profile_Screen**: The "System" tab screen (`profile_screen.dart`) currently displaying device diagnostics; will be refactored to show journaling stats.
- **Identity_Screen**: The "Identity" tab screen (`identity_screen.dart`) displaying preference rankings.
- **Journal_Screen**: The "Journal" tab (`journal_screen.dart`) showing the entry timeline.
- **Calendar_Screen**: The "Recall" tab (`calendar_screen.dart`) showing the month calendar.
- **Entry_Editor**: The entry creation/editing bottom sheet (`entry_editor.dart`).
- **Storage_Service**: The data access layer (`storage_service.dart`) wrapping ObjectBox.
- **Security_Service**: The PIN, PBKDF2, and lockout service (`security_service.dart`).
- **Encryption_Service**: The AES-256-GCM field-level encryption service (`encryption_service.dart`).
- **Backup_Service**: The export/import service (`backup_service.dart`).
- **Glass_Container**: The shared glassmorphism widget (`glass_widgets.dart` — `GlassContainer`).
- **Image_Thumbnail_Widget**: The shared image rendering widget (`image_widgets.dart`).
- **Main_Shell**: The root authenticated navigation widget (`main.dart` — `MainShell`).
- **Lock_Screen**: The PIN entry / biometric authentication screen (`lock_screen.dart`).
- **Root_Orchestrator**: The widget that switches between Lock_Screen and Main_Shell.
- **JournalEntry**: The immutable data model for a single journal entry (type, mood, content, images, tags).
- **Mood**: The enum with 13 values (euphoric → creative) attached to each JournalEntry.
- **Journaling_Streak**: The number of consecutive calendar days on which at least one entry exists, ending today or yesterday.
- **Stats_Provider**: A new Riverpod provider (to be created) that computes and caches journaling statistics from StorageService.
- **Pagination_Cursor**: An opaque value encoding the last-seen ObjectBox record ID, used to fetch the next page of entries.
- **Thumbnail_Cache**: The in-memory and disk cache maintained by `cached_network_image` and Flutter's `ImageCache`.
- **Isolate**: A Dart isolate (background thread) used via `compute()` for CPU-intensive work.
- **Exponential_Backoff**: A lockout strategy where each successive lockout doubles the wait duration.
- **RepaintBoundary**: A Flutter widget that prevents its subtree from being repainted when the parent repaints.
- **Salt**: A random byte sequence stored in FlutterSecureStorage, used as input to PBKDF2 key derivation.

---

## Requirements

---

### Requirement 1: Journaling Statistics on the Profile Screen

**User Story:** As a journaling user, I want the "System" (Profile) screen to show meaningful journaling insights, so that I can understand my habits and progress at a glance.

#### Acceptance Criteria

1. WHEN Profile_Screen loads, THE Profile_Screen SHALL display the following journaling statistics derived exclusively from the JournalEntry collection in Storage_Service:
   - Current Journaling_Streak (consecutive days ending today or yesterday)
   - Total entry count
   - Average Mood score across all entries as a decimal rounded to one decimal place (numeric 0.0–12.0 mapping to the Mood enum index)
   - Total word count across all entry content fields, where a word is defined as a whitespace-delimited token of one or more non-whitespace characters
   - Journal age in days (days elapsed since the date of the oldest entry, inclusive)
   - Top 3 tags by frequency; in the case of a tie, tags are ordered alphabetically; if fewer than 3 tags exist, only available tags are shown

2. WHEN the Profile_Screen is navigated to, THE Stats_Provider SHALL compute all statistics from the full entry collection and cache the result in the global Riverpod provider until `statsNotifierProvider` is explicitly invalidated by an entry mutation (add, edit, or delete).

3. WHEN no entries exist, THE Profile_Screen SHALL display each stat card with a defined zero or empty-state label: streak as "0 days", entry count as "0 entries", average mood as "—", word count as "0 words", journal age as "0 days", and top tags as "No tags yet".

4. THE Profile_Screen SHALL NOT display device diagnostics including battery level, RAM usage, device model, OS version, or any metric sourced from the `device_info_plus`, `battery_plus`, or `system_info2` packages.

5. THE Profile_Screen SHALL NOT contain any `Timer.periodic` or recurring background timer for polling system metrics.

6. WHEN the entry collection changes (an entry is added, edited, or deleted), THE Stats_Provider SHALL invalidate its cached statistics so that the next navigation to Profile_Screen recomputes them.

7. IF Stats_Provider fails to compute statistics (e.g., storage read error), THE Profile_Screen SHALL display each stat card in the empty-state defined in criterion 3 and SHALL show a non-blocking error message indicating stats are temporarily unavailable.

---

### Requirement 2: Remove Irrelevant Dependencies

**User Story:** As a maintainer, I want the pubspec.yaml to contain only packages that are actually used by the app, so that build times and APK/IPA size are minimized.

#### Acceptance Criteria

1. THE app SHALL NOT declare `device_info_plus`, `battery_plus`, or `system_info2` as dependencies in `pubspec.yaml`.

2. WHEN the packages in Requirement 2.1 are removed, THE app SHALL compile without errors on Android, iOS, and Windows.

3. WHEN Profile_Screen loads, THE Profile_Screen header card SHALL display the user's configurable `username` from `UserSettings`; if `username` is null or empty, THE header SHALL display the placeholder text "Journaler".

---

### Requirement 3: Rendering Performance — BackdropFilter Isolation

**User Story:** As a user on a mid-range device, I want the UI to remain smooth at 60 fps, so that scrolling and screen transitions do not stutter or drop frames.

#### Acceptance Criteria

1. WHEN Glass_Container renders with `useBackdropFilter: true`, THE Glass_Container SHALL wrap the `BackdropFilter` widget inside a `RepaintBoundary` widget, so that rasterization of the blurred layer does not trigger repaints of surrounding UI.

2. THE Glass_Container SHALL default `useBackdropFilter` to `false`, preserving the existing behavior for all existing call sites that do not pass the parameter.

3. WHERE `useBackdropFilter` is set to `false`, THE Glass_Container SHALL NOT instantiate a `BackdropFilter` widget.

4. WHEN a screen containing Glass_Container with `useBackdropFilter: true` is rendered, THE resulting widget tree SHALL contain exactly one `RepaintBoundary` ancestor between the `BackdropFilter` and the nearest ancestor widget that is an instance of `Scaffold`, `Material`, `ColoredBox`, or `DecoratedBox` with a fully opaque fill color (alpha value of 255).

5. WHEN Glass_Container renders with `useBackdropFilter: true`, THE `BackdropFilter` SHALL apply a blur with a sigma value in the range [8.0, 20.0]; if a caller supplies a sigma value outside this range, THE Glass_Container SHALL clamp it to the nearest boundary of [8.0, 20.0].

---

### Requirement 4: Rendering Performance — Animation Controller Lifecycle

**User Story:** As a user leaving the app in the background, I want background animations to pause so that the battery is not drained by unnecessary GPU work.

#### Acceptance Criteria

1. WHEN the app lifecycle transitions to `AppLifecycleState.paused` or `AppLifecycleState.inactive`, THE Main_Shell SHALL call `_bgCtrl.stop()` on the background orb `AnimationController`.

2. WHEN the app lifecycle transitions to `AppLifecycleState.resumed` and the Lock_Screen is not visible, THE Main_Shell SHALL call `_bgCtrl.repeat(reverse: true)` to resume the background animation.

3. WHILE the Lock_Screen is visible and the user has not tapped any PIN digit, backspace, or biometric button within the last 5 seconds, THE Lock_Screen SHALL NOT run any `AnimationController` at 60 fps; any idle visual state SHALL be achieved with static widgets or `AnimatedContainer` driven by state changes only.

4. THE Main_Shell SHALL continue to dispose of `_bgCtrl` in its `dispose()` method as it currently does.

5. THE Main_Shell SHALL register itself as a `WidgetsBindingObserver` in `initState()` and deregister in `dispose()` so that app lifecycle callbacks in criteria 1 and 2 are received.

---

### Requirement 5: Rendering Performance — Image Memory Management

**User Story:** As a user with a large photo journal, I want images to load quickly and not exhaust device memory, so that the app does not crash or slow down when browsing many entries.

#### Acceptance Criteria

1. WHEN Image_Thumbnail_Widget renders a gallery asset thumbnail, THE Image_Thumbnail_Widget SHALL pass a `cacheWidth` value no greater than 400 logical pixels and a `cacheHeight` value no greater than 400 logical pixels to `Image.memory`, so that the Flutter image cache stores a downsampled copy.

2. WHEN Image_Thumbnail_Widget renders a file-path image, THE Image_Thumbnail_Widget SHALL pass a `cacheWidth` value no greater than 400 logical pixels and a `cacheHeight` value no greater than 400 logical pixels to `Image.file`.

3. WHEN a new camera or gallery image is attached to an entry in Entry_Editor and the image source type is `filePath`, THE Entry_Editor SHALL compress the image to a maximum JPEG quality of 80 and a maximum long-edge dimension of 1920 pixels before constructing the `ImageReference`.

4. WHEN an entry with `filePath`-type images is saved and a thumbnail version does not yet exist, THE Storage_Service SHALL generate and persist a thumbnail copy at a maximum long-edge dimension of 300 pixels for use in list-view cards. IF thumbnail generation fails, THE Storage_Service SHALL log the error and proceed with saving the entry without a thumbnail.

5. FOR ALL valid image byte arrays `b`, `compress(b).size <= b.size` SHALL hold after compression (metamorphic property: compression never increases file size).

6. WHEN Image_Thumbnail_Widget is used inside a list-view card (Journal_Screen, Calendar_Screen), THE Image_Thumbnail_Widget SHALL load the thumbnail copy if it exists; IF no thumbnail exists for an entry (e.g., a legacy entry created before this requirement was implemented), THE Image_Thumbnail_Widget SHALL fall back to loading the full-resolution image with the cacheWidth/cacheHeight constraints from criteria 1 and 2.

---

### Requirement 6: Data Layer Performance — Paginated Entry Loading

**User Story:** As a power user with thousands of journal entries, I want the Journal screen to load quickly without exhausting device memory, so that the app remains responsive regardless of history size.

#### Acceptance Criteria

1. THE Storage_Service SHALL expose a `getJournalPage(int pageSize, Pagination_Cursor? cursor)` method that returns at most `pageSize` entries ordered by date descending, along with a new `Pagination_Cursor` for the next page. The `pageSize` parameter SHALL be in the range [1, 100]; values outside this range SHALL cause `getJournalPage` to throw an `ArgumentError`.

2. WHEN `cursor` is `null`, THE Storage_Service SHALL return the first page (most recent entries).

3. WHEN fewer than `pageSize` entries remain, THE Storage_Service SHALL return all remaining entries and a `null` cursor indicating no further pages exist. WHEN exactly `pageSize` entries remain and a subsequent call is made with the resulting cursor, THE Storage_Service SHALL return an empty list and a `null` cursor.

4. WHEN the user has scrolled to within 5 items of the end of the currently loaded list in Journal_Screen, THE Journal_Screen SHALL call `getJournalPage` with the current cursor to load the next page and append it to the displayed list.

5. FOR ALL valid entry collections `E` and page sizes `p` in [1, 100], concatenating all pages returned by sequential calls to `getJournalPage(p, cursor)` SHALL yield the same ordered set as calling `getJournal()` directly (pagination round-trip invariant).

6. THE existing `getJournal()` method SHALL be retained and SHALL return the complete entry list, for use by Backup_Service, Stats_Provider, and Calendar_Screen.

7. IF `getJournalPage` fails (e.g., storage read error), THE Journal_Screen SHALL retain the currently displayed list, show a non-blocking error indicator, and preserve the last valid cursor so that the user can retry.

---

### Requirement 7: Data Layer Performance — Off-Thread Encryption

**User Story:** As a user with an encrypted journal, I want to open and scroll through entries without the screen freezing, so that encryption operations do not block the UI.

#### Acceptance Criteria

1. WHEN Storage_Service decrypts one or more journal entries, THE Storage_Service SHALL perform AES-256-GCM decryption off the main isolate, so that the main isolate is not blocked during the operation.

2. WHEN Storage_Service encrypts a journal entry before saving it, THE Storage_Service SHALL perform AES-256-GCM encryption off the main isolate, so that the main isolate is not blocked during the operation.

3. WHEN a journal entry's content is encrypted and then decrypted using the same key, THE decrypted content SHALL equal the original plaintext content (encryption round-trip property).

4. IF the encryption key is not available (PIN not verified), THE Storage_Service SHALL return the raw stored bytes for each entry field without modification, leaving any ciphertext fields unchanged and not attempting decryption.

5. THE Encryption_Service SHALL NOT be called directly from any widget `build()` method.

6. IF the off-isolate encryption or decryption operation fails (e.g., isolate spawn error, key unavailable mid-operation), THE Storage_Service SHALL propagate the failure as a failed `Future` and SHALL NOT return a partially decrypted or partially encrypted entry.

7. WHEN `StorageService.saveDraft()` encrypts a draft, THE encryption SHALL NOT be called synchronously on the main thread; it SHALL use a top-level `compute()` call or an equivalent off-thread mechanism.

---

### Requirement 8: Data Layer Performance — Calendar Pre-computation

**User Story:** As a user viewing the calendar, I want month navigation to be instant, so that switching months does not cause visible lag.

#### Acceptance Criteria

1. WHEN Calendar_Screen loads its entry data, THE Calendar_Screen SHALL build a `Map<DateTime, List<JournalEntry>>` (keyed by date with time zeroed to midnight) from the loaded entries exactly once per data load, before rendering the calendar grid.

2. WHEN Calendar_Screen navigates between months, THE Calendar_Screen SHALL look up entries for a day exclusively from the pre-computed map and SHALL NOT iterate over the full entry list; the lookup SHALL complete within one frame (≤ 16 ms) on the target device.

3. THE pre-computed map SHALL satisfy: for every date `d` present in the loaded entry collection, `map[d]` equals the list of all entries whose date, when zeroed to midnight, equals `d` (map correctness invariant).

4. WHEN an entry is added, edited, or deleted, THE Calendar_Screen SHALL rebuild the pre-computed map with the updated entry collection before the next calendar frame renders.

---

### Requirement 9: State Management — Search Debouncing

**User Story:** As a user typing a search query, I want the results to update smoothly without lag, so that the app does not stutter on every keystroke.

#### Acceptance Criteria

1. WHEN the user types in the Journal_Screen search field, THE Journal_Screen SHALL delay applying the search filter until 300 milliseconds have elapsed since the last keystroke (debounce).

2. WHEN the debounce timer fires, THE Journal_Screen SHALL apply a case-insensitive partial-match filter against each entry's headline and content fields exactly once and update the displayed list.

3. WHEN the search field is cleared, THE Journal_Screen SHALL cancel any pending debounce timer and display the full unfiltered list within 50 milliseconds of the field being cleared.

4. WHEN the debounce timer fires with a final query `q`, THE displayed results SHALL equal the results that would be produced by applying the same case-insensitive partial-match filter with `q` in a single direct pass over the full entry list (debounce idempotence property).

5. WHEN the search field contains only whitespace, THE Journal_Screen SHALL treat the query as empty and display the full unfiltered list.

---

### Requirement 10: State Management — Entry Editor Sub-Widget Decomposition

**User Story:** As a user editing an entry, I want mood, tag, and image changes to feel instant without the entire editor re-rendering, so that the editor remains responsive on lower-end devices.

#### Acceptance Criteria

1. THE Entry_Editor SHALL decompose into at least three independently stateful sub-widgets: `MoodSelector`, `TagPicker`, and `ImageSection`.

2. WHEN the user changes the mood selection, ONLY the `MoodSelector` sub-widget SHALL rebuild; the headline and content text fields SHALL NOT rebuild.

3. WHEN the user adds or removes an image, ONLY the `ImageSection` sub-widget SHALL rebuild; the headline, content, and mood widgets SHALL NOT rebuild.

4. WHEN the user types in the headline or content fields, the auto-save timer SHALL fire after 500 milliseconds of inactivity as currently implemented; only the auto-save indicator widget SHALL rebuild as a result of the timer firing, and the `MoodSelector`, `TagPicker`, and `ImageSection` sub-widgets SHALL NOT rebuild.

5. THE Entry_Editor SHALL preserve all existing functionality: auto-save drafts, gallery/URL/file image picking, type switching (Story/Event), mood selection, time bucket, and save/cancel.

6. WHEN the user adds or removes a tag in the `TagPicker`, ONLY the `TagPicker` sub-widget SHALL rebuild; the headline, content, mood, and image widgets SHALL NOT rebuild.

---

### Requirement 11: State Management — Security State Isolation

**User Story:** As a user unlocking the app, I want only the lock overlay to update when authentication state changes, so that the rest of the app does not re-render unnecessarily.

#### Acceptance Criteria

1. WHEN the user successfully authenticates (PIN or biometric), THE Root_Orchestrator SHALL update authentication state through a narrowly scoped Riverpod `StateProvider` or equivalent such that only the Lock_Screen widget rebuilds, not the app root widget.

2. WHEN authentication state changes to either authenticated or unauthenticated, THE `JournalScreen`, `CalendarScreen`, `IdentityScreen`, and `Profile_Screen` widgets SHALL undergo zero rebuilds as a direct result of the state change.

3. WHEN authentication succeeds, THE lock overlay SHALL be removed from the widget tree and Main_Shell SHALL become the visible content widget.

4. WHEN authentication fails, THE `JournalScreen`, `CalendarScreen`, `IdentityScreen`, and `Profile_Screen` widgets SHALL undergo zero rebuilds as a result of the failed authentication event.

---

### Requirement 12: Resource Leak — TabController Listener Cleanup

**User Story:** As a developer, I want all registered listeners to be removed in `dispose()`, so that no memory leaks accumulate during normal navigation.

#### Acceptance Criteria

> **Root cause (code review finding):** The current `IdentityScreen` adds the `TabController` listener *inside the `build()` method* via a `Builder` widget — not in `initState()`. This means a new, anonymous listener is added on **every widget rebuild**, and no listener is ever removed. Over the lifetime of the screen, this accumulates unbounded anonymous listeners on the same controller. The fix requires restructuring to extract and store the listener reference in a named field.

1. WHEN Identity_Screen disposes, THE Identity_Screen SHALL remove the `TabController` listener that was added in `initState()`.

2. THE listener removal SHALL occur in the `dispose()` method before calling `super.dispose()`.

3. THE `TabController` listener SHALL be added exactly once in `initState()` (not inside `build()` or any `Builder` callback), stored as a named `VoidCallback` field, and removed by reference in `dispose()`.

4. WHEN Identity_Screen is rebuilt (e.g., widget updated), THE Identity_Screen SHALL NOT register duplicate listeners on the same `TabController` — guaranteed by moving listener registration out of `build()`.

---

### Requirement 13: Resource Leak — PageController Disposal

**User Story:** As a developer, I want all controllers to be disposed when their owning widget is removed from the tree, so that no memory leaks accumulate.

#### Acceptance Criteria

1. WHEN Calendar_Screen's `dispose()` is called, THE Calendar_Screen SHALL call `_pageController.dispose()` before calling `super.dispose()`. *(Already compliant in current code — must be preserved.)*

2. THE `_pageController` in Calendar_Screen SHALL be initialized exactly once in `initState()`.

3. THE `_pageController` in Calendar_Screen SHALL NOT be re-assigned or re-created inside the `build()` method or any method called from `build()`.

4. WHEN MainShell's `dispose()` is called, THE MainShell SHALL call `dispose()` on any `PageController` it owns before calling `super.dispose()`.

5. WHEN any `StatefulWidget` in the app creates a `PageController` in `initState()`, THE owning widget SHALL call `dispose()` on that controller in its own `dispose()` method before calling `super.dispose()`.

---

### Requirement 14: Resource Leak — Orphaned Image File Cleanup

**User Story:** As a user who deletes journal entries, I want disk space to be reclaimed automatically, so that deleted entries do not leave behind untracked image files.

#### Acceptance Criteria

1. WHEN Storage_Service deletes a JournalEntry, THE Storage_Service SHALL first remove the database record and then attempt to delete each associated file-path image from the device filesystem.

2. WHEN a `filePath`-type image is successfully deleted from the filesystem, THE file SHALL no longer be present at that path on the device.

3. IF a file deletion fails (e.g., file already missing, permission error), THE Storage_Service SHALL log the error and continue attempting to delete remaining files in the entry's image list rather than aborting.

4. WHEN an `ImageReference` has a null or empty `source` path, THE Storage_Service SHALL skip that reference without error.

5. THE Storage_Service SHALL NOT attempt to delete files referenced by `ImageSourceType.galleryAsset` or `ImageSourceType.webUrl`, as these are managed externally.

---

### Requirement 15: Resource Leak — Backup/Restore Off-Thread Execution

**User Story:** As a user restoring a large backup, I want the app to remain interactive during the restore, so that the UI does not freeze or show an ANR dialog.

#### Acceptance Criteria

1. WHEN Backup_Service.exportToFile() is called, THE main isolate SHALL NOT be blocked; the UI SHALL remain responsive (no frame drops ≥ 16 ms attributable to the backup operation), and the method SHALL return a `Future` that completes on the main isolate when the export finishes.

2. WHEN Backup_Service.importFromJson() is called, THE main isolate SHALL NOT be blocked; the UI SHALL remain responsive (no frame drops ≥ 16 ms attributable to the import operation), and the method SHALL return a `Future` that completes on the main isolate when the import finishes.

3. WHILE a backup export is in progress, THE Profile_Screen SHALL display a progress indicator showing the current stage, which SHALL transition through exactly these stages in order: "Serializing…", "Encrypting…", "Writing…".

4. WHILE a backup import is in progress, THE Profile_Screen SHALL display a progress indicator showing the current stage, which SHALL transition through exactly these stages in order: "Reading…", "Decrypting…", "Restoring…".

5. WHEN a valid backup file produced by `exportToFile()` is passed to `importFromJson()`, THE resulting JournalEntry collection SHALL have the same count and the same field values (`id`, `type`, `date`, `headline`, `content`, `mood`, `feeling`, `tags`, `location`, `timeBucket`, `images`, `isSpotlight`) for every entry as the original collection (backup round-trip property).

6. IF the backup file passed to `importFromJson()` is corrupted, truncated, or otherwise invalid, THE Backup_Service SHALL return a `BackupResult` with `success: false` and an error message indicating the nature of the failure, rather than throwing an unhandled exception.

---

### Requirement 16: Security — New Salt on PIN Change

**User Story:** As a security-conscious user, I want changing my PIN to generate fresh cryptographic material, so that compromise of the old PIN does not compromise data encrypted under the new PIN.

#### Acceptance Criteria

1. WHEN `Security_Service.changePin(oldPin, newPin)` is called and `oldPin` is verified successfully, THE Security_Service SHALL generate a new random Salt using `_generateSalt()` and write it to `_saltKey` in FlutterSecureStorage before hashing `newPin`.

2. WHEN `Security_Service.changePin(oldPin, newPin)` is called and `oldPin` is verified successfully, THE Security_Service SHALL generate a new random encryption Salt and write it to `_encryptionSaltKey` in FlutterSecureStorage, then re-derive and store the encryption key in the in-memory cache from `newPin` and the new encryption Salt.

3. WHEN `changePin(oldPin, newPin)` completes successfully, THE value stored at `_saltKey` SHALL differ from the value that was stored at `_saltKey` before the call, and SHALL be non-empty (new salt invariant).

4. WHEN `changePin(oldPin, newPin)` completes successfully, a subsequent call to `verifyPin(newPin)` SHALL return `PinVerificationResult(success: true)`.

5. WHEN `changePin(oldPin, newPin)` completes successfully, a subsequent call to `verifyPin(oldPin)` SHALL return `PinVerificationResult(success: false)`.

6. IF `changePin` fails at any step after the old PIN is verified but before the new hash, new `_saltKey`, and new `_encryptionSaltKey` are all written, THE Security_Service SHALL leave the stored PIN hash, `_saltKey`, and `_encryptionSaltKey` in a consistent state such that `verifyPin(oldPin)` still returns `PinVerificationResult(success: true)`.

7. WHEN `changePin(oldPin, newPin)` is called and `oldPin` is not verified successfully, THE Security_Service SHALL return `ChangePinResult(success: false)` and SHALL NOT modify `_saltKey`, `_encryptionSaltKey`, or the stored PIN hash.

8. WHEN `changePin(oldPin, newPin)` is called and `newPin` equals `oldPin`, THE Security_Service SHALL still generate and persist new salts and a new PIN hash, treating the operation as a full re-key.

9. BEFORE initiating any write during `changePin`, THE Security_Service SHALL write a `_rekeyPendingKey` flag with value `'true'` to FlutterSecureStorage. WHEN `changePin` completes successfully OR rolls back fully, THE Security_Service SHALL delete `_rekeyPendingKey` from FlutterSecureStorage. WHEN the app launches and `_rekeyPendingKey` is present in FlutterSecureStorage, THE app SHALL treat the data as potentially in an indeterminate re-key state and SHALL prompt the user to authenticate with the old PIN; if authentication succeeds, `changePin` SHALL be re-attempted automatically to complete the interrupted operation; if authentication fails or the old PIN is unavailable, the user SHALL be informed that a full PIN reset via security questions or biometrics is required.

> **Safeguard:** Changing the encryption salt means all previously encrypted fields become unreadable under the new key. Requirement 16.2 is only safe if all journal data is re-encrypted under the new key immediately after salt rotation, protected by the `_rekeyPendingKey` crash-recovery flag defined in Requirement 16.9.

---

### Requirement 17: Security — Exponential Backoff on Failed PIN Attempts

**User Story:** As a security-conscious user, I want successive failed PIN attempts to incur increasingly long lockout periods, so that automated brute-force attacks are impractical.

#### Acceptance Criteria

1. WHEN `SecurityConstants.maxAttempts` consecutive failed PIN attempts have occurred within the current lockout cycle, THE Security_Service SHALL increment `lockout_cycle_count` by 1, persist the new value to FlutterSecureStorage, and then trigger a lockout.

2. WHEN a lockout is triggered and `lockout_cycle_count` is `n` (after incrementing), THE Security_Service SHALL set the lockout duration to `base_duration × 2^(n - 1)` seconds, where `base_duration` is `SecurityConstants.lockoutDurationSeconds` and `n >= 1`, such that the first lockout equals exactly `base_duration` seconds.

3. THE lockout duration computed by criterion 2 SHALL be capped at 3600 seconds (1 hour) regardless of cycle count.

4. THE lockout duration SHALL be monotonically non-decreasing across cycles: for all cycle counts `n >= 1`, `lockout_duration(n) >= lockout_duration(n - 1)`, with equality only when both values equal the 3600-second cap.

5. WHEN a PIN attempt succeeds (correct PIN entered), THE Security_Service SHALL reset `lockout_cycle_count` to 0 and persist the reset value to FlutterSecureStorage.

6. WHILE the user is locked out, THE Lock_Screen SHALL display the remaining lockout duration, decrementing the displayed value by 1 each second until it reaches 0.

7. WHEN `resetPinViaSecurityQuestions` or `resetPinViaBiometric` succeeds, THE Security_Service SHALL reset `lockout_cycle_count` to 0 and persist the reset value to FlutterSecureStorage.

8. WHEN a lockout expires (the lockout duration elapses), THE Security_Service SHALL reset the failed-attempt counter for the current cycle to 0 without resetting `lockout_cycle_count`, so that the next `maxAttempts` failures trigger a longer lockout.

---

### Requirement 18: Security — Secure Storage Read Parallelization

**User Story:** As a developer, I want FlutterSecureStorage reads that are independent of each other to run in parallel, so that initialization and PIN verification are as fast as possible.

#### Acceptance Criteria

1. WHEN `Security_Service.verifyPin(pin)` reads `_pinHashKey`, `_saltKey`, `_attemptCountKey`, and `_lockoutUntilKey` from FlutterSecureStorage, THE Security_Service SHALL issue all four reads via a single `Future.wait()` call rather than sequential `await` calls.

2. WHEN `Security_Service.initialize()` reads the initial Salt key (`_saltKey`) and the encryption salt key (`_encryptionSaltKey`), THE Security_Service SHALL issue both reads via a single `Future.wait()` call rather than sequential `await` calls, provided no data dependency exists between the two reads. If either key is absent, the corresponding salt SHALL be generated and written after the parallel read completes.

3. WHEN `verifyPin`, `changePin`, or `initialize` is called after parallelization, THE returned result and any side effects SHALL be identical to those that would be produced by the sequential implementation given the same inputs and storage state (result equivalence property).

4. IF any read within a `Future.wait()` call in `verifyPin` fails (e.g., FlutterSecureStorage throws), THE Security_Service SHALL propagate the failure as a failed `Future` and SHALL NOT return a partial or default verification result.

---

### Requirement 19: Preserve All Existing Functionality

**User Story:** As an existing user, I want all current features to continue working correctly after the overhaul, so that no data is lost and no workflow is broken.

#### Acceptance Criteria

1. THE Journal_Screen SHALL continue to display all existing entries in reverse-chronological order after pagination is introduced.

2. THE Calendar_Screen SHALL continue to display entry indicators (colored dots) correctly for all dates after the pre-computation refactor.

3. THE Security_Service PIN setup, PIN verification, biometric authentication, security questions, and PIN reset flows SHALL remain fully functional after all security changes.

4. THE Backup_Service export and import flows SHALL correctly serialize and deserialize all `JournalEntry` fields — including `id`, `type`, `date`, `headline`, `content`, `mood`, `feeling`, `tags`, `location`, `timeBucket`, `images`, and `isSpotlight` — after the off-thread refactor.

5. THE Identity_Screen rankings, category management, item add/edit/delete, reorder, masking toggle, and search SHALL remain fully functional after the resource leak fixes.

6. WHEN security is enabled and the app is relaunched, THE Root_Orchestrator SHALL present the Lock_Screen before allowing access to any content screen, as currently implemented.

7. THE Profile_Screen security toggle (enable/disable PIN), PIN management navigation, export backup, and manage backups flows SHALL remain fully functional after the profile screen refactor.

---

### Requirement 20: Backup Image Serialization Fix (Data-Loss Defect)

**User Story:** As a user who relies on backups to protect their journal, I want image references to be correctly serialized into backup files so that images are not silently dropped on export.

#### Acceptance Criteria

> **Root cause:** `BackupService._serializeEntry` currently sets `'images': entry.images` — passing a `List<ImageReference>` (Freezed value objects) directly into `jsonEncode`. Because `ImageReference` has no implicit `toJson` override at the `List` serialization level, `jsonEncode` emits `{}` for each element, silently losing all image metadata. This must be fixed before any release.

1. WHEN `BackupService._serializeEntry` serializes a `JournalEntry`, THE `images` field SHALL be serialized as `entry.images.map((i) => i.toJson()).toList()`, producing a JSON array of `ImageReference` maps rather than empty objects.

2. WHEN `BackupService._deserializeEntry` deserializes the `images` field, THE existing `_parseBackupImages` method SHALL correctly reconstruct `ImageReference` objects from the serialized maps (this path already works correctly for the `Map` format).

3. WHEN a backup is exported and then imported, ALL `ImageReference` objects (including `source`, `type`, and any other fields) SHALL be present and equal in the re-imported entry collection.

4. THE fix SHALL be backward-compatible: if the backup file was produced before this fix (and therefore contains `{}` per image entry), THE import SHALL NOT crash; it SHALL silently skip malformed image entries via the existing `_parseBackupImages` fallback path.

---

### Requirement 21: Username / Profile Management UI

**User Story:** As a user, I want to be able to set and edit my display name so that the Profile screen shows my name instead of generic placeholder text.

#### Acceptance Criteria

> **Root cause:** `UserSettings.username` exists in the data model and is stored via `StorageService`, but there is currently no UI to read or write it. The Profile header displays the device name (`_deviceName` from `device_info_plus`) instead.

1. WHEN Profile_Screen loads and `settings.username` is non-null and non-empty, THE Profile_Screen header SHALL display `settings.username`.

2. WHEN Profile_Screen loads and `settings.username` is null or empty, THE Profile_Screen header SHALL display the placeholder "Journaler".

3. THE Profile_Screen SHALL provide an edit affordance (e.g., an edit icon or tap-to-edit interaction on the header) that opens an inline text field or dialog allowing the user to set or change their display name.

4. WHEN the user confirms a new username, THE Profile_Screen SHALL call `StorageService.saveSettings` with the updated `UserSettings` containing the new `username` and immediately reflect the change in the header without requiring a full restart.

5. THE username SHALL be stored persistently in `UserSettings` via the existing `StorageService.saveSettings` path and SHALL survive app restarts.

6. THE username field SHALL accept up to 50 characters. If the user enters more than 50 characters, THE UI SHALL truncate or prevent further input beyond the limit.

---

### Requirement 22: Backup Restore UI

**User Story:** As a user, I want to be able to restore my data from a previous backup listed in the "Manage Backups" sheet, so that I can recover from data loss without needing a separate file picker.

#### Acceptance Criteria

> **Root cause:** `BackupService.importEncryptedFile` and `BackupService.importFromJson` exist but are not reachable from any screen. The "Manage Backups" bottom sheet lists backup files with only a delete action — there is no restore button.

1. WHEN the "Manage Backups" sheet is open and at least one backup file is listed, EACH backup item row SHALL include a restore button (e.g., a restore icon) alongside the existing delete button.

2. WHEN the user taps the restore button for an encrypted backup, THE Profile_Screen SHALL call `BackupService.importEncryptedFile` with that backup's file path and display a progress indicator using the `backupProgressProvider` stages defined in Requirement 15.

3. WHEN the user taps the restore button for an unencrypted backup, THE Profile_Screen SHALL call `BackupService.importFromJson` with the file's contents and display a progress indicator.

4. WHEN a restore completes successfully, THE app SHALL show a non-blocking `SnackBar` message confirming the number of entries and rankings imported, and SHALL invalidate `statsNotifierProvider` so that the Profile stats refresh.

5. WHEN a restore fails (corrupted file, decryption error, etc.), THE app SHALL show a non-blocking `SnackBar` with the failure reason and SHALL NOT leave any partial data committed.

6. BEFORE beginning a restore, THE app SHALL display a confirmation dialog warning the user that restoring will merge entries with their current data (or replace, depending on `merge` flag) and asking them to confirm.

---

### Requirement 23: Spotlight Toggle and Tag Filtering

**User Story:** As a user, I want to mark important entries as "spotlight" entries and filter my journal by tags or spotlight status, so that I can quickly navigate to significant moments.

#### Acceptance Criteria

> **Root cause:** `JournalEntry.isSpotlight` and `tags` are persisted in ObjectBox but there is no toggle in `EntryEditor` and no filter UI in `JournalScreen`. Both fields are effectively dead in the current UI.

1. THE Entry_Editor SHALL include a toggle (e.g., a star icon button in the header) that sets `isSpotlight` to `true` or `false`. The toggle SHALL be visually distinct in the active state (e.g., filled amber star vs. outlined star).

2. WHEN `isSpotlight` is toggled, ONLY the spotlight toggle widget SHALL rebuild; the content, mood, and image widgets SHALL NOT rebuild (consistent with Requirement 10's rebuild-isolation rules).

3. THE Journal_Screen SHALL provide a filter chip or toggle button that, when active, shows only entries where `isSpotlight == true`.

4. THE Journal_Screen SHALL provide a tag filter mechanism: when the user selects one or more tags from the available tag set, THE Journal_Screen SHALL show only entries that contain ALL of the selected tags (AND semantics).

5. WHEN a spotlight or tag filter is active alongside a text search query, THE Journal_Screen SHALL apply all active filters simultaneously (spotlight AND tag AND text search).

6. WHEN the user clears all active filters, THE Journal_Screen SHALL display the full unfiltered (and un-searched) entry list.
