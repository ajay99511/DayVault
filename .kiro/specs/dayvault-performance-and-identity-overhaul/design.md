# Design Document — DayVault Performance and Identity Overhaul

## Overview

This document describes the technical design for the DayVault Performance and Identity Overhaul. The goals map to ten problem categories identified in the requirements:

1. **Profile Screen** — Replace device diagnostics with meaningful journaling statistics via a new `StatsProvider` Riverpod provider.
2. **Rendering performance** — Isolate `BackdropFilter` GPU cost behind `RepaintBoundary`; pause background animation when app is backgrounded or the lock screen is idle.
3. **Data layer performance** — Introduce cursor-based pagination for the journal list; move encryption/decryption off the UI thread; pre-compute the Calendar date→entries map.
4. **State management** — Debounce search queries; decompose `EntryEditor` into independently stateful sub-widgets; isolate auth state into a narrow `StateProvider`.
5. **Resource leaks** — Remove `TabController` listener in `IdentityScreen`; dispose `PageController` in `CalendarScreen`; delete orphaned image files on entry delete; move backup I/O off the main isolate with staged progress.
6. **Security hardening** — Rotate both salts plus re-encrypt all entries atomically on PIN change; exponential backoff with a persisted cycle counter; parallelize independent `FlutterSecureStorage` reads.
7. **Backup image serialization fix** — Correctly serialize `ImageReference` objects in `_serializeEntry`.
8. **Username profile management** — Editable username field in ProfileScreen.
9. **Backup restore UI** — Restore button in the Manage Backups sheet.
10. **Spotlight and tag filtering** — Spotlight toggle in EntryEditor; tag and spotlight filters in JournalScreen.

All existing functionality (journal, calendar, rankings, security, backup) continues to work unchanged from the user's perspective.

---

## Architecture

### High-Level Component Diagram

```mermaid
graph TD
  subgraph UI Layer
    Root[RootOrchestrator]
    Lock[LockScreen]
    Shell[MainShell]
    JS[JournalScreen]
    CS[CalendarScreen]
    IS[IdentityScreen]
    PS[ProfileScreen]
    EE[EntryEditor\nMoodSelector · TagPicker · ImageSection · SpotlightToggle]
  end

  subgraph State Layer
    AuthProv[authStateProvider\nStateProvider<bool>]
    StatsProv[statsProvider\nAsyncNotifierProvider<JournalStats>]
    BackupProg[backupProgressProvider\nStateProvider<BackupStage?>]
  end

  subgraph Service Layer
    StorSvc[StorageService\nObjectBox · pagination · thumbnails · file cleanup]
    SecSvc[SecurityService\nPBKDF2 · exponential backoff · salt rotation · parallel reads]
    EncSvc[EncryptionService\nAES-256-GCM · off-thread via compute()]
    BakSvc[BackupService\noff-thread · staged progress · image toJson fix]
  end

  subgraph Infra Layer
    OBX[(ObjectBox DB)]
    FSS[(FlutterSecureStorage)]
    FS[(Filesystem\nImages · Thumbnails · Backups)]
  end

  Root -- watches --> AuthProv
  Root --> Lock
  Root --> Shell
  Shell -- WidgetsBindingObserver --> Shell
  PS -- reads --> StatsProv
  StatsProv -- reads --> StorSvc
  JS -- paginates --> StorSvc
  CS -- full load + fold() --> StorSvc
  BakSvc -- progress --> BackupProg
  PS -- watches --> BackupProg

  StorSvc --> OBX
  StorSvc -- thumbnails/cleanup --> FS
  SecSvc --> FSS
  EncSvc -. compute() .-> StorSvc
  BakSvc -. compute() .-> BakSvc
```

### Package Changes

| Change | Action |
|---|---|
| Remove `device_info_plus`, `battery_plus`, `system_info2` | Delete from `pubspec.yaml` and all import sites |
| Add `flutter_image_compress` | Image compression before save |
| Add `image` (Dart) | Thumbnail generation in `StorageService` |
| Retain `pointycastle`, `encrypt`, `flutter_riverpod`, `flutter_secure_storage` | No version change |

---

## Components and Interfaces

### 1. StatsProvider (new)

**Location:** `lib/providers/stats_provider.dart`

```dart
// Data model
class JournalStats {
  final int streak;
  final int totalEntries;
  final double averageMood;    // 0.0–12.0, –1 means no entries
  final int totalWordCount;
  final int journalAgeInDays;
  final List<String> topTags;  // up to 3, alpha-sorted on tie
}

// Provider
@riverpod
class StatsNotifier extends _$StatsNotifier
    implements AsyncNotifierProvider<StatsNotifier, JournalStats> {
  @override
  Future<JournalStats> build();    // reads storageServiceProvider
  void invalidate();               // called after entry mutation
}
```

- Reads the full entry list from `StorageService.getJournal()` **once** per build cycle.
- Computes all 6 stats in a single `fold()` pass.
- Cached until `ref.invalidate(statsNotifierProvider)` is called by any mutation site (entry add, edit, or delete). Because this is a global Riverpod provider, it persists across navigations — `ProfileScreen` does not need to re-trigger computation on every visit if no mutation has occurred.
- On error: returns `AsyncValue.error`, which `ProfileScreen` maps to empty-state values.
- After creating `stats_provider.dart`, run `flutter pub run build_runner build --delete-conflicting-outputs` to generate `stats_provider.g.dart`.

### 2. GlassContainer — `useBackdropFilter` Refinement

