# Design Document: DayVault Security Hardening

## Overview

DayVault (package: `memory_palace`) is a Flutter personal journal app. A full technical audit identified 17 production-blocking findings across five categories: cryptographic correctness, authentication bypass, data integrity, rendering performance, and input validation. This design document covers all 15 requirements derived from those findings and specifies the exact code changes required to resolve each one.

The hardening initiative is a surgical refactor — no new screens, no new dependencies beyond those already declared. Every change targets a specific, identified defect in an existing class.

### Scope Summary

| Area | Requirements | Files Affected |
|---|---|---|
| Cryptography | R1, R2 | `security_service.dart`, `encryption_service.dart` |
| Authentication | R3, R5, R6 | `security_service.dart`, `main.dart`, `forgot_pin_screen.dart` |
| Data Integrity | R4, R14, R15 | `objectbox_service.dart`, `storage_service.dart`, `backup_service.dart` |
| Performance | R7, R8, R9, R11 | `main.dart`, `glass_widgets.dart`, `storage_service.dart` |
| Correctness | R10, R12, R13 | `profile_screen.dart`, `image_widgets.dart`, `main.dart` |

---

## Architecture

DayVault follows a layered architecture with Riverpod for state management and ObjectBox as the local database. The security hardening does not change the architecture — it corrects defects within the existing layers.


```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                         │
│  main.dart (RootOrchestrator, MainShell)                        │
│  screens/ (LockScreen, ForgotPinScreen, ProfileScreen, ...)     │
│  widgets/ (GlassContainer, ImageThumbnailWidget)                │
└────────────────────────┬────────────────────────────────────────┘
                         │ Riverpod Providers
┌────────────────────────▼────────────────────────────────────────┐
│                      Service Layer                              │
│  SecurityService   EncryptionService   BackupService            │
│  StorageService    ObjectBoxService                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│                    Persistence Layer                            │
│  ObjectBox (journal, rankings, settings)                        │
│  FlutterSecureStorage (PIN hash, salts, drafts)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Key Dependency Flow (Security Path)

```
main()
  └─ ObjectBoxService.init()          [R4, R14]
  └─ SecurityService.initialize()     [R3]
  └─ FlutterError.onError = handler   [R13]
  └─ PlatformDispatcher.onError = handler [R13]

RootOrchestrator (WidgetsBindingObserver) [R5]
  └─ LockScreen → SecurityService.verifyPin()
       └─ _deriveAndCacheEncryptionKey()  [R1]
            └─ EncryptionService (key now available) [R2]

ForgotPinScreen [R6]
  └─ LocalAuthentication.authenticate()
  └─ SecurityService.resetPinDirectly()

MainShell [R7, R8]
  └─ IndexedStack(_screens)
  └─ BackdropFilter (nav bar only)

StorageService [R2, R9, R10, R11]
  └─ ObjectBox queries (try/finally)
  └─ compute() isolate for batch decryption
  └─ computeStreak() pure function

BackupService [R15]
  └─ _safeEnumValue() bounds checking
  └─ 10,000-entry limit
  └─ 10,000-char string truncation
