# Implementation Plan: DayVault Security Hardening

## Overview

This plan resolves all 17 production-blocking findings from the technical audit. The work is organized into 18 tasks covering cryptographic correctness (T1–T2), authentication hardening (T3, T5–T6), data integrity (T4, T11), performance (T7–T9, T15), correctness (T10, T12–T14), and a full test suite (T16–T18). Tasks are ordered to respect dependencies — cryptographic foundations first, then authentication, then data layer, then UI, then tests.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "tasks": ["T1"],
      "description": "Cryptographic foundation — must be correct before anything that uses keys"
    },
    {
      "wave": 2,
      "tasks": ["T2", "T3"],
      "description": "T2 depends on T1 (real key needed). T3 is independent but logically grouped with security fixes."
    },
    {
      "wave": 3,
      "tasks": ["T4", "T5", "T6", "T7", "T8", "T9", "T13", "T14"],
      "description": "All independent of each other. T4 is prerequisite for T11."
    },
    {
      "wave": 4,
      "tasks": ["T10", "T11", "T12"],
      "description": "T10 (query fix) and T11 (seeding, depends on T4) and T12 (streak, depends on T10 being stable)"
    },
    {
      "wave": 5,
      "tasks": ["T15"],
      "description": "T15 (batch isolate decrypt) depends on T2 (encryption stable) and T10 (storage stable)"
    },
    {
      "wave": 6,
      "tasks": ["T16", "T17", "T18"],
      "description": "All tests — depend on T1–T15 complete"
    }
  ]
}
```

## Tasks

- [ ] 1. Replace fake PBKDF2 with real pointycastle implementation in SecurityService

  **Requirement:** R1  
  **File:** `lib/services/security_service.dart`

  - [ ] 1.1 Add `import 'package:pointycastle/key_derivators/pbkdf2.dart'`, `import 'package:pointycastle/macs/hmac.dart'`, `import 'package:pointycastle/digests/sha256.dart'`, `import 'package:pointycastle/key_derivators/api.dart'` at the top of `security_service.dart`
  - [ ] 1.2 Add `static const String _encryptionSaltKey = 'encryption_salt'` to `SecurityService`
  - [ ] 1.3 Delete the `_pbkdf2Hash` top-level function and the `_deriveKeyBinary` top-level function entirely
  - [ ] 1.4 Add a new top-level function `Uint8List _pbkdf2Derive(Map<String, dynamic> params)` that uses `PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))` with `Pbkdf2Parameters(utf8.encode(salt), iterations, keyLength)` and returns the derived key bytes
  - [ ] 1.5 Update `_hashPin()` to call `compute(_pbkdf2Derive, {'pin': pin, 'salt': salt, 'iterations': 100000, 'keyLength': 32})` and return `base64Encode(keyBytes)`
  - [ ] 1.6 Update `_deriveAndCacheEncryptionKey()` to read from `_encryptionSaltKey` (not `_saltKey`), generate and persist the encryption salt if absent, and call `compute(_pbkdf2Derive, {'pin': pin, 'salt': encSalt, 'iterations': 100000, 'keyLength': 32})`
  - [ ] 1.7 Update `setPin()` to generate and persist both `_saltKey` (PIN hash salt) and `_encryptionSaltKey` (encryption salt) as independent 16-byte random values before hashing
  - [ ] 1.8 Add `requiresPinReset` field to `PinVerificationResult` class (default `false`)
  - [ ] 1.9 In `verifyPin()`, before comparing hashes, check if `storedHash.length == 64` (old hex format); if so, delete the old hash and return `PinVerificationResult(success: false, error: 'Security upgrade required. Please set a new PIN.', requiresPinReset: true)`
  - [ ] 1.10 Add `SecurityService.resetPinDirectly(String newPin)` method that validates the PIN, deletes the old hash, derives and stores a new hash, and calls `_resetAttempts()` — without any biometric prompt

- [ ] 2. Fix EncryptionService: wire real key, switch to AES-GCM, encrypt drafts

  **Requirement:** R2  
  **Files:** `lib/services/encryption_service.dart`, `lib/services/storage_service.dart`

  - [ ] 2.1 Update `EncryptionService._getDerivedKey()` to call `SecurityService().getCachedEncryptionKey()` and throw `StateError('Encryption key not available: PIN not verified')` if the result is null — remove the zero-filled placeholder key
  - [ ] 2.2 Update `EncryptionService.encrypt()` to use `encrypt_lib.AESMode.gcm` instead of `AESMode.cbc`
  - [ ] 2.3 Update `EncryptionService.encrypt()` to append `encrypted.mac!.bytes` (16-byte GCM tag) to the payload after the ciphertext, producing the format: `[version=2][16-byte IV][ciphertext][16-byte GCM tag]`
  - [ ] 2.4 Update `EncryptionService._decryptAes()` to extract the last 16 bytes as the GCM tag, pass it to the decrypter, and throw `FormatException('GCM tag verification failed: ...')` on `ArgumentError` from the decrypter
  - [ ] 2.5 Update `StorageService.saveDraft()` to call `await EncryptionService().encrypt(draftData)` before writing to `FlutterSecureStorage`
  - [ ] 2.6 Update `StorageService.getDraft()` to call `await EncryptionService().decrypt(raw)` after reading from `FlutterSecureStorage`
  - [ ] 2.7 Update `StorageService.getAllDraftIds()` to decode the key index using `(jsonDecode(json) as List).cast<String>()` instead of `draftKeysJson.split(',')`
  - [ ] 2.8 Update `StorageService.saveDraft()` to encode the key index using `jsonEncode(existingDrafts)` instead of `existingDrafts.join(',')`
  - [ ] 2.9 Update `StorageService.deleteDraft()` to encode the updated key index using `jsonEncode(existingDrafts)` instead of `existingDrafts.join(',')`

- [ ] 3. Fix lockout persistence: remove _resetAttempts() from initialize() and biometric path

  **Requirement:** R3  
  **Files:** `lib/services/security_service.dart`, `lib/screens/lock_screen.dart`

  - [ ] 3.1 Remove the `await _resetAttempts()` call from `SecurityService.initialize()` — the method body should only create the PIN hash salt if absent
  - [ ] 3.2 In `LockScreen._authenticateBiometric()`, remove the `await _securityService.initialize()` call from the `if (didAuthenticate)` branch — call `widget.onUnlock()` directly

- [ ] 4. Fix ObjectBoxService: safe database migration with backup and user consent

  **Requirement:** R4  
  **Files:** `lib/services/objectbox_service.dart`, `lib/main.dart`

  - [ ] 4.1 Add `enum InitResult { success, migrationRequired, fatalError }` and `class ObjectBoxInitOutcome` with fields `result`, `backupPath`, and `errorMessage` to `objectbox_service.dart`
  - [ ] 4.2 Change `ObjectBoxService.init()` return type from `Future<ObjectBoxService>` to `Future<ObjectBoxInitOutcome>`
  - [ ] 4.3 In the `catch` block of `ObjectBoxService.init()`, replace the `_deleteDatabase()` call with a `Directory(dbPath).rename(backupPath)` call where `backupPath = '${dir.path}/objectbox_backup_${DateTime.now().millisecondsSinceEpoch}'`
  - [ ] 4.4 If the rename succeeds, return `ObjectBoxInitOutcome(InitResult.migrationRequired, backupPath: backupPath)` instead of reinitializing
  - [ ] 4.5 If the rename fails, return `ObjectBoxInitOutcome(InitResult.fatalError, errorMessage: ...)` without deleting anything
  - [ ] 4.6 Add `ObjectBoxService.reinitializeAfterConsent(String backupPath)` static method that opens a fresh store and calls `_seedDefaultsIfNeeded()`
  - [ ] 4.7 Update `main()` to receive `ObjectBoxInitOutcome` from `ObjectBoxService.init()` and pass it to `MemoryPalaceApp`
  - [ ] 4.8 Update `MemoryPalaceApp` and `RootOrchestrator` to show an `AlertDialog` when `outcome.result == InitResult.migrationRequired`, with "Start Fresh" and "Cancel" buttons; "Start Fresh" calls `ObjectBoxService.reinitializeAfterConsent(outcome.backupPath!)`

- [ ] 5. Add re-authentication on app resume to RootOrchestrator

  **Requirement:** R5  
  **File:** `lib/main.dart`

  - [ ] 5.1 Add `with WidgetsBindingObserver` to `_RootOrchestratorState`
  - [ ] 5.2 Add `DateTime? _backgroundedAt` field to `_RootOrchestratorState`
  - [ ] 5.3 Add `static const _gracePeriod = Duration(seconds: 30)` to `_RootOrchestratorState`
  - [ ] 5.4 In `initState()`, call `WidgetsBinding.instance.addObserver(this)` after `super.initState()`
  - [ ] 5.5 In `dispose()`, call `WidgetsBinding.instance.removeObserver(this)` before `super.dispose()`
  - [ ] 5.6 Override `didChangeAppLifecycleState(AppLifecycleState state)`: on `paused`, set `_backgroundedAt = DateTime.now()`; on `resumed`, if `_backgroundedAt != null` and elapsed time exceeds `_gracePeriod`, call `setState(() => isAuthenticated = false)`

- [ ] 6. Fix ForgotPinScreen: perform biometric auth before advancing PIN step

  **Requirement:** R6  
  **File:** `lib/screens/forgot_pin_screen.dart`

  - [ ] 6.1 Add `final LocalAuthentication _localAuth = LocalAuthentication()` field to `_ForgotPinScreenState`
  - [ ] 6.2 Rewrite `_resetViaBiometric()` to: set `_isLoading = true`, call `_securityService.isBiometricAvailable()`, call `_localAuth.authenticate(localizedReason: 'Authenticate to reset your PIN')`, advance `_pinStep = 1` only on `didAuthenticate == true`, set `_errorMessage` and reset `_isLoading` on failure or cancellation, and wrap everything in `try/catch`
  - [ ] 6.3 In `_completeReset()`, replace the biometric branch (`_resetMethod == 1`) to call `_securityService.resetPinDirectly(_newPin)` instead of `_securityService.resetPinViaBiometric(_newPin)` — no second biometric prompt

- [ ] 7. Replace AnimatedSwitcher with IndexedStack and fix _screens initialization

  **Requirement:** R7  
  **File:** `lib/main.dart`

  - [ ] 7.1 Change `final List<Widget> _screens = [...]` to `late final List<Widget> _screens` in `_MainShellState`
  - [ ] 7.2 Initialize `_screens` inside `initState()` with `const` widget instances: `_screens = const [JournalScreen(), CalendarScreen(), IdentityScreen(), ProfileScreen()]`
  - [ ] 7.3 Replace the `AnimatedSwitcher(child: KeyedSubtree(key: ValueKey(_idx), child: _screens[_idx]))` widget with `IndexedStack(index: _idx, children: _screens)`

- [ ] 8. Remove BackdropFilter from GlassContainer default path

  **Requirement:** R8  
  **Files:** `lib/widgets/glass_widgets.dart`, `lib/main.dart`

  - [ ] 8.1 Add `final bool useBackdropFilter` parameter to `GlassContainer` constructor with default value `false`
  - [ ] 8.2 Update `GlassContainer.build()` to skip `BackdropFilter` when `useBackdropFilter == false`, returning `ClipRRect(child: Container(...))` directly
  - [ ] 8.3 When `useBackdropFilter == true`, wrap the `Container` in `BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: container)` as before
  - [ ] 8.4 In `MainShell.build()`, add `useBackdropFilter: true` to the nav bar `GlassContainer` only — all other `GlassContainer` usages across all screens keep the default `false`

- [ ] 9. Wrap all ObjectBox queries in try/finally to prevent resource leaks

  **Requirement:** R9  
  **File:** `lib/services/storage_service.dart`

  - [ ] 9.1 In `getJournal()`, wrap `query.find()` in `try { ... } finally { query.close(); }`
  - [ ] 9.2 In `saveJournalEntry()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.3 In `deleteJournalEntry()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.4 In `getJournalEntryById()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.5 In `getFavoriteRankings()`, wrap `query.find()` in `try { ... } finally { query.close(); }`
  - [ ] 9.6 In `addRankingCategory()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.7 In `deleteRankingCategory()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.8 In `updateRankingCategory()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.9 In `addRankedItem()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.10 In `deleteRankedItem()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`
  - [ ] 9.11 In `reorderRankedItems()`, wrap the lookup query's `findFirst()` in `try { ... } finally { query.close(); }`