The `GlassContainer` already has the `useBackdropFilter` parameter (defaulting to `false`). Two outstanding defects must be fixed:

**Defect A — Missing RepaintBoundary:** The current code tree is `ClipRRect → BackdropFilter → Container`, with no `RepaintBoundary`. Every repaint of surrounding UI forces BackdropFilter rasterization.

**Defect B — Missing blur clamp:** The `blur` value is passed directly to `ImageFilter.blur` without range clamping.

**Corrected implementation:**

- When `useBackdropFilter: true`:
  - Widget tree: `RepaintBoundary → ClipRRect(borderRadius) → BackdropFilter(sigmaX: _clampedBlur, sigmaY: _clampedBlur) → Container(decoration) → child`
  - The `RepaintBoundary` is the outermost wrapper so that changes inside do not propagate repaints upward.
  - The `ClipRRect` clips the blurred region to the container's border radius.
  - `_clampedBlur = blur.clamp(8.0, 20.0)` is computed in `build()`.
- When `useBackdropFilter: false` (default): `ClipRRect → Container` — no `BackdropFilter` instantiated.

```dart
@override
Widget build(BuildContext context) {
  final double _clampedBlur = blur.clamp(8.0, 20.0);

  final innerContainer = Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.1)),
      gradient: gradient ?? LinearGradient(...),
    ),
    child: child,
  );

  if (!useBackdropFilter) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: innerContainer,
    );
  }

  return RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _clampedBlur, sigmaY: _clampedBlur),
        child: innerContainer,
      ),
    ),
  );
}
```

### 3. MainShell — AnimationController Lifecycle

`MainShell` currently extends `State<MainShell> with SingleTickerProviderStateMixin` and does NOT implement `WidgetsBindingObserver`. It must be upgraded:

```dart
class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgCtrl = AnimationController(...)..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bgCtrl.stop();
    } else if (state == AppLifecycleState.resumed && _isUnlocked) {
      _bgCtrl.repeat(reverse: true);
    }
  }
}
```

`_isUnlocked` is derived from `authStateProvider` (see §8 below). The animation does not resume if the lock screen is visible.

### 4. LockScreen — Idle Animation Cutoff

`LockScreen` tracks the last user interaction timestamp. A single `Timer` fires after 5 seconds of inactivity and calls `_stopAnimation()`. Any PIN digit, backspace, or biometric button tap resets the timer and resumes the animation.

```dart
Timer? _idleTimer;
bool _animating = true;

void _resetIdleTimer() {
  _idleTimer?.cancel();
  if (!_animating) setState(() => _animating = true);
  _idleTimer = Timer(const Duration(seconds: 5), _stopAnimation);
}

void _stopAnimation() {
  if (mounted) setState(() => _animating = false);
}
```

Idle visual state uses static widgets; `AnimatedContainer` transitions driven by `_animating` flag only.

### 5. Cursor-Based Pagination in StorageService

**New types:**

```dart
// Opaque cursor — wraps the ObjectBox integer record ID of the last returned entry
class PaginationCursor {
  final int _lastId;
  const PaginationCursor._(this._lastId);
}

// Result container
class PagedResult<T> {
  final List<T> items;
  final PaginationCursor? nextCursor;   // null = no more pages
  const PagedResult({required this.items, this.nextCursor});
}
```

**New method on StorageService:**

```dart
Future<PagedResult<JournalEntry>> getJournalPage(
  int pageSize, [
  PaginationCursor? cursor,
]) async {
  if (pageSize < 1 || pageSize > 100) {
    throw ArgumentError('pageSize must be in [1, 100], got $pageSize');
  }
  // Build ObjectBox query with optional id < cursor._lastId filter,
  // order by date DESC, limit pageSize + 1 (to detect hasMore)
  ...
  final nextCursor = results.length > pageSize
    ? PaginationCursor._(results[pageSize - 1].id)
    : null;
  return PagedResult(items: results.take(pageSize).toList(), nextCursor: nextCursor);
}
```

**JournalScreen — Infinite Scroll:**

```dart
late ScrollController _scrollCtrl;
PaginationCursor? _cursor;
bool _hasMore = true;
bool _isPaging = false;

void _onScroll() {
  final position = _scrollCtrl.position;
  const threshold = 5; // items before end
  if (!_isPaging && _hasMore &&
      position.pixels >= position.maxScrollExtent - (threshold * _avgItemHeight)) {
    _loadNextPage();
  }
}
```

### 6. Off-Thread Encryption via `compute()`

`_CryptoPayload` is a Dart `record` (no class references, safely sendable across isolates):

```dart
typedef _EncryptPayload = ({Uint8List keyBytes, String plaintext});
typedef _DecryptPayload = ({Uint8List keyBytes, String ciphertext});

// Top-level functions (required by compute())
String _isolateEncrypt(_EncryptPayload p) { ... }
String _isolateDecrypt(_DecryptPayload p) { ... }
```

`StorageService.saveJournalEntry()` currently delegates to `ObjectBoxJournalEntry.fromFreezed(entry)` which calls `EncryptionService().encrypt()` directly on the main thread. The refactor moves encryption into a top-level function callable via `compute()`:

```dart
// Off-thread encryption
final encrypted = await compute(
  _isolateEncrypt,
  (keyBytes: key, plaintext: entry.content),
);
```

`StorageService.getJournal()` already uses `compute(_batchDecryptEntries, ...)` — this path is largely compliant and should be preserved.

