# Requirements Document

## Introduction

DayVault (package: `memory_palace`) is a Flutter personal journal app. A full technical audit identified 17 production-blocking findings spanning cryptographic correctness, authentication bypass, data integrity, rendering performance, and input validation. This document captures all 17 findings as a single security-hardening initiative, grouped into logical requirement areas. Each requirement is derived directly from an audit finding and is expressed using EARS patterns and INCOSE quality rules.

---

## Glossary

- **SecurityService**: The singleton Dart class (`security_service.dart`) responsible for PIN hashing, rate limiting, lockout management, and biometric authentication.
- **EncryptionService**: The singleton Dart class (`encryption_service.dart`) responsible for AES-GCM encryption and decryption of backup and draft data.
- **ObjectBoxService**: The singleton Dart class (`objectbox_service.dart`) responsible for initialising and exposing the ObjectBox database store.
- **StorageService**: The Dart class (`storage_service.dart`) responsible for reading and writing journal entries, rankings, settings, and drafts.
- **BackupService**: The Dart class (`backup_service.dart`) responsible for exporting and importing user data.
- **ProfileScreen**: The Flutter screen (`profile_screen.dart`) that displays cognitive metrics, diagnostics, and system configuration.
- **ForgotPinScreen**: The Flutter screen (`forgot_pin_screen.dart`) that handles PIN reset via security questions or biometric authentication.
- **MainShell**: The Flutter widget (`main.dart`) that hosts the bottom navigation bar and the four primary screens.
- **RootOrchestrator**: The Flutter widget (`main.dart`) that decides whether to show the lock screen or the main shell.
- **GlassContainer**: The Flutter widget (`glass_widgets.dart`) that renders a frosted-glass card using `BackdropFilter`.
- **ImageThumbnailWidget**: The Flutter widget (`image_widgets.dart`) that renders image thumbnails from gallery, URL, or file sources.
- **KDF**: Key Derivation Function — a cryptographic algorithm that derives a fixed-length key from a password and salt.
- **PBKDF2**: Password-Based Key Derivation Function 2 — a standard KDF using iterated HMAC.
- **AES-GCM**: Advanced Encryption Standard in Galois/Counter Mode — an authenticated encryption algorithm that provides both confidentiality and integrity.
- **PIN**: A 4–6 digit numeric passcode used to authenticate the user.
- **Draft**: An auto-saved, in-progress journal entry stored in `FlutterSecureStorage`.
- **Grace Period**: A configurable duration after which the app requires re-authentication when resuming from background.
- **Streak**: The count of consecutive calendar days on which the user created at least one journal entry.

---

## Requirements

---

### Requirement 1: PIN Key Derivation Strength

**User Story:** As a user, I want my PIN to be protected by a strong key derivation function, so that an attacker who obtains the stored hash cannot brute-force my PIN in a practical timeframe.

#### Acceptance Criteria

1. WHEN `SecurityService` derives a PIN hash, THE `SecurityService` SHALL use `pointycastle`'s `PBKDF2KeyDerivator` configured with `HMac(SHA256Digest(), 64)` and exactly 100,000 iterations.
2. THE `SecurityService` SHALL execute PBKDF2 key derivation inside a `compute()` isolate to avoid blocking the UI thread.
3. WHEN the same PIN and salt are provided as inputs, THE `SecurityService` SHALL produce the same hash output on every invocation (determinism invariant).
4. WHEN two different PINs are provided with the same salt, THE `SecurityService` SHALL produce two distinct hash outputs (collision resistance property).
5. THE `SecurityService` SHALL produce a hash output of exactly 32 bytes (256 bits) for every valid PIN input (output length invariant).
6. WHEN `SecurityService` derives the encryption key, THE `SecurityService` SHALL use a separate salt value stored under a distinct secure storage key (`_encryptionSaltKey`) from the PIN hash salt (`_saltKey`).
7. WHEN `SecurityService` derives the encryption key, THE `SecurityService` SHALL use exactly 100,000 PBKDF2 iterations, matching the PIN hash iteration count.
8. WHEN `SecurityService.setPin()` is called for the first time, THE `SecurityService` SHALL generate and persist both the PIN hash salt and the encryption key salt as independent random 16-byte values.