- [ ] 10. Replace hardcoded streak with computed value; remove Clarity card

  **Requirement:** R10  
  **Files:** `lib/services/storage_service.dart`, `lib/screens/profile_screen.dart`

  - [ ] 10.1 Add `static int computeStreak(List<JournalEntry> entries)` to `StorageService`: extract unique calendar dates, sort descending, return 0 if empty or if most recent entry is older than yesterday, otherwise count consecutive days from today backward
  - [ ] 10.2 Add `int _streak = 0` field to `_ProfileScreenState`
  - [ ] 10.3 In `_ProfileScreenState._load()`, compute `_streak = StorageService.computeStreak(j)` and include it in the `setState()` call
  - [ ] 10.4 Update the "Streak" `_statCard` call to display `_streak == 0 ? "—" : "$_streak"` instead of the hardcoded `"12"`
  - [ ] 10.5 Remove the "Clarity" `_statCard` call entirely from `ProfileScreen.build()`

- [ ] 11. Move rankings seeding to ObjectBoxService.init(); remove from StorageService

  **Requirement:** R14  
  **Files:** `lib/services/objectbox_service.dart`, `lib/services/storage_service.dart`

  - [ ] 11.1 Add `static Future<void> _seedDefaultsIfNeeded()` to `ObjectBoxService` that checks `box.count() > 0` and returns early if already seeded, otherwise inserts the 5 default `ObjectBoxRankingCategory` records
  - [ ] 11.2 Call `await _seedDefaultsIfNeeded()` inside `ObjectBoxService.init()` immediately after the store is successfully opened (both in the happy path and in `reinitializeAfterConsent()`)
  - [ ] 11.3 Remove the first-launch seeding block from `StorageService.getRankings()` — the method should only call `_rankingBox.getAll()` and map to `RankingCategory`