**Note on `saveDraft`:** `StorageService.saveDraft()` calls `EncryptionService().encrypt(draftData)` synchronously on the main thread. This call must also be moved off-thread via `compute()` (Req 7.7).

### 7. Calendar Pre-Computation

```dart
class _CalendarScreenState ... {
  Map<DateTime, List<JournalEntry>> _entriesByDate = {};

  void _buildDateMap(List<JournalEntry> entries) {
    _entriesByDate = entries.fold({}, (map, entry) {
      final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
      (map[key] ??= []).add(entry);
      return map;
    });
  }

  List<JournalEntry> _getEntriesForDay(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _entriesByDate[key] ?? const [];
  }
}
```

`_buildDateMap` is called immediately after `_loadData()` completes and again after any entry mutation. `_getEntriesForDay` is now an O(1) map lookup — no list scan.

### 8. Security State Isolation

Replace `bool isAuthenticated` + `setState()` in `RootOrchestrator` with:

```dart
// Global provider — lib/providers/auth_provider.dart
final authStateProvider = StateProvider<bool>((ref) => false);

// In RootOrchestrator.build():
@override
Widget build(BuildContext context) {
  if (isLoading) return const _LoadingScaffold();
  return Consumer(
    builder: (ctx, ref, _) {
      final isAuthenticated = ref.watch(authStateProvider);
      if (!isAuthenticated) {
        return LockScreen(
          onUnlock: () => ref.read(authStateProvider.notifier).state = true,
        );
      }
      return const MainShell();
    },
  );
}
```

`JournalScreen`, `CalendarScreen`, `IdentityScreen`, and `ProfileScreen` do not watch `authStateProvider` — they rebuild only for their own providers, so they undergo zero rebuilds on auth-state transitions.

`MainShell._isUnlocked` reads `ref.read(authStateProvider)` (not `watch`) — so the animation resume check does not create a subscription, it just reads the current value.

### 9. EntryEditor Decomposition

`entry_editor.dart` is split into:

```
EntryEditor (parent — manages overall state, draft lifecycle, save/cancel)
  ├── MoodSelector     (StatefulWidget — owns selectedMood, emits via onChanged callback)
  ├── TagPicker        (StatefulWidget — owns tags list, emits via onChanged callback)
  ├── ImageSection     (StatefulWidget — owns images list, emits via onChanged callback)
  ├── SpotlightToggle  (StatelessWidget — receives isSpotlight + onChanged, single rebuild)
  └── _AutoSaveIndicator (StatelessWidget — displays _isSaving/_hasChanges)
```

Parent communicates downward via constructor parameters; sub-widgets call back via `void Function(...)` callbacks. Only the changed sub-widget rebuilds on its own state change. The parent's `setState()` scope is limited to `_isSaving`, `_hasChanges`, and the selected-type toggle.

**SpotlightToggle:**
```dart
class SpotlightToggle extends StatelessWidget {
  final bool isSpotlight;
  final ValueChanged<bool> onChanged;
  const SpotlightToggle({required this.isSpotlight, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isSpotlight ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isSpotlight ? AppColors.amber500 : AppColors.slate400,
      ),
      onPressed: () => onChanged(!isSpotlight),
      tooltip: isSpotlight ? 'Remove spotlight' : 'Mark as spotlight',
    );
  }
}
```

**ImageSection owns compression — not the parent `EntryEditor`:**

To preserve rebuild isolation (Req 10.3), image compression must be initiated inside `ImageSection`, not the parent `EntryEditor`. `ImageSection` calls `_compressAndCreateRef` internally before invoking `onChanged(newImages)`. The parent's `setState()` is never called as a direct result of an image add/remove — only `ImageSection` rebuilds. The parent receives the final `List<ImageReference>` via the callback and stores it in its own field without calling `setState()` unless also updating `_hasChanges`:

```dart
// Inside ImageSection — handles compression and emits via callback
Future<void> _handleImageAdd(String originalPath) async {
  final ref = await _compressAndCreateRef(originalPath);  // async, inside ImageSection
  setState(() => _images = [..._images, ref]);            // only ImageSection rebuilds
  widget.onChanged(_images);                              // parent stores without setState
}
```

The parent updates `_hasChanges = true` (which rebuilds only `_AutoSaveIndicator`) via the callback, not the images list itself.

### 10. Resource Leak Fixes

**IdentityScreen — TabController listener (critical fix):**

The current code adds an **anonymous listener inside `build()`** via a `Builder` widget:
```dart
// CURRENT (broken) — in build():
Builder(builder: (ctx) {
  final tabController = DefaultTabController.of(ctx);
  tabController.addListener(() { ... });  // adds on EVERY rebuild, never removed
  ...
})
```

This accumulates unbounded anonymous listeners. The correct fix extracts the controller and listener into the state, adds once in `initState()`, and removes in `dispose()`:

```dart
class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  TabController? _tabCtrl;
  VoidCallback? _tabListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newCtrl = DefaultTabController.of(context);
    if (newCtrl != _tabCtrl) {
      // Remove from old controller
      if (_tabListener != null) _tabCtrl?.removeListener(_tabListener!);

      _tabCtrl = newCtrl;
      _tabListener = () {
        if (!newCtrl.indexIsChanging && mounted) {
          if (newCtrl.index < categories.length) {
            final newId = categories[newCtrl.index].id;
            if (activeId != newId) setState(() => activeId = newId);
          }
        }
      };
      _tabCtrl!.addListener(_tabListener!);
    }
  }

  @override
  void dispose() {
    if (_tabListener != null) _tabCtrl?.removeListener(_tabListener!);
    _searchCtrl.dispose();
    super.dispose();
  }
}
```