```

---

## Components and Interfaces

### R1 — SecurityService: PIN Key Derivation Strength

**Problem:** `_pbkdf2Hash` uses a hand-rolled HMAC loop that only executes `iterations ~/ 1000` rounds (100 rounds for 100,000 iterations). `_deriveKeyBinary` uses 10,000 iterations. Neither uses a proper PBKDF2 implementation.

**Solution:** Replace both functions with `pointycastle`'s `PBKDF2KeyDerivator`.


**New constants in `SecurityService`:**
```dart
static const String _encryptionSaltKey = 'encryption_salt';
```

**New isolate top-level function (replaces `_pbkdf2Hash` and `_deriveKeyBinary`):**
```dart
// Top-level function — must be outside the class for compute()
Uint8List _pbkdf2Derive(Map<String, dynamic> params) {
  final pin       = params['pin']        as String;
  final salt      = params['salt']       as String;
  final iterations = params['iterations'] as int;
  final keyLength  = params['keyLength']  as int;

  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(
    Uint8List.fromList(utf8.encode(salt)),
    iterations,
    keyLength,
  ));
  return derivator.process(Uint8List.fromList(utf8.encode(pin)));
}
```

**Updated `_hashPin` (returns hex string for storage comparison):**
```dart
Future<String> _hashPin(String pin, String salt) async {
  final keyBytes = await compute(_pbkdf2Derive, {
    'pin': pin, 'salt': salt, 'iterations': 100000, 'keyLength': 32,
  });
  return base64Encode(keyBytes); // 44-char base64 of 32 bytes
}
```

**Updated `_deriveAndCacheEncryptionKey` (uses separate salt, 100,000 iterations):**
```dart
Future<void> _deriveAndCacheEncryptionKey(String pin) async {
  // Use the dedicated encryption salt, not the PIN hash salt
  String? encSalt = await _storage.read(key: _encryptionSaltKey);
  if (encSalt == null) {
    encSalt = _generateSalt();
    await _storage.write(key: _encryptionSaltKey, value: encSalt);
  }
  final keyBytes = await compute(_pbkdf2Derive, {
    'pin': pin, 'salt': encSalt, 'iterations': 100000, 'keyLength': 32,
  });
  _cachedEncryptionKey = keyBytes;
}
```

**Updated `setPin` (generates both salts on first call):**
```dart
Future<bool> setPin(String pin) async {
  if (!_isValidPin(pin)) return false;
  if (await isPinSet()) return false;

  // Generate PIN hash salt
  final pinSalt = _generateSalt();
  await _storage.write(key: _saltKey, value: pinSalt);

  // Generate encryption key salt (independent)
  final encSalt = _generateSalt();
  await _storage.write(key: _encryptionSaltKey, value: encSalt);

  final hash = await _hashPin(pin, pinSalt);
  await _storage.write(key: _pinHashKey, value: hash);
  return true;
}
```

**Migration path:** Existing stored hashes are 64-char hex strings (SHA-256 output). New hashes are 44-char base64 strings (32-byte PBKDF2 output). On first login after update, `inputHash != storedHash` because the format changed. Detection: if `storedHash.length == 64` (old format), force PIN re-setup by deleting the old hash and prompting the user to set a new PIN.

```dart
// In verifyPin(), before comparing:
if (storedHash != null && storedHash.length == 64) {
  // Old hash format detected — invalidate and force re-setup
  await _storage.delete(key: _pinHashKey);
  return PinVerificationResult(
    success: false,
    error: 'Security upgrade required. Please set a new PIN.',
    requiresPinReset: true,
  );
}
```

---

### R2 — EncryptionService: Authenticated Encryption (AES-GCM)

**Problem:** `_getDerivedKey()` returns a zero-filled key. `encrypt()` uses `AESMode.cbc` (no authentication tag). The GCM tag is not appended. Draft data is stored unencrypted.

**Solution:** Wire `_getDerivedKey()` to `SecurityService`, switch to `AESMode.gcm`, append the MAC tag, and encrypt/decrypt drafts in `StorageService`.


**Updated `_getDerivedKey()`:**
```dart
Future<Uint8List> _getDerivedKey() async {
  final key = SecurityService().getCachedEncryptionKey();
  if (key == null) {
    throw StateError('Encryption key not available: PIN not verified');
  }
  return key;
}
```

**Updated `encrypt()` — AES-GCM with appended MAC:**
```dart
Future<String?> encrypt(String plainText) async {
  if (plainText.isEmpty) return plainText;
  try {
    final keyBytes = await _getDerivedKey();
    final key = encrypt_lib.Key(keyBytes);
    final iv  = encrypt_lib.IV.fromSecureRandom(16);

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(
      Uint8List.fromList(utf8.encode(plainText)), iv: iv,
    );

    // Payload: [1 byte version=2][16 bytes IV][N bytes ciphertext][16 bytes GCM tag]
    final combined = Uint8List.fromList([
      _currentEncryptionVersion,
      ...iv.bytes,
      ...encrypted.bytes,
      ...encrypted.mac!.bytes,
    ]);
    return base64Encode(combined);
  } catch (e, st) {
    debugPrint('Encryption failed: $e\n$st');
    rethrow;
  }
}
```

**Updated `_decryptAes()` — AES-GCM with tag verification:**
```dart
Future<String> _decryptAes(Uint8List data) async {
  // data = [16 bytes IV][N bytes ciphertext][16 bytes GCM tag]
  if (data.length < 33) throw const FormatException('Encrypted data too short');

  final ivBytes      = data.sublist(0, 16);
  final tagBytes     = data.sublist(data.length - 16);
  final cipherBytes  = data.sublist(16, data.length - 16);

  final iv       = encrypt_lib.IV(ivBytes);
  final keyBytes = await _getDerivedKey();
  final key      = encrypt_lib.Key(keyBytes);

  final encrypter = encrypt_lib.Encrypter(
    encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
  );

  try {
    final encrypted = encrypt_lib.Encrypted(cipherBytes);
    final mac       = encrypt_lib.Mac(tagBytes);
    return encrypter.decrypt(
      encrypt_lib.Encrypted.fromBase64(
        base64Encode(Uint8List.fromList([...cipherBytes, ...tagBytes])),
      ),
      iv: iv,
    );
  } on ArgumentError catch (e) {
    throw FormatException('GCM tag verification failed: $e');
  }
}
```

**Payload format diagram:**
```
Byte offset:  0        1       17          17+N      17+N+16
              ┌────────┬───────┬───────────┬─────────┐
              │version │  IV   │ ciphertext│ GCM tag │
              │ (0x02) │16 bytes│  N bytes  │ 16 bytes│
              └────────┴───────┴───────────┴─────────┘
```

**Draft encryption in `StorageService`:**
```dart
Future<void> saveDraft(String draftId, String draftData) async {
  final encrypted = await EncryptionService().encrypt(draftData);
  await _draftStorage.write(key: 'draft_$draftId', value: encrypted);

  final existingDrafts = await getAllDraftIds();
  if (!existingDrafts.contains(draftId)) {
    existingDrafts.add(draftId);
    await _draftStorage.write(
      key: '_draft_keys_',
      value: jsonEncode(existingDrafts),  // JSON, not comma-join
    );
  }
}

Future<String?> getDraft(String draftId) async {
  final raw = await _draftStorage.read(key: 'draft_$draftId');
  if (raw == null) return null;
  return EncryptionService().decrypt(raw);
}

Future<List<String>> getAllDraftIds() async {
  final json = await _draftStorage.read(key: '_draft_keys_');
  if (json == null || json.isEmpty) return [];
  try {
    return (jsonDecode(json) as List).cast<String>();
  } catch (_) {
    return [];
  }
}
```

---

### R3 — SecurityService: Lockout Persistence

**Problem:** `initialize()` calls `_resetAttempts()`, wiping the lockout on every app start. The biometric success path in `LockScreen` also calls `initialize()`.

**Solution:** Remove `_resetAttempts()` from `initialize()`. Remove the `initialize()` call from the biometric success path.


**Updated `initialize()`:**
```dart
Future<void> initialize() async {
  // Only create the PIN hash salt if it doesn't exist yet.
  // NEVER reset attempt state here — lockout must survive restarts.
  final salt = await _storage.read(key: _saltKey);
  if (salt == null) {
    await _storage.write(key: _saltKey, value: _generateSalt());
  }
  // Do NOT call _resetAttempts() here.
}
```

**In `LockScreen._authenticateBiometric()` — remove the `initialize()` call:**
```dart
// BEFORE (buggy):
if (didAuthenticate) {
  await _securityService.initialize(); // ← removes lockout!
  widget.onUnlock();
}

// AFTER (correct):
if (didAuthenticate) {
  widget.onUnlock(); // initialize() is NOT called here
}
```

---

### R4 — ObjectBoxService: Database Migration Safety

**Problem:** On `openStore()` failure, the service immediately deletes the database without user consent and without creating a backup.

**Solution:** Use an `InitResult` enum returned from `init()`. `RootOrchestrator` handles the dialog. The database is only deleted after explicit user consent.

**`InitResult` enum:**
```dart
enum InitResult { success, migrationRequired, fatalError }