- [ ] 12. Fix ImageThumbnailWidget: remove illegal state mutations outside setState

  **Requirement:** R12  
  **File:** `lib/widgets/image_widgets.dart`

  - [ ] 12.1 Remove `bool _isLoading` and `bool _hasError` instance variables from `_ImageThumbnailWidgetState`
  - [ ] 12.2 Rewrite `_buildGalleryImage()` as a `FutureBuilder<Uint8List?>` that renders a `CircularProgressIndicator` while `connectionState == waiting`, renders `Image.memory` on success, and renders a `broken_image` icon on null/error — with no `setState()` calls inside the builder
  - [ ] 12.3 Rewrite `_buildUrlImage()` to use `CachedNetworkImage` with `placeholder` callback rendering a `CircularProgressIndicator` and `errorWidget` callback rendering a `broken_image` icon — remove all `_hasError` references
  - [ ] 12.4 Rewrite `_buildFileImage()` to use `Image.file` with `errorBuilder` callback rendering a `broken_image` icon — remove all `_hasError` references
  - [ ] 12.5 Update `build()` to remove the `if (_isLoading)` and `if (_hasError)` overlay widgets from the `Stack` children — loading and error states are now handled inline by each image builder

- [ ] 13. Add global Flutter error boundary in main()

  **Requirement:** R13  
  **File:** `lib/main.dart`

  - [ ] 13.1 After `WidgetsFlutterBinding.ensureInitialized()`, set `FlutterError.onError` to a handler that calls `FlutterError.presentError(details)` and `debugPrint('FlutterError: ${details.exceptionAsString()}')`
  - [ ] 13.2 After setting `FlutterError.onError`, set `PlatformDispatcher.instance.onError` to a handler that calls `debugPrint('PlatformError: $error\n$stack')` and returns `true`
  - [ ] 13.3 Add a `// TODO: forward to crash reporting (e.g. Firebase Crashlytics) in release` comment in both handlers to mark the integration point