---

### Requirement 2: Authenticated Encryption for Backup and Draft Data

**User Story:** As a user, I want my exported backups and in-progress drafts to be encrypted with authenticated encryption, so that an attacker cannot read or silently tamper with my data.

#### Acceptance Criteria

1. WHEN `EncryptionService.encrypt()` is called, THE `EncryptionService` SHALL retrieve the active encryption key by calling `SecurityService().getCachedEncryptionKey()`.
2. IF `SecurityService().getCachedEncryptionKey()` returns `null`, THEN THE `EncryptionService` SHALL throw a `StateError` with the message `'Encryption key not available: PIN not verified'`.
3. WHEN `EncryptionService.encrypt()` encrypts data, THE `EncryptionService` SHALL use `AESMode.gcm` with a cryptographically secure random 16-byte IV.
4. WHEN `EncryptionService.encrypt()` produces ciphertext, THE `EncryptionService` SHALL append the GCM authentication tag to the output payload.
5. WHEN `EncryptionService.decrypt()` verifies a GCM authentication tag and the tag is invalid, THE `EncryptionService` SHALL throw a `FormatException` rather than returning corrupted plaintext.
6. FOR ALL non-empty plaintext strings, decrypting the output of encrypting that string SHALL return the original plaintext (round-trip property).
7. FOR ALL non-empty plaintext strings, the ciphertext produced by `EncryptionService.encrypt()` SHALL differ from the plaintext (confidentiality invariant).
8. WHEN `StorageService.saveDraft()` stores draft content, THE `StorageService` SHALL encrypt the draft content using `EncryptionService.encrypt()` before writing to `FlutterSecureStorage`.
9. WHEN `StorageService.getDraft()` retrieves draft content, THE `StorageService` SHALL decrypt the content using `EncryptionService.decrypt()` before returning it to the caller.
10. WHEN `StorageService` manages the draft key index, THE `StorageService` SHALL encode and decode the index using `jsonEncode(List<String>)` and `jsonDecode()` rather than comma-delimited string concatenation.
11. FOR ALL sets of draft IDs, calling `StorageService.getAllDraftIds()` after saving those drafts SHALL return a list containing exactly those IDs with no duplicates (set membership invariant).

---

### Requirement 3: Lockout Persistence Across App Restarts

**User Story:** As a user, I want the failed-attempt lockout to survive app force-closes, so that an attacker cannot bypass the lockout by repeatedly restarting the app.

#### Acceptance Criteria

1. WHEN `SecurityService.initialize()` is called, THE `SecurityService` SHALL NOT reset the failed-attempt counter or the lockout timestamp.
2. WHEN `SecurityService.verifyPin()` succeeds, THE `SecurityService` SHALL reset the failed-attempt counter and clear the lockout timestamp.
3. WHEN the app is restarted after a lockout has been set, THE `SecurityService` SHALL preserve the lockout timestamp and continue enforcing the lockout until the lockout duration has elapsed.
4. FOR ALL values of N between 1 and 5 (inclusive), after N failed PIN attempts followed by M calls to `SecurityService.initialize()` (for any M ≥ 1), THE `SecurityService` SHALL report the same remaining-attempts count as it did before the restarts (lockout persistence property).

---

### Requirement 4: Database Migration Safety

**User Story:** As a user, I want the app to protect my journal data when a database schema mismatch occurs, so that a failed migration does not silently destroy all my entries.

#### Acceptance Criteria

1. WHEN `ObjectBoxService.init()` encounters an exception during `openStore()`, THE `ObjectBoxService` SHALL attempt a schema migration before taking any destructive action.
2. IF the schema migration specifically fails (as distinct from other initialisation errors), THEN THE `ObjectBoxService` SHALL copy the existing database directory to a timestamped backup path within the application documents directory before any deletion.
3. IF the schema migration specifically fails, THEN THE `ObjectBoxService` SHALL present the user with a recovery dialog that describes the situation and requires explicit user consent before deleting the original database.
4. THE `ObjectBoxService` SHALL NOT delete the original database directory without explicit user consent obtained through the recovery dialog.
5. WHEN the user grants consent in the recovery dialog, THE `ObjectBoxService` SHALL delete the original database directory and reinitialise the store with a fresh database.
6. IF the schema migration specifically fails and the user denies consent in the recovery dialog, THEN THE `ObjectBoxService` SHALL surface an error to the caller without deleting any data.