class ObjectBoxInitOutcome {
  final InitResult result;
  final String? backupPath;
  final String? errorMessage;
  const ObjectBoxInitOutcome(this.result, {this.backupPath, this.errorMessage});
}
```

**Updated `ObjectBoxService.init()`:**
```dart
static Future<ObjectBoxInitOutcome> init() async {
  if (_instance != null) return const ObjectBoxInitOutcome(InitResult.success);

  final dir    = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}/objectbox';

  try {
    final store = await openStore(directory: dbPath);
    _instance = ObjectBoxService._()..store = store;
    await _seedDefaultsIfNeeded(); // R14
    return const ObjectBoxInitOutcome(InitResult.success);
  } catch (e, st) {
    debugPrint('ObjectBox init failed: $e\n$st');

    // Attempt backup before any destructive action
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${dir.path}/objectbox_backup_$timestamp';
    try {
      await Directory(dbPath).rename(backupPath);
    } catch (backupErr) {
      debugPrint('Backup failed: $backupErr');
      return ObjectBoxInitOutcome(
        InitResult.fatalError,
        errorMessage: 'Could not back up database: $backupErr',
      );
    }

    return ObjectBoxInitOutcome(
      InitResult.migrationRequired,
      backupPath: backupPath,
    );
  }
}

/// Called by RootOrchestrator after user grants consent.
static Future<void> reinitializeAfterConsent(String backupPath) async {
  // backupPath already moved away; just open a fresh store
  final dir    = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}/objectbox';
  final store  = await openStore(directory: dbPath);
  _instance = ObjectBoxService._()..store = store;
  await _seedDefaultsIfNeeded();
}
```

**`RootOrchestrator` handles the dialog:**
```dart
// In main():
final outcome = await ObjectBoxService.init();
if (outcome.result == InitResult.migrationRequired) {
  // Show dialog — handled inside RootOrchestrator via initError + outcome
}
```

**Migration dialog flow:**
```
openStore() throws
       │
       ▼
  rename DB → backup_<timestamp>
       │
       ▼
  return InitResult.migrationRequired
       │
       ▼
  RootOrchestrator shows AlertDialog
  "Database schema changed. Your data has been backed up to:
   <backupPath>. Tap OK to start fresh."
       │
  ┌────┴────┐
  │ OK      │ Cancel
  ▼         ▼
reinitialize  surface error,
after consent keep backup
```

---

### R5 — RootOrchestrator: Re-authentication on App Resume

**Problem:** `_RootOrchestratorState` does not implement `WidgetsBindingObserver`, so the app never locks when returning from background.

**Solution:** Mix in `WidgetsBindingObserver`, record background timestamp on `paused`, and lock on `resumed` if elapsed time exceeds the grace period.


**Updated `_RootOrchestratorState`:**
```dart
class _RootOrchestratorState extends ConsumerState<RootOrchestrator>
    with WidgetsBindingObserver {

  static const _gracePeriod = Duration(seconds: 30);

  bool isAuthenticated = false;
  bool isLoading = true;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null && DateTime.now().difference(bg) > _gracePeriod) {
        setState(() => isAuthenticated = false);
      }
    }
  }
  // ... rest unchanged
}
```

**Lifecycle state diagram:**
```
App foreground (isAuthenticated=true)
        │
        │ user presses home / switches app
        ▼
AppLifecycleState.paused
  _backgroundedAt = DateTime.now()
        │
        │ user returns to app
        ▼
AppLifecycleState.resumed
  elapsed = now - _backgroundedAt
        │
  ┌─────┴──────┐
  elapsed > 30s  elapsed ≤ 30s
        │              │
        ▼              ▼
  isAuthenticated=false  no change
  → LockScreen shown     → stays authenticated
```

---

### R6 — ForgotPinScreen: Biometric Authentication Before PIN Reset

**Problem:** `_resetViaBiometric()` immediately sets `_pinStep = 1` without calling `LocalAuthentication.authenticate()`. The biometric check happens later in `_completeReset()`, which also re-authenticates (double prompt).

**Solution:** Move the biometric call into `_resetViaBiometric()`. Add `SecurityService.resetPinDirectly()` to avoid a second biometric prompt in `_completeReset()`.

**New `SecurityService.resetPinDirectly()`:**
```dart
/// Reset PIN without biometric re-authentication.
/// Caller is responsible for having already authenticated the user.
Future<PinVerificationResult> resetPinDirectly(String newPin) async {
  if (!_isValidPin(newPin)) {
    return PinVerificationResult(success: false, error: 'Invalid PIN format');
  }
  await _storage.delete(key: _pinHashKey);
  final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
  final hash = await _hashPin(newPin, salt);
  await _storage.write(key: _pinHashKey, value: hash);
  await _resetAttempts();
  return PinVerificationResult(success: true);
}
```

**Updated `_resetViaBiometric()` in `ForgotPinScreen`:**
```dart
Future<void> _resetViaBiometric() async {
  setState(() { _isLoading = true; _errorMessage = null; });

  try {
    final available = await _securityService.isBiometricAvailable();
    if (!available) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Biometric authentication not available on this device';
      });
      return;
    }

    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Authenticate to reset your PIN',
    );

    if (didAuthenticate) {
      setState(() { _isLoading = false; _pinStep = 1; }); // advance only on success
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Biometric authentication cancelled';
        // _pinStep remains 0
      });
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Biometric error: ${e.toString()}';
    });
  }
}
```

**Updated `_completeReset()` — biometric path uses `resetPinDirectly`:**
```dart
if (_resetMethod == 1) {
  // Biometric already verified in _resetViaBiometric() — no second prompt
  result = await _securityService.resetPinDirectly(_newPin);
} else {
  final answers = _answerControllers.map((c) => c.text.trim()).toList();
  result = await _securityService.resetPinViaSecurityQuestions(answers, _newPin);
}
```

---

### R7 — MainShell: Screen State Preservation

**Problem:** `_screens` is a `final` field initialized inline in the class body, but `AnimatedSwitcher` + `KeyedSubtree` destroys and recreates the inactive screen widget on every tab switch.

**Solution:** Move `_screens` to `late final` initialized in `initState()`, and replace `AnimatedSwitcher` + `KeyedSubtree` with `IndexedStack`.


**Updated `_MainShellState`:**
```dart
class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _bgCtrl;
  late final List<Widget> _screens; // late final — initialized once in initState

  @override
  void initState() {
    super.initState();
    _screens = const [
      JournalScreen(),
      CalendarScreen(),
      IdentityScreen(),
      ProfileScreen(),
    ];
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }
  // ...
}
```

**Replace `AnimatedSwitcher` + `KeyedSubtree` with `IndexedStack`:**
```dart
// BEFORE:
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: KeyedSubtree(key: ValueKey(_idx), child: _screens[_idx]),
),