> **Note:** Using `didChangeDependencies` (not `initState`) is necessary because `DefaultTabController.of(context)` requires a valid `BuildContext` with the inherited controller.

**CalendarScreen — already disposes `_pageController`.** The existing `dispose()` in the current source already calls `_pageController.dispose()` — this is confirmed compliant with Requirement 13.1. No change needed.

**StorageService.deleteJournalEntry — orphaned file cleanup:**
```dart
Future<void> deleteJournalEntry(String entryId) async {
  final query = _journalBox.query(...).build();
  try {
    final existing = query.findFirst();
    if (existing == null) return;
    final entry = existing.toFreezed();
    _journalBox.remove(existing.id);  // DB record first

    for (final img in entry.images) {
      if (img.type != ImageSourceType.filePath) continue;
      if (img.source.isEmpty) continue;
      try {
        final file = File(img.source);
        if (await file.exists()) await file.delete();
        final thumbPath = StorageService.thumbnailPath(img.source);
        final thumb = File(thumbPath);
        if (await thumb.exists()) await thumb.delete();
      } catch (e) {
        debugPrint('Failed to delete image file ${img.source}: $e');
        // Continue with remaining files
      }
    }
  } finally {
    query.close();
  }
}
```

### 11. Backup Off-Thread with Staged Progress

**New enum and provider:**
```dart
enum BackupStage { idle, serializing, encrypting, writing, reading, decrypting, restoring }

final backupProgressProvider = StateProvider<BackupStage?>((ref) => null);
```

`BackupService.exportToFile()` reads from `backupProgressProvider` notifier:
```dart
Future<BackupResult> exportToFile({...}) async {
  // Stage 1: Serializing (main isolate, UI-safe)
  ref.read(backupProgressProvider.notifier).state = BackupStage.serializing;
  final jsonString = await compute(_serializeData, data);

  // Stage 2: Encrypting
  ref.read(backupProgressProvider.notifier).state = BackupStage.encrypting;
  final content = await compute(_encryptData, (keyBytes: key, json: jsonString));

  // Stage 3: Writing
  ref.read(backupProgressProvider.notifier).state = BackupStage.writing;
  await compute(_writeFile, (path: filePath, content: content));

  ref.read(backupProgressProvider.notifier).state = null; // idle
  return BackupResult(success: true, ...);
}
```

`BackupService.importFromJson()` mirrors the export pattern — each stage is a **separate** `compute()` call with a main-thread provider update between calls.

> **Important:** All three import stages must be separate `compute()` calls with main-thread stage updates between them. Combining stages into one isolate would prevent the UI from seeing intermediate stage transitions.

### 12. Backup Image Serialization Fix

**Defect in `BackupService._serializeEntry`:**

```dart
// CURRENT (broken):
'images': entry.images,
// jsonEncode() calls .toString() on ImageReference objects → emits {} for each

// FIXED:
'images': entry.images.map((i) => i.toJson()).toList(),
```

No changes required in `_deserializeEntry` — `_parseBackupImages` already handles the `Map` format correctly (checks `first is Map && first.containsKey('source')`).

### 13. Salt Rotation + Atomic Re-encryption on PIN Change

This is the most complex change. The design provides an atomic, rollback-safe `changePin` implementation with crash-recovery via a `_rekeyPendingKey` flag.

**Current defect:** `SecurityService.changePin` reuses the existing `_saltKey` value — it reads the current salt and hashes the new PIN against it, providing no forward secrecy. The encryption key is also never rotated.

**Revised `changePin` algorithm (12-step):**

```
0. Write _rekeyPendingKey = 'true' to FlutterSecureStorage
1. Verify oldPin (read hash, salt, attempt count in parallel via Future.wait)
2. If verification fails → delete _rekeyPendingKey, return failure, no mutation
3. Save snapshot: oldPinSalt, oldEncSalt, oldHash (parallel reads via Future.wait)
4. Load all journal entries (getJournal() — returns plaintext via cached key)
5. Generate newPinSalt, newEncSalt
6. Derive newEncKey from (newPin, newEncSalt) — off-thread via compute()
7. Re-encrypt all loaded entries under newEncKey  ← off-thread, compute()
8. Write to SecureStorage: newPinSalt, newEncSalt, newHash — BEFORE writing to DB
   (three writes via Future.wait; if any fails, skip step 9, go to rollback)
9. Write to DB: save all re-encrypted entries atomically
   (ObjectBox putMany() — single transaction; if fails, go to rollback)
10. Update in-memory cached key → newEncKey
11. Delete _rekeyPendingKey from FlutterSecureStorage
12. Return success
```

> **Key ordering:** SecureStorage writes (step 8) happen **before** the DB write (step 9). If the app is killed after step 8 but before step 9, entries remain under `oldEncKey` while `_rekeyPendingKey` signals the interrupted operation. On next launch, the recovery flow re-runs `changePin` from scratch.

**New return type:**
```dart
class ChangePinResult {
  final bool success;
  final String? error;
  const ChangePinResult({required this.success, this.error});
  factory ChangePinResult.fromVerification(PinVerificationResult r) =>
      ChangePinResult(success: false, error: r.error);
}
```