- [ ] 14. Add import validation and bounds checking to BackupService

  **Requirement:** R15  
  **File:** `lib/services/backup_service.dart`

  - [ ] 14.1 Add private helper `T _safeEnumValue<T>(List<T> values, int? index, String fieldName)` that throws `FormatException` with a descriptive message if `index` is null or outside `[0, values.length - 1]`
  - [ ] 14.2 Add private helper `String? _truncate(String? value, {int maxLength = 10000})` that returns the first `maxLength` characters if the string exceeds the limit
  - [ ] 14.3 In `importFromJson()`, add a check immediately after extracting `journalList`: if `journalList.length > 10000`, return `BackupResult(success: false, error: 'Backup contains ${journalList.length} entries; maximum is 10,000')`
  - [ ] 14.4 In `_deserializeEntry()`, replace `EntryType.values[data['type'] as int]` with `_safeEnumValue(EntryType.values, data['type'] as int?, 'type')`
  - [ ] 14.5 In `_deserializeEntry()`, replace `Mood.values[data['mood'] as int]` with `_safeEnumValue(Mood.values, data['mood'] as int?, 'mood')`
  - [ ] 14.6 In `_deserializeEntry()`, replace `TimeBucket.values[data['timeBucket'] as int]` with `_safeEnumValue(TimeBucket.values, data['timeBucket'] as int, 'timeBucket')`
  - [ ] 14.7 In `_deserializeEntry()`, wrap `headline`, `content`, and `feeling` string fields with `_truncate(data['headline'] as String?)` etc.