// AFTER:
IndexedStack(
  index: _idx,
  children: _screens,
),
```

`IndexedStack` keeps all children in the widget tree at all times. Only the child at `index` is visible. Scroll positions, form state, and loaded data are all preserved across tab switches.

---

### R8 — GlassContainer: Rendering Performance

**Problem:** Every `GlassContainer` instance wraps its content in `BackdropFilter(ImageFilter.blur(...))`. On a screen with 10+ cards, this creates 10+ GPU compositing layers, causing frame drops on mid-range devices.

**Solution:** Remove `BackdropFilter` from `GlassContainer`'s default path. Simulate the frosted-glass look with a semi-transparent gradient. Add a `useBackdropFilter` parameter for the one nav bar use case.

**Updated `GlassContainer`:**
```dart
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final EdgeInsets padding;
  final Border? border;
  final Gradient? gradient;
  final bool useBackdropFilter; // NEW — false by default

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 12,
    this.opacity = 0.05,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.border,
    this.gradient,
    this.useBackdropFilter = false, // default: no GPU compositing
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(
          color: Colors.white.withValues(alpha: 0.1), width: 1,
        ),
        gradient: gradient ?? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: child,
    );

    if (!useBackdropFilter) return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: container,
    );

    // Only used for the nav bar
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: container,
      ),
    );
  }
}
```

**Nav bar in `MainShell` — single `BackdropFilter`:**
```dart
GlassContainer(
  useBackdropFilter: true, // only here
  borderRadius: 32,
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Row(...),
),
```

---

### R9 — StorageService: Query Resource Management

**Problem:** Several `StorageService` methods call `query.build()` and `query.find()` / `query.findFirst()` without a `try/finally` block. If `find()` throws, the native query object leaks.

**Solution:** Wrap every query in `try/finally { query.close(); }`.

**Pattern to apply to all 11 methods:**
```dart
// BEFORE:
final query = _box.query(...).build();
final result = query.find();
query.close();
return result;

// AFTER:
final query = _box.query(...).build();
try {
  return query.find();
} finally {
  query.close();
}
```

**Methods requiring this fix:**
`getJournal()`, `saveJournalEntry()`, `deleteJournalEntry()`, `getJournalEntryById()`, `getFavoriteRankings()`, `addRankingCategory()`, `deleteRankingCategory()`, `updateRankingCategory()`, `addRankedItem()`, `deleteRankedItem()`, `reorderRankedItems()`

Note: `getRankings()` uses `_rankingBox.getAll()` (no query object) — no change needed there.

---

### R10 — ProfileScreen: Accurate Cognitive Metrics

**Problem:** The streak is hardcoded as `"12"`. The "Clarity" card shows `"87%"` with no real formula.

**Solution:** Add `StorageService.computeStreak()` as a pure function. Remove the "Clarity" card.


**New pure function in `StorageService`:**
```dart
/// Compute the current journaling streak.
///
/// Returns the number of consecutive calendar days ending on today
/// (or the most recent entry date) on which at least one entry exists.
/// Returns 0 if [entries] is empty.
static int computeStreak(List<JournalEntry> entries) {
  if (entries.isEmpty) return 0;

  // Extract unique calendar dates (date only, no time)
  final dates = entries
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // descending

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  int streak = 0;
  DateTime expected = todayDate;

  // If the most recent entry is not today or yesterday, streak is 0
  if (dates.first.isBefore(expected.subtract(const Duration(days: 1)))) {
    return 0;
  }

  for (final date in dates) {
    if (date == expected) {
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    } else if (date.isBefore(expected)) {
      break; // gap found
    }
    // date > expected means duplicate date (already counted via toSet)
  }

  return streak;
}
```

**Updated `_ProfileScreenState._load()`:**
```dart
Future<void> _load() async {
  final s = ref.read(storageServiceProvider).getSettings();
  final j = await ref.read(storageServiceProvider).getJournal();
  setState(() {
    settings = s;
    totalMemories = j.length;
    _streak = StorageService.computeStreak(j); // computed, not hardcoded
  });
}
```

**Add `_streak` field and update the stat card:**
```dart
int _streak = 0;

// In build():
_statCard("Streak",
  _streak == 0 ? "—" : "$_streak",
  Icons.local_fire_department,
  AppColors.emerald500,
),
// Remove the "Clarity" _statCard entirely
```

---

### R11 — StorageService: Asynchronous Decryption Off the UI Thread

**Problem:** `getJournal()` calls `Future.wait(results.map((e) => e.toFreezed()))`, which runs decryption on the main thread for each entry sequentially.

**Solution:** Batch all raw entries into a single `compute()` isolate call. The isolate receives serialized maps, decrypts all fields, and returns decrypted maps. The main thread reconstructs `JournalEntry` objects.

**Isolate function (top-level):**
```dart
// Top-level — must be outside any class for compute()
List<Map<String, dynamic>> _batchDecryptEntries(
    List<Map<String, dynamic>> rawMaps) {
  // Each map contains raw (possibly encrypted) field values.
  // Decryption logic (formerly in _maybeDecrypt) runs here.
  return rawMaps.map((raw) {
    return {
      ...raw,
      'headline': _maybeDecryptField(raw['headline'] as String?),
      'content':  _maybeDecryptField(raw['content']  as String?),
      'feeling':  _maybeDecryptField(raw['feeling']  as String?),
    };
  }).toList();
}