**New `StorageService` methods:**
```dart
Future<int?> getObjectBoxIdForEntry(String entryId) async { ... }
Future<void> putManyJournalEntries(List<JournalEntry> entries) async { ... }
```

### 14. Exponential Backoff

**New constant in `SecurityConstants` (add to `lib/config/constants.dart`):**
```dart
// Use existing field name SecurityConstants.maxAttempts — do NOT rename
static const String lockoutCycleKey = 'lockout_cycle_count';
```

**Lockout duration formula:**
```dart
int _computeLockoutDuration(int cycleCount) {
  // cycleCount is already incremented (>= 1)
  final raw = SecurityConstants.lockoutDurationSeconds *
      math.pow(2, cycleCount - 1).toInt();
  return raw.clamp(0, 3600);
}
```

**Lockout timestamp storage format:** The existing code stores `lockoutUntil` as `millisecondsSinceEpoch.toString()` and reads it with `int.parse` + `DateTime.fromMillisecondsSinceEpoch`. This format must be preserved for backward compatibility with existing stored lockouts. Do NOT change to ISO8601 format.

### 15. Parallel FlutterSecureStorage Reads

**`verifyPin` — parallel reads:**
```dart
Future<PinVerificationResult> verifyPin(String pin) async {
  final [pinHash, salt, attemptCountStr, lockoutUntilStr] = await Future.wait([
    _storage.read(key: _pinHashKey),
    _storage.read(key: _saltKey),
    _storage.read(key: _attemptCountKey),
    _storage.read(key: _lockoutUntilKey),
  ]);
  // ... rest of logic unchanged ...
}
```

**`initialize` — parallel reads and initialization of BOTH salts:**

The current `initialize()` only creates `_saltKey` and ignores `_encryptionSaltKey`. The corrected version initializes both in parallel:

```dart
Future<void> initialize() async {
  final [salt, encSalt] = await Future.wait([
    _storage.read(key: _saltKey),
    _storage.read(key: _encryptionSaltKey),
  ]);
  if (salt == null) await _storage.write(key: _saltKey, value: _generateSalt());
  if (encSalt == null) await _storage.write(key: _encryptionSaltKey, value: _generateSalt());
}
```

### 16. Image Compression + Thumbnails

**In `EntryEditor` (inside `ImageSection`) — before constructing `ImageReference`:**
```dart
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<ImageReference> _compressAndCreateRef(String originalPath) async {
  final result = await FlutterImageCompress.compressAndGetFile(
    originalPath,
    '${originalPath}_compressed.jpg',
    quality: 80,
    minWidth: 1920,
    minHeight: 1920,
    keepExif: false,
  );
  final compressed = result ?? XFile(originalPath); // fallback to original
  return ImageReference(source: compressed.path, type: ImageSourceType.filePath);
}
```

**In `StorageService.saveJournalEntry()` — thumbnail generation:**

```dart
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

static String thumbnailPath(String originalPath) {
  final dir = p.dirname(originalPath);
  final base = p.basenameWithoutExtension(originalPath);
  return p.join(dir, '${base}_thumb.jpg');
}

Future<void> _generateThumbnail(String filePath) async {
  try {
    await compute(_isolateGenerateThumbnail,
        (sourcePath: filePath, thumbPath: thumbnailPath(filePath)));
  } catch (e) {
    debugPrint('Thumbnail generation failed for $filePath: $e');
  }
}

typedef _ThumbnailPayload = ({String sourcePath, String thumbPath});

void _isolateGenerateThumbnail(_ThumbnailPayload p) {
  final bytes = File(p.sourcePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return;
  final thumb = img.copyResize(decoded,
      width: decoded.width > decoded.height ? 300 : -1,
      height: decoded.height >= decoded.width ? 300 : -1);
  File(p.thumbPath).writeAsBytesSync(img.encodeJpg(thumb, quality: 75));
}
```

**In `ImageThumbnailWidget` — thumbnail-first fallback:**
```dart
Widget _buildFileImage() {
  final thumbPath = StorageService.thumbnailPath(widget.imageRef.source);
  final thumbFile = File(thumbPath);
  if (thumbFile.existsSync()) {
    return Image.file(thumbFile, fit: widget.fit,
        cacheWidth: 400, cacheHeight: 400);
  }
  return Image.file(File(widget.imageRef.source), fit: widget.fit,
      cacheWidth: 400, cacheHeight: 400);
}
```

### 17. Username / Profile Management

`ProfileScreen` header currently reads `_deviceName` from `device_info_plus`. After the device diagnostics removal, it shall read `settings.username ?? 'Journaler'`.

An inline edit affordance is added to the header:

```dart
// In ProfileScreen header GlassContainer:
Row(
  children: [
    CircleAvatar(
      backgroundColor: AppColors.indigo500,
      child: Text(
        (settings.username?.isNotEmpty == true)
            ? settings.username![0].toUpperCase()
            : 'J',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(settings.username?.isNotEmpty == true
              ? settings.username! : 'Journaler',
              style: ...),
          Text('${stats.totalEntries} entries · ${stats.streak} day streak',
              style: ...),
        ],
      ),
    ),
    IconButton(
      icon: const Icon(Icons.edit_outlined, color: AppColors.slate400),
      onPressed: _showUsernameEditDialog,
    ),
  ],
)

Future<void> _showUsernameEditDialog() async {
  final ctrl = TextEditingController(text: settings.username ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.slate900,
      title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: ctrl,
        maxLength: 50,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Your display name',
          hintStyle: TextStyle(color: AppColors.slate400),
          counterStyle: TextStyle(color: AppColors.slate400),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('SAVE'),
        ),
      ],
    ),
  );
  if (result != null && mounted) {
    final updated = settings.copyWith(username: result.isEmpty ? null : result);
    await ref.read(storageServiceProvider).saveSettings(updated);
    setState(() => settings = updated);
  }
}
```