---

### Requirement 5: Re-authentication on App Resume

**User Story:** As a user, I want the app to lock itself when I return from the background after a configurable period, so that an unattended device does not expose my journal to others.

#### Acceptance Criteria

1. THE `RootOrchestrator` SHALL implement `WidgetsBindingObserver` and register itself with `WidgetsBinding.instance` during `initState`.
2. WHEN `AppLifecycleState.resumed` is observed and the time elapsed since the app entered the background exceeds the configured grace period, THE `RootOrchestrator` SHALL set `isAuthenticated` to `false` and display the lock screen.
3. WHEN `AppLifecycleState.paused` is observed, THE `RootOrchestrator` SHALL record the current timestamp as the background-entry time.
4. THE `RootOrchestrator` SHALL use a default grace period of 30 seconds when no explicit grace period is configured.
5. WHEN `AppLifecycleState.resumed` is observed and the elapsed time since background entry is less than or equal to the grace period, THE `RootOrchestrator` SHALL NOT reset the authentication state.

---

### Requirement 6: Biometric Authentication Before PIN Reset Advance

**User Story:** As a user, I want biometric authentication to be verified before the PIN reset flow advances to the new-PIN entry step, so that an attacker cannot set a new PIN without passing biometric verification.

#### Acceptance Criteria

1. WHEN the user selects the biometric reset method and taps the authenticate button, THE `ForgotPinScreen` SHALL invoke `SecurityService.isBiometricAvailable()` and `LocalAuthentication.authenticate()` before advancing `_pinStep` to 1.
2. IF biometric authentication fails or is cancelled, THEN THE `ForgotPinScreen` SHALL display a descriptive error message, SHALL NOT advance `_pinStep` beyond 0, and SHALL NOT render the PIN entry keypad until authentication succeeds.
3. IF biometric authentication succeeds, THEN THE `ForgotPinScreen` SHALL advance `_pinStep` to 1 and allow the user to enter a new PIN.
4. WHEN `_completeReset()` is called after a successful biometric authentication, THE `ForgotPinScreen` SHALL NOT perform a second biometric authentication prompt.

---

### Requirement 7: Screen State Preservation and Navigation Performance

**User Story:** As a user, I want tab switching to be fast and preserve the scroll position and state of each screen, so that navigating between tabs does not cause jarring reloads.

#### Acceptance Criteria

1. THE `_MainShellState` SHALL initialise the `_screens` list exactly once inside `initState()` as a `late final` field, and SHALL NOT recreate the list on subsequent `setState()` calls.
2. THE `MainShell` SHALL use an `IndexedStack` widget to display the active screen, replacing the `AnimatedSwitcher` + `KeyedSubtree` combination.
3. WHEN the user switches tabs, THE `MainShell` SHALL preserve the widget subtree and scroll state of all inactive screens.
4. WHEN the user switches tabs, THE `MainShell` SHALL NOT trigger a full rebuild of inactive screen subtrees.

---

### Requirement 8: GlassContainer Rendering Performance

**User Story:** As a user, I want the app UI to render smoothly without frame drops, so that scrolling and navigation feel responsive on mid-range devices.

#### Acceptance Criteria

1. THE `GlassContainer` widget SHALL NOT use `BackdropFilter` or `ImageFilter.blur` in its default rendering path.
2. THE `GlassContainer` widget SHALL simulate the frosted-glass appearance using a static semi-transparent gradient overlay without GPU compositing layers.
3. WHERE a hero blur effect is required (e.g., the bottom navigation bar), THE `MainShell` SHALL apply exactly one `BackdropFilter` instance per screen, managed centrally by `MainShell`, and no other widget on that screen SHALL add an additional `BackdropFilter`.
4. WHEN a screen requires no hero blur effect, THE screen SHALL NOT use `BackdropFilter` at all.