String? _maybeDecryptField(String? value) {
  if (value == null || value.isEmpty) return value;
  // Inline decryption logic (sync, using cached key)
  // ... (moved from ObjectBoxJournalEntry.toFreezed())
  return value;
}
```

**Updated `StorageService.getJournal()`:**
```dart
Future<List<JournalEntry>> getJournal() async {
  final query = _journalBox
      .query()
      .order(ObjectBoxJournalEntry_.date, flags: Order.descending)
      .build();
  final List<ObjectBoxJournalEntry> results;
  try {
    results = query.find();
  } finally {
    query.close();
  }

  // Serialize raw fields for the isolate
  final rawMaps = results.map((e) => e.toRawMap()).toList();

  // Batch decrypt in a single isolate call
  final decryptedMaps = await compute(_batchDecryptEntries, rawMaps);

  // Reconstruct JournalEntry objects on the main thread
  return [
    for (int i = 0; i < results.length; i++)
      results[i].toFreezedFromDecrypted(decryptedMaps[i]),
  ];
}
```

**New methods on `ObjectBoxJournalEntry`:**
- `toRawMap()` — serializes all fields to a `Map<String, dynamic>` without decryption
- `toFreezedFromDecrypted(Map<String, dynamic>)` — constructs a `JournalEntry` from pre-decrypted fields

---

### R12 — ImageThumbnailWidget: State Management

**Problem:** `_isLoading` and `_hasError` are assigned directly outside `setState()` in `_buildGalleryImage()`, `_buildUrlImage()`, and `_buildFileImage()`. This causes illegal `setState` calls during build.

**Solution:** Remove `_isLoading` and `_hasError` instance variables. Derive loading and error states entirely from widget callback parameters.


**Updated `_ImageThumbnailWidgetState`:**
```dart
class _ImageThumbnailWidgetState extends State<ImageThumbnailWidget> {
  // _isLoading and _hasError REMOVED

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.showTapToZoom ? () => _openFullscreen(context) : null,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              if (widget.onDelete != null) _buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryImage() {
    return FutureBuilder<Uint8List?>(
      future: _loadGalleryThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.indigo500,
          ));
        }
        if (snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: widget.fit,
              gaplessPlayback: true);
        }
        return const Center(child: Icon(Icons.broken_image,
            color: AppColors.slate400, size: 40));
      },
    );
    // No setState() calls inside the builder
  }

  Widget _buildUrlImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageRef.source,
      fit: widget.fit,
      placeholder: (ctx, url) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2,
            color: AppColors.indigo500),
      ),
      errorWidget: (ctx, url, err) => const Center(
        child: Icon(Icons.broken_image, color: AppColors.slate400, size: 40),
      ),
      fadeInDuration: const Duration(milliseconds: 200),
    );
    // No _hasError references
  }

  Widget _buildFileImage() {
    return Image.file(
      File(widget.imageRef.source),
      fit: widget.fit,
      errorBuilder: (ctx, err, st) => const Center(
        child: Icon(Icons.broken_image, color: AppColors.slate400, size: 40),
      ),
    );
    // No _hasError references
  }
}
```

---

### R13 — Global Flutter Error Boundary

**Problem:** `main()` has no global error handlers. Unhandled Flutter framework errors and platform errors fail silently in release builds.

**Solution:** Set `FlutterError.onError` and `PlatformDispatcher.instance.onError` before `runApp()`.

**Updated `main()`:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error boundary — must be set before runApp()
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // default Flutter error rendering
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    // TODO: forward to crash reporting (e.g. Firebase Crashlytics) in release
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformError: $error\n$stack');
    // TODO: forward to crash reporting in release
    return true; // returning true prevents the default crash
  };

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  String? initError;
  try {
    await ObjectBoxService.init();
    await SecurityService().initialize();
  } catch (e, st) {
    debugPrint('Critical init failed: $e\n$st');
    initError = e.toString();
  }

  runApp(ProviderScope(child: MemoryPalaceApp(initError: initError)));
}
```

---

### R14 — ObjectBoxService: Rankings Seeding Race Condition Prevention

**Problem:** `StorageService.getRankings()` seeds default categories on every call when the box is empty. If called concurrently, this can insert duplicates and trigger unique-constraint violations.

**Solution:** Move seeding to `ObjectBoxService.init()`, which runs once at startup. Remove seeding from `StorageService.getRankings()`.


**New `_seedDefaultsIfNeeded()` in `ObjectBoxService`:**
```dart
static const List<Map<String, String>> _defaultCategoryDefs = [
  {'id': 'movies',      'title': 'Movies',      'iconName': 'movie'},
  {'id': 'restaurants', 'title': 'Restaurants', 'iconName': 'restaurant'},
  {'id': 'places',      'title': 'Places',      'iconName': 'place'},
  {'id': 'people',      'title': 'People',      'iconName': 'person'},
  {'id': 'books',       'title': 'Books',       'iconName': 'book'},
];

static Future<void> _seedDefaultsIfNeeded() async {
  final box = _instance!.store.box<ObjectBoxRankingCategory>();
  if (box.count() > 0) return; // already seeded

  for (final def in _defaultCategoryDefs) {
    final cat = ObjectBoxRankingCategory()
      ..categoryId = def['id']!
      ..title      = def['title']!
      ..iconName   = def['iconName']!
      ..isFavorite = false
      ..itemsJson  = '[]';
    box.put(cat);
  }
}
```

**Updated `StorageService.getRankings()` — seeding removed:**
```dart
Future<List<RankingCategory>> getRankings() async {
  // Seeding is now handled by ObjectBoxService.init() — do NOT seed here.
  final results = _rankingBox.getAll();
  return results.map((c) => c.toFreezed()).toList();
}
```

---

### R15 — BackupService: Import Validation and Bounds Checking