- [ ] 15. Add batch isolate decryption to StorageService.getJournal()

  **Requirement:** R11  
  **Files:** `lib/services/storage_service.dart`, `lib/models/objectbox_models.dart`

  - [ ] 15.1 Add `Map<String, dynamic> toRawMap()` to `ObjectBoxJournalEntry` that returns all fields as a plain map without calling `_maybeDecrypt` on any field
  - [ ] 15.2 Add `JournalEntry toFreezedFromDecrypted(Map<String, dynamic> decrypted)` to `ObjectBoxJournalEntry` that constructs a `JournalEntry` using pre-decrypted field values from the map (no decryption logic inside this method)
  - [ ] 15.3 Add top-level function `List<Map<String, dynamic>> _batchDecryptEntries(List<Map<String, dynamic>> rawMaps)` outside any class, containing the `_maybeDecryptField` logic moved from `ObjectBoxJournalEntry._maybeDecrypt`
  - [ ] 15.4 Update `StorageService.getJournal()` to: call `results.map((e) => e.toRawMap()).toList()`, pass the list to `compute(_batchDecryptEntries, rawMaps)`, then reconstruct entries using `results[i].toFreezedFromDecrypted(decryptedMaps[i])`
  - [ ] 15.5 Remove the `_maybeDecrypt` static method from `ObjectBoxJournalEntry` once the logic has been moved to the top-level `_batchDecryptEntries` function

- [ ] 16. Write unit tests for all security and data layer changes

  **Requirements:** R1–R3, R9–R11, R14–R15  
  **Files:** `test/security_service_test.dart`, `test/encryption_service_test.dart`, `test/storage_service_test.dart`, `test/backup_service_test.dart`, `test/objectbox_service_test.dart`

  - [ ] 16.1 Create `test/security_service_test.dart` with tests for: PBKDF2 determinism (P1), collision resistance (P2), 32-byte output (P3), independent salts, `initialize()` does not reset attempts, `initialize()` does not clear lockout, `verifyPin()` resets on success, 5 failures trigger lockout, lockout survives N `initialize()` calls (P6), old 64-char hash triggers `requiresPinReset`, `resetPinDirectly()` sets new hash without biometric
  - [ ] 16.2 Create `test/encryption_service_test.dart` with tests for: round-trip encrypt/decrypt (P4), ciphertext ≠ plaintext (P5), two encryptions of same plaintext differ (random IV), tampered ciphertext throws `FormatException`, `_getDerivedKey()` throws `StateError` when key is null, mode is GCM not CBC
  - [ ] 16.3 Create `test/storage_service_test.dart` with tests for: `saveDraft` stores encrypted content, `getDraft` decrypts correctly, `getAllDraftIds` uses JSON encoding, draft ID set membership invariant (P10), `query.close()` called on exception, `computeStreak([])` == 0, streak for 7 consecutive days == 7, streak with gap == 0, order-independence (P7), batch isolate decrypt == inline decrypt (P9)
  - [ ] 16.4 Create `test/backup_service_test.dart` with tests for: `type=999` throws `FormatException`, `mood=999` throws `FormatException`, `timeBucket=999` throws `FormatException`, 10,001 entries rejected, headline > 10,000 chars truncated, 10,000 valid entries all imported (P13), partial import with mixed valid/invalid entries
  - [ ] 16.5 Create `test/objectbox_service_test.dart` with tests for: `openStore()` failure renames DB to backup path, `InitResult.migrationRequired` returned, DB not deleted without consent, `_seedDefaultsIfNeeded()` idempotent, concurrent seeding produces no duplicates (P11)