---

### Requirement 9: ObjectBox Query Resource Management

**User Story:** As a developer, I want all ObjectBox queries to be closed even when an exception occurs, so that native query objects do not leak memory or file handles.

#### Acceptance Criteria

1. WHEN `StorageService` builds an ObjectBox query using `query.build()`, THE `StorageService` SHALL close the query object inside a `try/finally` block regardless of whether `find()` or `findFirst()` throws an exception.
2. THE `StorageService` SHALL apply the `try/finally { query.close(); }` pattern to every query in `getJournal()`, `saveJournalEntry()`, `deleteJournalEntry()`, `getJournalEntryById()`, `getFavoriteRankings()`, `addRankingCategory()`, `deleteRankingCategory()`, `updateRankingCategory()`, `addRankedItem()`, `deleteRankedItem()`, and `reorderRankedItems()`.
3. IF a query's `find()` or `findFirst()` call throws an exception, THEN THE `StorageService` SHALL propagate the exception to the caller after closing the query object.
4. THE `StorageService` SHALL track all open query objects so that any query not closed by the `try/finally` block (e.g., due to an unexpected control-flow exit) is closed during the next cleanup cycle.

---

### Requirement 10: Accurate Cognitive Metrics on Profile Screen

**User Story:** As a user, I want the Profile screen to display metrics computed from my actual journal data, so that the statistics reflect my real journaling behaviour rather than fabricated values.

#### Acceptance Criteria

1. THE `ProfileScreen` SHALL compute the streak value by counting the number of consecutive calendar days ending on today (or the most recent entry date) on which the user created at least one journal entry.
2. WHEN the user has no journal entries, THE `ProfileScreen` SHALL display `"—"` for the streak value.
3. THE `ProfileScreen` SHALL NOT display a hardcoded streak value of `"12"`.
4. THE `ProfileScreen` SHALL remove the "Clarity" metric card until a real, documented formula for clarity is defined and implemented.
5. FOR ALL lists of journal entry dates, the computed streak SHALL equal the length of the longest suffix of consecutive calendar days ending on or before today that contains at least one entry per day (streak correctness property).
6. FOR ALL permutations of the same list of journal entry dates, the computed streak SHALL return the same value (order-independence property).

---

### Requirement 11: Asynchronous Decryption Off the UI Thread

**User Story:** As a user, I want the journal list to load without freezing the UI, so that the app remains responsive even when I have hundreds of entries.

#### Acceptance Criteria

1. WHEN `StorageService.getJournal()` loads journal entries, THE `StorageService` SHALL perform all decryption of entry fields in a single `compute()` isolate call rather than on the main UI thread.
2. THE `StorageService` SHALL batch all entries into the isolate in one call rather than spawning one isolate per entry.
3. FOR ALL lists of journal entries, the result of isolate-based batch decryption SHALL be identical to the result of sequential inline decryption for every entry in the list (decryption equivalence property).

---

### Requirement 12: ImageThumbnailWidget State Management

**User Story:** As a developer, I want image loading state to be managed correctly within Flutter's widget lifecycle, so that the app does not trigger illegal setState calls or produce stale UI state.

#### Acceptance Criteria

1. THE `ImageThumbnailWidget` SHALL NOT assign `_isLoading` or `_hasError` directly outside of a `setState()` call.
2. THE `_buildUrlImage()` method SHALL use `CachedNetworkImage`'s `placeholder` and `errorWidget` callbacks to render loading and error states inline, without referencing `_isLoading` or `_hasError` instance variables.
3. THE `_buildFileImage()` method SHALL use `Image.file`'s `errorBuilder` callback to render error states inline, without referencing `_hasError` instance variables.
4. THE `_buildGalleryImage()` method SHALL NOT call `setState()` inside a `FutureBuilder` builder callback.
5. THE `ImageThumbnailWidget` SHALL remove the `_isLoading` and `_hasError` instance variables in a single refactoring change, and SHALL derive loading and error states entirely from widget callback parameters. THE `ImageThumbnailWidget` MAY retain `setState()` calls for other state management purposes unrelated to loading and error states.