**Problem:** `_deserializeEntry()` uses direct array index access (`EntryType.values[data['type'] as int]`) with no bounds check. A crafted backup with `"type": 999` throws a `RangeError`. There is no entry count limit or string length limit.

**Solution:** Add a `_safeEnumValue<T>()` helper, a 10,000-entry limit, and a 10,000-character string truncation.

**New helper in `BackupService`:**
```dart
/// Safely access an enum value by index, throwing [FormatException] on out-of-range.
T _safeEnumValue<T>(List<T> values, int? index, String fieldName) {
  if (index == null) {
    throw FormatException('Missing required field: $fieldName');
  }
  if (index < 0 || index >= values.length) {
    throw FormatException(
      'Invalid $fieldName index $index: must be in [0, ${values.length - 1}]',
    );
  }
  return values[index];
}

/// Truncate a string to [maxLength] characters.
String? _truncate(String? value, {int maxLength = 10000}) {
  if (value == null) return null;
  return value.length > maxLength ? value.substring(0, maxLength) : value;
}
```

**Updated `importFromJson()` — entry count limit:**
```dart
Future<BackupResult> importFromJson(String jsonString, {bool merge = true}) async {
  try {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    if (!data.containsKey('version') || !data.containsKey('journal')) {
      return BackupResult(success: false, error: 'Invalid backup file format');
    }

    final journalList = data['journal'] as List;

    // Entry count limit
    if (journalList.length > 10000) {
      return BackupResult(
        success: false,
        error: 'Backup contains ${journalList.length} entries; maximum is 10,000',
      );
    }
    // ... rest of import logic unchanged
  }
}
```

**Updated `_deserializeEntry()` — bounds-checked enum access and string truncation:**
```dart
JournalEntry _deserializeEntry(Map<String, dynamic> data) {
  return JournalEntry(
    id:       data['id'] as String,
    type:     _safeEnumValue(EntryType.values, data['type'] as int?, 'type'),
    date:     DateTime.parse(data['date'] as String),
    headline: _truncate(data['headline'] as String?) ?? '',
    content:  _truncate(data['content']  as String?) ?? '',
    mood:     _safeEnumValue(Mood.values, data['mood'] as int?, 'mood'),
    feeling:  _truncate(data['feeling']  as String?),
    tags:     (data['tags'] as List?)?.map((e) => e as String).toList() ?? [],
    location: data['location'] != null
        ? LocationData.fromJson(data['location'] as Map<String, dynamic>)
        : null,
    timeBucket: data['timeBucket'] != null
        ? _safeEnumValue(TimeBucket.values, data['timeBucket'] as int, 'timeBucket')
        : null,
    images:      _parseBackupImages(data['images'] as List?),
    isSpotlight: data['isSpotlight'] as bool? ?? false,
  );
}
```

---

## Data Models

No new data models are introduced. The following existing models are modified:

### `PinVerificationResult` — add `requiresPinReset` field

```dart
class PinVerificationResult {
  final bool success;
  final String? error;
  final int? remainingAttempts;
  final int? remainingLockoutSeconds;
  final bool requiresPinReset; // NEW — signals old hash format detected

  PinVerificationResult({
    required this.success,
    this.error,
    this.remainingAttempts,
    this.remainingLockoutSeconds,
    this.requiresPinReset = false,
  });
}
```

### `ObjectBoxInitOutcome` — new class

```dart
enum InitResult { success, migrationRequired, fatalError }

class ObjectBoxInitOutcome {
  final InitResult result;
  final String? backupPath;   // set when result == migrationRequired
  final String? errorMessage; // set when result == fatalError
  const ObjectBoxInitOutcome(this.result, {this.backupPath, this.errorMessage});
}
```

### `ObjectBoxJournalEntry` — two new methods

| Method | Signature | Purpose |
|---|---|---|
| `toRawMap` | `Map<String, dynamic> toRawMap()` | Serialize all fields without decryption for isolate dispatch |
| `toFreezedFromDecrypted` | `JournalEntry toFreezedFromDecrypted(Map<String, dynamic> decrypted)` | Reconstruct `JournalEntry` from pre-decrypted field map |

### `StorageService` — one new static method

| Method | Signature | Purpose |
|---|---|---|
| `computeStreak` | `static int computeStreak(List<JournalEntry> entries)` | Pure function: count consecutive journaling days |

### `SecurityService` — one new method, one new constant

| Addition | Type | Purpose |
|---|---|---|
| `resetPinDirectly(String newPin)` | `Future<PinVerificationResult>` | Reset PIN without biometric re-prompt |
| `_encryptionSaltKey` | `static const String` | Separate secure storage key for encryption salt |

---

## Correctness Properties

These are the executable invariants that property-based tests must verify. Each maps to a requirement.

### Property 1: PBKDF2 Determinism (R1)

For all valid PIN strings and salt strings, `SecurityService._hashPin(pin, salt)` called twice with the same inputs SHALL return the same output. Formally: `∀ pin, salt: hash(pin, salt) == hash(pin, salt)`.

**Validates: Requirements 1.3**

### Property 2: PBKDF2 Collision Resistance (R1)

For all pairs of distinct PIN strings with the same salt, `SecurityService._hashPin` SHALL return distinct outputs. Formally: `∀ pin1 ≠ pin2, salt: hash(pin1, salt) ≠ hash(pin2, salt)`.

**Validates: Requirements 1.4**

### Property 3: PBKDF2 Output Length (R1)

For all valid PIN and salt inputs, the raw key bytes returned by `_pbkdf2Derive` SHALL be exactly 32 bytes. Formally: `∀ pin, salt: len(pbkdf2Derive(pin, salt, 100000, 32)) == 32`.

**Validates: Requirements 1.5**

### Property 4: Encryption Round-Trip (R2)

For all non-empty plaintext strings, decrypting the output of encrypting that string SHALL return the original plaintext. Formally: `∀ plaintext ≠ "": decrypt(encrypt(plaintext)) == plaintext`.

**Validates: Requirements 2.6**

### Property 5: Encryption Confidentiality (R2)