### 18. Backup Restore UI

The "Manage Backups" sheet currently only has a delete button per row. A restore button is added alongside:

```dart
// In _showBackupsDialog → ListView.builder → each backup row:
Row(
  children: [
    // ... existing icon, name, date ...
    IconButton(
      icon: const Icon(Icons.restore, color: AppColors.emerald500),
      tooltip: 'Restore this backup',
      onPressed: () => _confirmAndRestore(ctx, backup),
    ),
    IconButton(
      icon: const Icon(Icons.delete_outline, color: AppColors.rose500),
      // ... existing delete logic
    ),
  ],
)

Future<void> _confirmAndRestore(BuildContext sheetCtx, BackupFileInfo backup) async {
  Navigator.pop(sheetCtx); // close the sheet
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.slate900,
      title: const Text('Restore Backup?', style: TextStyle(color: Colors.white)),
      content: Text(
        'This will merge "${backup.name}" entries with your current data. '
        'Existing entries will not be deleted.',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RESTORE')),
      ],
    ),
  );
  if (confirmed != true) return;

  final backupService = ref.read(backupServiceProvider);
  BackupResult result;
  if (backup.isEncrypted) {
    result = await backupService.importEncryptedFile(backup.path);
  } else {
    final content = await File(backup.path).readAsString();
    result = await backupService.importFromJson(content);
  }

  if (!mounted) return;
  if (result.success) {
    ref.invalidate(statsNotifierProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Restore complete'),
               backgroundColor: AppColors.emerald500),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Restore failed'),
               backgroundColor: AppColors.rose500),
    );
  }
}
```

### 19. Spotlight Toggle and Tag Filter in JournalScreen

```dart
// JournalScreen state additions:
bool _spotlightOnly = false;
final Set<String> _selectedTags = {};

// Filtered entries (replaces current simple search filter):
List<JournalEntry> get _filteredEntries {
  var result = _searchQuery.trim().isEmpty ? entries : entries.where((e) {
    final q = _searchQuery.toLowerCase();
    return e.headline.toLowerCase().contains(q) || e.content.toLowerCase().contains(q);
  });
  if (_spotlightOnly) result = result.where((e) => e.isSpotlight);
  if (_selectedTags.isNotEmpty) {
    result = result.where((e) => _selectedTags.every((t) => e.tags.contains(t)));
  }
  return result.toList();
}

// Available tags derived from full entry list:
Set<String> get _allTags => entries.expand((e) => e.tags).toSet();
```

Filter chips are displayed in a horizontally scrollable row below the search bar.

---

## Data Models

### New Types

```dart
// lib/models/stats.dart
class JournalStats {
  final int streak;
  final int totalEntries;
  final double averageMood;      // -1.0 means no entries (displays as "—")
  final int totalWordCount;
  final int journalAgeInDays;
  final List<String> topTags;
  const JournalStats({...});
  static const empty = JournalStats(
    streak: 0, totalEntries: 0, averageMood: -1,
    totalWordCount: 0, journalAgeInDays: 0, topTags: [],
  );
}

// lib/models/paged_result.dart
class PaginationCursor {
  final int _lastId;
  const PaginationCursor._(this._lastId);
}

class PagedResult<T> {
  final List<T> items;
  final PaginationCursor? nextCursor;
  const PagedResult({required this.items, this.nextCursor});
}

// lib/services/backup_service.dart (addition)
enum BackupStage { idle, serializing, encrypting, writing, reading, decrypting, restoring }

// lib/services/security_service.dart (addition)
class ChangePinResult {
  final bool success;
  final String? error;
  const ChangePinResult({required this.success, this.error});
}
```

### Modified Signatures

| Component | Old Signature | New Signature |
|---|---|---|
| `StorageService.deleteJournalEntry` | `Future<void> deleteJournalEntry(String id)` | Same signature, new file-cleanup body |
| `StorageService.getJournalPage` | (new) | `Future<PagedResult<JournalEntry>> getJournalPage(int pageSize, [PaginationCursor? cursor])` |
| `StorageService.putManyJournalEntries` | (new) | `Future<void> putManyJournalEntries(List<JournalEntry> entries)` |
| `StorageService.getObjectBoxIdForEntry` | (new) | `Future<int?> getObjectBoxIdForEntry(String entryId)` |
| `SecurityService.changePin` | `Future<PinVerificationResult> changePin(String old, String new)` | `Future<ChangePinResult> changePin(String old, String new)` — new return type, salt rotation + re-encryption with `_rekeyPendingKey` crash guard |
| `SecurityService.hasInterruptedRekey` | (new) | `Future<bool> hasInterruptedRekey()` — checked on app launch |
| `SecurityService.verifyPin` | sequential reads | parallel `Future.wait([4 reads])` |
| `SecurityService.initialize` | initializes `_saltKey` only | parallel `Future.wait([_saltKey, _encryptionSaltKey])`, generates both if absent |
| `GlassContainer.blur` | applied directly | clamped to `[8.0, 20.0]` before use |
| `BackupService._serializeEntry` | `'images': entry.images` | `'images': entry.images.map((i) => i.toJson()).toList()` |