---

### Requirement 13: Global Flutter Error Boundary

**User Story:** As a developer, I want all unhandled Flutter and platform exceptions to be captured at the app boundary, so that crashes are logged and do not fail silently in release builds.

#### Acceptance Criteria

1. WHEN the app initialises in `main()`, THE `App` SHALL set `FlutterError.onError` to a handler that logs the error details.
2. WHEN the app initialises in `main()`, THE `App` SHALL set `PlatformDispatcher.instance.onError` to a handler that logs the error details and returns `true`.
3. WHILE the app is running in debug mode, THE error handlers SHALL write error details to the debug console using `debugPrint`, unless a crash reporting integration is explicitly configured for debug mode.
4. WHILE the app is running in release mode, THE error handlers SHALL forward error details to a crash reporting integration. IF the crash reporting integration is unavailable or misconfigured, THEN THE error handlers SHALL fall back to debug console logging rather than failing silently.
5. IF an unhandled exception occurs on the Flutter framework layer, THEN THE `App` SHALL capture it via `FlutterError.onError` without crashing the process.

---

### Requirement 14: Rankings Seeding Race Condition Prevention

**User Story:** As a user launching the app for the first time, I want the default ranking categories to be seeded exactly once, so that the app does not crash with a unique-constraint violation on first launch.

#### Acceptance Criteria

1. WHEN `ObjectBoxService.init()` completes successfully, THE `ObjectBoxService` SHALL seed the default ranking categories into the ObjectBox store if and only if the rankings box is empty.
2. THE `StorageService.getRankings()` method SHALL NOT perform first-launch seeding; seeding SHALL be the sole responsibility of `ObjectBoxService.init()`.
3. WHEN `ObjectBoxService.init()` is called concurrently by multiple callers, THE `ObjectBoxService` SHALL seed the default categories exactly once (idempotence under concurrency).
4. FOR ALL values of N between 2 and 10 (inclusive), N concurrent calls to the seeding logic on an empty rankings box SHALL result in exactly the default set of categories with no duplicate `categoryId` values (concurrency safety property).

---

### Requirement 15: Import Validation and Bounds Checking

**User Story:** As a user, I want the backup import to validate all data before saving it, so that a crafted or corrupted backup file cannot crash the app or corrupt the database.

#### Acceptance Criteria

1. WHEN `BackupService._deserializeEntry()` reads the `type` field from import data, THE `BackupService` SHALL verify that the integer value is within the valid range `[0, EntryType.values.length - 1]` before accessing `EntryType.values`.
2. IF the `type` field is outside the valid range, THEN THE `BackupService` SHALL throw a `FormatException` with a descriptive message rather than a `RangeError`.
3. WHEN `BackupService._deserializeEntry()` reads the `mood` field from import data, THE `BackupService` SHALL verify that the integer value is within the valid range `[0, Mood.values.length - 1]` before accessing `Mood.values`.
4. WHEN `BackupService._deserializeEntry()` reads the `timeBucket` field from import data, THE `BackupService` SHALL verify that the integer value is within the valid range `[0, TimeBucket.values.length - 1]` before accessing `TimeBucket.values`.
5. WHEN `BackupService.importFromJson()` receives a journal list with more than 10,000 entries, THE `BackupService` SHALL reject the import and return a `BackupResult` with `success: false` and a descriptive error message.
6. WHEN `BackupService._deserializeEntry()` reads string fields (`headline`, `content`, `feeling`), THE `BackupService` SHALL truncate any string exceeding 10,000 characters to exactly 10,000 characters before saving, applying this limit consistently to all string fields.
7. FOR ALL integer values outside the valid enum range for `type`, `mood`, or `timeBucket`, `BackupService._deserializeEntry()` SHALL throw a `FormatException` rather than a `RangeError` (bounds safety property).
8. FOR ALL import payloads containing between 1 and 10,000 entries with valid fields, `BackupService.importFromJson()` SHALL successfully import all entries without throwing an exception (valid-input acceptance property).