For all non-empty plaintext strings, the ciphertext produced by `EncryptionService.encrypt` SHALL differ from the plaintext. Formally: `∀ plaintext ≠ "": encrypt(plaintext) ≠ plaintext`.

**Validates: Requirements 2.7**

### Property 6: Lockout Persistence (R3)

For all N in [1, 5] and all M ≥ 1, after N failed PIN attempts followed by M calls to `SecurityService.initialize()`, the remaining-attempts count SHALL equal `5 - N`. Formally: `∀ N ∈ [1,5], M ≥ 1: remainingAttempts_after_N_fails_and_M_restarts == 5 - N`.

**Validates: Requirements 3.4**

### Property 7: Streak Order-Independence (R10)

For all lists of journal entries, `StorageService.computeStreak` SHALL return the same value regardless of the order of entries in the input list. Formally: `∀ entries: computeStreak(entries) == computeStreak(shuffle(entries))`.

**Validates: Requirements 10.6**

### Property 8: Streak Correctness (R10)

For all lists of journal entry dates, `StorageService.computeStreak` SHALL return the length of the longest suffix of consecutive calendar days ending on or before today that contains at least one entry per day.

**Validates: Requirements 10.5**

### Property 9: Decryption Equivalence (R11)

For all lists of journal entries, the result of isolate-based batch decryption via `_batchDecryptEntries` SHALL be identical to the result of sequential inline decryption for every entry. Formally: `∀ entries: isolate_decrypt(entries) == inline_decrypt(entries)`.

**Validates: Requirements 11.3**

### Property 10: Draft ID Set Membership (R2)

For all sets of draft IDs, calling `StorageService.getAllDraftIds()` after saving those drafts SHALL return a list containing exactly those IDs with no duplicates. Formally: `∀ draftIds: getAllDraftIds_after_saving(draftIds) == Set(draftIds)`.

**Validates: Requirements 2.11**

### Property 11: Seeding Concurrency Safety (R14)

For all N in [2, 10], N concurrent calls to the rankings seeding logic on an empty box SHALL result in exactly the 5 default categories with no duplicate `categoryId` values. Formally: `∀ N ∈ [2,10]: concurrent_seed(N) → |categories| == 5 ∧ no_duplicate_ids`.

**Validates: Requirements 14.4**

### Property 12: Import Bounds Safety (R15)

For all integer values outside the valid enum range for `type`, `mood`, or `timeBucket`, `BackupService._deserializeEntry` SHALL throw a `FormatException` rather than a `RangeError`. Formally: `∀ index ∉ valid_range: _safeEnumValue(index) throws FormatException`.

**Validates: Requirements 15.7**

### Property 13: Valid-Input Acceptance (R15)

For all import payloads containing between 1 and 10,000 entries with valid field values, `BackupService.importFromJson` SHALL successfully import all entries without throwing an exception. Formally: `∀ payload with 1 ≤ |entries| ≤ 10000 ∧ all_fields_valid: importFromJson(payload).success == true`.

**Validates: Requirements 15.8**

---

## Error Handling

### Encryption key unavailable (`StateError`)

**Trigger:** `EncryptionService.encrypt()` or `EncryptionService.decrypt()` called before PIN verification.  
**Handler:** `_getDerivedKey()` throws `StateError('Encryption key not available: PIN not verified')`.  
**Propagation:** Callers (`saveDraft`, `exportToFile`) catch and surface a user-facing error message. The app does not fall back to plaintext.

### GCM tag verification failure (`FormatException`)

**Trigger:** Ciphertext tampered with, or decrypted with wrong key.  
**Handler:** `_decryptAes()` throws `FormatException('GCM tag verification failed: ...')`.  
**Propagation:** `BackupService.importEncryptedFile()` catches and returns `BackupResult(success: false, error: ...)`. The app does not import corrupted data.

### Database migration failure (`ObjectBoxInitOutcome.fatalError`)

**Trigger:** `openStore()` throws AND the database directory cannot be renamed to a backup path.  
**Handler:** `ObjectBoxService.init()` returns `ObjectBoxInitOutcome(InitResult.fatalError, errorMessage: ...)`.  
**Propagation:** `main()` passes the error to `MemoryPalaceApp`, which renders `_ErrorScreen` with a retry button.

### Database migration — user denies consent

**Trigger:** `openStore()` throws, backup succeeds, user taps "Cancel" in the recovery dialog.  
**Handler:** `RootOrchestrator` does NOT call `reinitializeAfterConsent()`. The backup directory is preserved.  
**Propagation:** `_ErrorScreen` is shown with a message explaining the situation.

### Import bounds violation (`FormatException`)

**Trigger:** Backup file contains an out-of-range enum index or more than 10,000 entries.  
**Handler:** `_safeEnumValue()` throws `FormatException`. `importFromJson()` catches per-entry and increments `skippedEntries`.  
**Propagation:** `BackupResult` is returned with `success: true` (partial import) and a message listing skipped entries.

### Biometric authentication failure

**Trigger:** `LocalAuthentication.authenticate()` returns `false` or throws.  
**Handler:** `ForgotPinScreen._resetViaBiometric()` catches, sets `_errorMessage`, resets `_isLoading`, and does NOT advance `_pinStep`.  
**Propagation:** Error message displayed inline. User can retry or switch to security questions.

### Old PIN hash format detected

**Trigger:** `verifyPin()` reads a 64-char hex hash (pre-hardening format).  
**Handler:** `SecurityService.verifyPin()` deletes the old hash and returns `PinVerificationResult(success: false, requiresPinReset: true)`.  
**Propagation:** `LockScreen` detects `requiresPinReset: true` and navigates to `PinSetupScreen` with a message explaining the security upgrade.

---

## Testing Strategy

### Unit Tests

All unit tests use `flutter_test` with mocked dependencies via `mockito` or manual fakes.