---

## Component Interactions and Data Flow

### Profile Screen Stats Flow

```
ProfileScreen.build()
  → ref.watch(statsNotifierProvider)
      → AsyncValue<JournalStats>
         ├─ loading: show shimmer per card
         ├─ data: render 6 stat cards + username header
         └─ error: render empty-state cards + SnackBar

StatsNotifier.build()
  → storageService.getJournal()
  → _computeStats(entries)          // single fold() pass
  → return JournalStats

// Invalidation path:
JournalScreen.onSave()
  → storageService.saveJournalEntry(entry)
  → ref.invalidate(statsNotifierProvider)
```

### Pagination Flow

```
JournalScreen.initState()
  → _loadNextPage()         // cursor=null, first page
  → setState(entries = page.items, cursor = page.nextCursor)

ScrollController.onScroll()
  → within threshold?
      → _loadNextPage(cursor)
      → setState(entries = [...entries, ...page.items], cursor = nextCursor)
      → if nextCursor == null: _hasMore = false
```

### Encryption Flow (Save Path)

```
EntryEditor.handleSave()
  → compress image (compute, off-thread) if filePath
  → widget.onSave(JournalEntry)
  → storageService.saveJournalEntry(entry)
      → compute(_isolateEncrypt, (keyBytes, plaintext))  ← off-thread
      → ObjectBoxJournalEntry.put()
      → _generateThumbnail(filePath)                    ← async, non-blocking
```

### Salt Rotation + Re-encryption Flow

```
PinManagementScreen → changePin(old, new)
  → SecurityService.changePin(old, new)
      → write _rekeyPendingKey = 'true'
      → verifyPin(old)        [parallel reads]
      → snapshot old secrets  [parallel reads]
      → storageService.getJournal()
      → compute(_pbkdf2Derive, newEncSalt) → newEncKey
      → compute(_reEncryptEntries, {entries, newEncKey})
      → Future.wait([write newPinSalt, write newEncSalt, write newHash])  ← BEFORE DB
         └─ on failure: rollback secrets + delete _rekeyPendingKey
      → storageService.putManyJournalEntries(reEncrypted)  ← AFTER SecureStorage
         └─ on failure: rollback secrets + delete _rekeyPendingKey
      → _cachedEncryptionKey = newEncKey
      → delete _rekeyPendingKey
```

---

## Error Handling

### Salt Rotation Rollback (Critical Path)

The atomic guarantee rests on four properties:

1. **Crash-recovery flag**: `_rekeyPendingKey = 'true'` is written **before any mutation** and deleted only after full success or full rollback.
2. **SecureStorage writes before DB writes**: New salts written before DB `putMany`, ensuring consistent state.
3. **ObjectBox `putMany` atomicity**: Single transaction — all-or-nothing.
4. **SecureStorage rollback**: On failure, three parallel writes restore old secrets from snapshot.

### Pagination Errors

`getJournalPage` propagates failures as a failed `Future`. `JournalScreen` catches in `try/catch` around `_loadNextPage`, shows a `SnackBar` with retry button. The `_cursor` is not advanced on failure.

### Backup Off-Thread Failure

If the `compute()` isolate fails, `exportToFile` / `importFromJson` catch, reset `backupProgressProvider` to `null`, return `BackupResult(success: false, error: ...)`.

---

## Correctness Properties

### Property 1: Stats computation is correct for any entry collection
*For any* list of `JournalEntry` objects (including empty), `_computeStats()` returns a `JournalStats` where all six fields satisfy their definitions (totalEntries, totalWordCount, averageMood, journalAgeInDays, topTags, streak).
**Validates: Requirements 1.1, 1.3**

### Property 2: BackdropFilter is absent when useBackdropFilter is false
*For any* `GlassContainer` constructed with `useBackdropFilter: false`, the rendered widget subtree contains no `BackdropFilter` widget instance.
**Validates: Requirements 3.3**

### Property 3: Blur sigma is clamped to [8.0, 20.0]
*For any* `blur` value passed to `GlassContainer` with `useBackdropFilter: true`, the applied sigmaX and sigmaY equal `blur.clamp(8.0, 20.0)`.
**Validates: Requirements 3.5**

### Property 4: Image compression never increases file size
*For any* valid JPEG/PNG byte array `b`, `compress(b).length ≤ b.length` after `FlutterImageCompress` at quality 80 with max long-edge 1920.
**Validates: Requirements 5.5**

### Property 5: Pagination round-trip invariant
*For any* entry collection `E` and page size `p` in [1, 100], concatenating all pages equals `getJournal()` in the same order.
**Validates: Requirements 6.5**

### Property 6: Encryption round-trip
*For any* non-empty plaintext string and cached encryption key, `decrypt(encrypt(plaintext)) == plaintext` using AES-256-GCM.
**Validates: Requirements 7.3**

### Property 7: Calendar date map correctness
*For any* list of `JournalEntry` objects, `_buildDateMap(entries)[d]` equals the sublist of all entries with date zeroed to midnight equal to `d`.
**Validates: Requirements 8.3**

### Property 8: Search debounce idempotence
*For any* query `q` and entry collection `E`, the debounce-fired result equals a direct single-pass filter with the same `q` and `E`.
**Validates: Requirements 9.4**

### Property 9: Backup round-trip (with image fix)
*For any* list of `JournalEntry` objects, serializing via `exportToFile()` and importing via `importFromJson()` produces a list where each entry has identical values for all fields including `images`.
**Validates: Requirements 15.5, 20.3**