- [ ] 17. Write widget tests for UI and lifecycle changes

  **Requirements:** R5–R8, R12  
  **Files:** `test/widget/root_orchestrator_test.dart`, `test/widget/main_shell_test.dart`, `test/widget/forgot_pin_screen_test.dart`, `test/widget/image_thumbnail_widget_test.dart`, `test/widget/profile_screen_test.dart`

  - [ ] 17.1 Create `test/widget/root_orchestrator_test.dart`: security enabled → `LockScreen` shown; security disabled → `MainShell` shown; `paused` then `resumed` after >30s → `LockScreen` shown; `paused` then `resumed` within 30s → `MainShell` stays; observer registered in `initState` and removed in `dispose`
  - [ ] 17.2 Create `test/widget/main_shell_test.dart`: tab switch does not call `initState` on visited screens; scroll position preserved; `_screens` initialized once; only one `BackdropFilter` in widget tree
  - [ ] 17.3 Create `test/widget/forgot_pin_screen_test.dart`: biometric auth fails → `_pinStep` remains 0; biometric cancelled → error message shown; biometric succeeds → `_pinStep` == 1; `_isLoading` reset on all outcomes; no second biometric prompt in `_completeReset()`
  - [ ] 17.4 Create `test/widget/image_thumbnail_widget_test.dart`: gallery loading spinner shown while future pending; image shown after resolve; error icon on null; URL placeholder shown; URL error icon on failure; file error icon on missing file; no `setState`-during-build assertion errors
  - [ ] 17.5 Create `test/widget/profile_screen_test.dart`: streak shows "—" with no entries; streak shows computed value not "12"; "Clarity" card absent; streak updates after load

- [ ] 18. Write integration and E2E tests

  **Requirements:** R1–R5, R11, R15  
  **Files:** `test/integration/pin_security_test.dart`, `test/integration/backup_restore_test.dart`, `test/integration/database_migration_test.dart`, `test/integration/journal_load_performance_test.dart`

  - [ ] 18.1 Create `test/integration/pin_security_test.dart`: 5 wrong PINs → lockout shown; app restart → lockout still active; lockout expires → PIN re-enabled; correct PIN after expiry → unlocks; background >30s → lock screen on resume; background <30s → no lock screen
  - [ ] 18.2 Create `test/integration/backup_restore_test.dart`: export encrypted → `.encrypted` file created; import encrypted → all entries restored; import tampered encrypted → `FormatException`, no corruption; import out-of-range enum → partial import reported; export unencrypted → readable JSON
  - [ ] 18.3 Create `test/integration/database_migration_test.dart`: schema mismatch → recovery dialog shown; user taps OK → fresh DB, app usable; user taps Cancel → backup preserved, error screen shown; backup file exists at expected path
  - [ ] 18.4 Create `test/integration/journal_load_performance_test.dart`: 500 entries load in < 500ms; 1,000 entries → UI thread frame time < 16ms during load (isolate batch decrypt verified)

## Notes

- **Migration path for existing users:** T1 introduces a new hash format (44-char base64 vs old 64-char hex). The `verifyPin()` migration guard (T1.9) detects old hashes and forces PIN re-setup. Users will see a one-time "Security upgrade required" message on first launch after the update. This is unavoidable and intentional.
- **Encryption key availability:** After T2, `EncryptionService.encrypt()` throws `StateError` if called before PIN verification. `BackupService.exportToFile(encrypted: true)` must only be called from authenticated screens. The `ProfileScreen` backup buttons are already behind the auth gate — no routing changes needed.
- **IndexedStack memory trade-off (T7):** `IndexedStack` keeps all 4 screen subtrees in memory simultaneously. On devices with < 1GB RAM, this may increase baseline memory usage by ~20–40MB. This is an acceptable trade-off for the elimination of `initState` re-runs and scroll position loss. Monitor with Flutter DevTools memory profiler after deployment.
- **BackdropFilter removal (T8):** The visual change from removing `BackdropFilter` is imperceptible at the opacity levels used (0.03–0.07 alpha). The gradient simulation is visually equivalent. No design review is required.
- **Test infrastructure:** Tests T16–T18 require `mockito` for mocking `FlutterSecureStorage` and `LocalAuthentication`. Add `mockito: ^5.4.0` and `build_runner` to `dev_dependencies` if not already present. ObjectBox integration tests require a real store — use `objectbox_test` helpers or a temp directory fixture.
- **Task ordering for PRs:** Each wave in the dependency graph maps to a logical PR boundary. Wave 1–2 (T1–T3) should be reviewed together as the cryptographic foundation. Wave 3–4 (T4–T12) can be split by file. Wave 5 (T15) should be reviewed after T2 and T10 are merged. Wave 6 (T16–T18) is the test PR.