| Test File | Covers |
|---|---|
| `test/security_service_test.dart` | R1 (PBKDF2 correctness, P1–P3), R3 (lockout persistence, P6), R6 (biometric flow) |
| `test/encryption_service_test.dart` | R2 (AES-GCM round-trip P4, confidentiality P5, GCM tag rejection) |
| `test/storage_service_test.dart` | R2 (draft encryption), R9 (query close on exception), R10 (streak P7–P8), R11 (batch decrypt P9), R14 (seeding idempotence P11) |
| `test/backup_service_test.dart` | R15 (bounds checking P12–P13, entry limit, string truncation) |
| `test/objectbox_service_test.dart` | R4 (migration safety), R14 (seeding race condition) |

**Key unit test scenarios:**

```
security_service_test.dart
  ✓ PBKDF2 hash is deterministic for same pin+salt
  ✓ PBKDF2 hash differs for different pins
  ✓ PBKDF2 output is exactly 32 bytes
  ✓ Encryption salt is independent from PIN hash salt
  ✓ initialize() does NOT reset attempt counter
  ✓ initialize() does NOT clear lockout timestamp
  ✓ verifyPin() resets attempts on success
  ✓ 5 failed attempts triggers lockout
  ✓ Lockout survives N calls to initialize()
  ✓ Old 64-char hash triggers requiresPinReset
  ✓ resetPinDirectly() sets new hash without biometric prompt

encryption_service_test.dart
  ✓ encrypt(plaintext) → decrypt → original plaintext (round-trip)
  ✓ encrypt(plaintext) ≠ plaintext (confidentiality)
  ✓ Two encryptions of same plaintext produce different ciphertexts (random IV)
  ✓ Tampered ciphertext throws FormatException on decrypt
  ✓ _getDerivedKey() throws StateError when key is null
  ✓ AES mode is GCM (not CBC)

storage_service_test.dart
  ✓ saveDraft stores encrypted content (not plaintext JSON)
  ✓ getDraft decrypts and returns original content
  ✓ getAllDraftIds uses JSON encoding (not comma-join)
  ✓ Saving 3 drafts, deleting middle → getAllDraftIds returns 2 IDs
  ✓ query.close() called even when find() throws
  ✓ computeStreak([]) == 0
  ✓ computeStreak(entries_today_only) == 1
  ✓ computeStreak(entries_7_consecutive_days) == 7
  ✓ computeStreak(gap_yesterday) == 0
  ✓ computeStreak is order-independent (P7)
  ✓ Batch isolate decrypt == inline decrypt for all entries (P9)

backup_service_test.dart
  ✓ type=999 throws FormatException (not RangeError)
  ✓ mood=999 throws FormatException
  ✓ timeBucket=999 throws FormatException
  ✓ 10,001 entries → BackupResult(success: false)
  ✓ headline > 10,000 chars → truncated to 10,000
  ✓ 10,000 valid entries → all imported successfully (P13)
  ✓ Partial import: valid entries imported, invalid entries skipped

objectbox_service_test.dart
  ✓ openStore() failure → database renamed to backup path
  ✓ openStore() failure → InitResult.migrationRequired returned
  ✓ Database NOT deleted without reinitializeAfterConsent()
  ✓ _seedDefaultsIfNeeded() called exactly once on init
  ✓ _seedDefaultsIfNeeded() is idempotent (calling twice = same result)
```

### Widget Tests

```
test/widget/root_orchestrator_test.dart
  ✓ Security enabled → LockScreen shown on cold start
  ✓ Security disabled → MainShell shown directly
  ✓ AppLifecycleState.paused then resumed after >30s → LockScreen shown
  ✓ AppLifecycleState.paused then resumed within 30s → MainShell stays
  ✓ WidgetsBindingObserver registered in initState, removed in dispose

test/widget/main_shell_test.dart
  ✓ Tab switch does NOT call initState on already-visited screens (IndexedStack)
  ✓ Scroll position preserved after tab switch and return
  ✓ _screens list initialized exactly once (not on setState)
  ✓ Only one BackdropFilter in the widget tree (nav bar only)

test/widget/forgot_pin_screen_test.dart
  ✓ Biometric method selected, auth fails → _pinStep remains 0
  ✓ Biometric method selected, auth cancelled → error message shown
  ✓ Biometric method selected, auth succeeds → _pinStep advances to 1
  ✓ _isLoading reset to false on all biometric outcomes
  ✓ No second biometric prompt in _completeReset()

test/widget/image_thumbnail_widget_test.dart
  ✓ Gallery image: loading spinner shown while future pending
  ✓ Gallery image: image shown after future resolves
  ✓ Gallery image: error icon shown on null result
  ✓ URL image: placeholder shown while loading
  ✓ URL image: error icon shown on network error
  ✓ File image: error icon shown on missing file
  ✓ No setState-during-build assertion errors in debug mode

test/widget/profile_screen_test.dart
  ✓ Streak card shows "—" when no entries
  ✓ Streak card shows computed value (not "12")
  ✓ "Clarity" card is absent from the widget tree
  ✓ Streak updates after journal entries are loaded
```

### Integration / E2E Tests

```
test/integration/pin_security_test.dart
  ✓ Enter wrong PIN 5 times → lockout message shown
  ✓ Force-kill app, relaunch → lockout still active
  ✓ Wait for lockout to expire → PIN entry re-enabled
  ✓ Correct PIN after lockout expires → unlocks successfully
  ✓ Background app >30s → lock screen shown on resume
  ✓ Background app <30s → no lock screen on resume

test/integration/backup_restore_test.dart
  ✓ Export encrypted backup → file created with .encrypted extension
  ✓ Import encrypted backup → all entries restored
  ✓ Import tampered encrypted backup → FormatException, no data corruption
  ✓ Import backup with out-of-range enum → partial import, skipped entries reported
  ✓ Export unencrypted backup → readable JSON file created

test/integration/database_migration_test.dart
  ✓ Schema mismatch → recovery dialog shown
  ✓ User taps OK → fresh database initialized, app usable
  ✓ User taps Cancel → backup preserved, error screen shown
  ✓ Backup file exists at expected path after migration failure

test/integration/journal_load_performance_test.dart
  ✓ Load 500 entries → completes in < 500ms (isolate batch decrypt)
  ✓ Load 1,000 entries → UI thread not blocked (frame time < 16ms during load)
```