### Property 10: New salt invariant after changePin
*For any* successful `changePin(oldPin, newPin)`, `_saltKey` value after the call differs from before and is non-empty.
**Validates: Requirements 16.3**

### Property 11: PIN change round-trip and old-PIN rejection
*For any* valid `(oldPin, newPin)` pair, after successful `changePin`: `verifyPin(newPin)` returns success; `verifyPin(oldPin)` returns failure.
**Validates: Requirements 16.4, 16.5**

### Property 12: Lockout duration formula correctness and monotonicity
*For any* cycle count `n ≥ 1`, `lockoutDuration(n) == min(3600, base × 2^(n-1))`. Monotonically non-decreasing.
**Validates: Requirements 17.2, 17.3, 17.4**

### Property 13: Parallel reads produce equivalent results
*For any* combination of stored values, `verifyPin(pin)` using `Future.wait` returns identical `PinVerificationResult` to the sequential implementation.
**Validates: Requirements 18.1, 18.3**

---

## Testing Strategy

### Unit Tests (Priority)

- `BackupService._serializeEntry` produces `images` as a `List<Map>` not `List<{}>` — **Req 20.1**
- `StatsNotifier` caches result (provider called once for multiple `ref.read` calls) — **Req 1.2**
- `StorageService.getJournalPage` throws `ArgumentError` for pageSize < 1 or > 100 — **Req 6.1**
- `changePin` rollback restores `verifyPin(oldPin)` success when storage write fails — **Req 16.6**
- `changePin` with `newPin == oldPin` generates new salts — **Req 16.8**
- `lockout_cycle_count` resets to 0 on successful PIN verification — **Req 17.5**
- `SecurityService.initialize()` writes both `_saltKey` and `_encryptionSaltKey` when absent — **Req 18.2**
- `Future.wait()` in `verifyPin` propagates failure when any read throws — **Req 18.4**
- `LockScreen` stops animation after 5 seconds of user inactivity — **Req 4.3**
- `IdentityScreen` does not register duplicate `TabController` listeners on rebuild — **Req 12.3, 12.4**
- `StorageService.deleteJournalEntry` does not attempt to delete `galleryAsset` or `webUrl` images — **Req 14.5**
- `BackupService.importFromJson` returns `BackupResult(success: false)` on corrupted JSON — **Req 15.6**

### Widget Tests

- `GlassContainer(useBackdropFilter: true)` → widget tree contains `RepaintBoundary` above `BackdropFilter` — **Req 3.1, 3.4**
- `MoodSelector` rebuild isolation — change mood, verify headline `TextField` is not rebuilt — **Req 10.2**
- `SpotlightToggle` rebuild isolation — toggle, verify content and mood widgets are not rebuilt — **Req 23.2**
- `authStateProvider` change → `JournalScreen`, `CalendarScreen`, `IdentityScreen`, `ProfileScreen` undergo zero builds — **Req 11.2**

### Integration Tests

- Full PIN setup → entry create → spotlight mark → calendar view → journal filter → backup → restore → verify entries intact — **Req 19.1–19.7**
- PIN change while entries exist → verify all entries remain readable under new PIN — **Req 16.2**
- Remove `device_info_plus`, `battery_plus`, `system_info2` → app compiles on Android/iOS/Windows — **Req 2.2**
- Username edit → save → reopen Profile → verify username persists — **Req 21.5**

---

## Migration and Backward-Compatibility Notes

### Legacy Entries Without Thumbnails
`ImageThumbnailWidget._buildFileImage()` calls `File(thumbPath).existsSync()` before deciding which path to load. Since thumbnails don't exist for legacy entries, the widget transparently falls back to the full-resolution image with `cacheWidth: 400, cacheHeight: 400`. No migration script needed.

### Existing PIN Users Upgrading (Salt Rotation)
The new `changePin` rotates both salts **only** when explicitly called. Existing users who do not change their PIN continue to use the existing salts and their entries remain readable. Salt rotation only happens on the next explicit `changePin`.

### Exponential Backoff Migration
Existing users have no `lockout_cycle_count` key. The code treats a missing key as `'0'` — first lockout uses `base_duration × 2^0 = base_duration` seconds, identical to the old flat lockout. No migration needed.

### `changePin` Return Type Change
`changePin` currently returns `PinVerificationResult`; it will return `ChangePinResult`. All call sites in `PinManagementScreen` must be updated. `ChangePinResult` exposes the same `success` and `error` fields.

### Dependency Removal
Removing `device_info_plus`, `battery_plus`, and `system_info2` requires:
1. Delete the three `pubspec.yaml` entries.
2. Remove all import statements in `profile_screen.dart`.
3. Delete `_initSystemInfo()`, `_startMetricsTimer()`, `_updateMetrics()`, `Timer`, `Battery`, `DeviceInfoPlugin`, `SysInfo` fields and methods.
4. Replace header card with `settings.username ?? 'Journaler'`.
5. Run `flutter pub get` and verify compilation.

### Interrupted Re-key Migration
Existing users will have no `_rekeyPendingKey` in FlutterSecureStorage. `hasInterruptedRekey()` returns `false` (key absent), so the new check is a no-op.

### `lib/providers/` Directory
The providers directory does not exist in the current codebase. It must be created. Both `stats_provider.dart` and `auth_provider.dart` live here. After creating either file, `build_runner` must be re-run.
