# Comprehensive Code Quality & Architectural Audit: DayVault

**Repository:** `C:\Users\ajaye\My_Products\dayvault` (package name `memory_palace`)
**Benchmarked against:** `C:\agents\agentresearchs\plans\engineering-skills\skills\engineering-standards`
**Audit date:** 2026-08-24 · **Commit:** `8f7fff4` (branch `main`, clean tree)
**Scope:** 90 Dart files / ~24,800 LOC (`lib/` 60 files, `test/` 26 files). No source was modified.

**Verification commands actually run for this audit:**

| Command | Result |
|---|---|
| `flutter analyze --no-pub` | **74 issues found** (ran in 105.4s) |
| `flutter test --no-pub` | **All tests passed** — 107 tests, 53s |
| `find lib -name "*.dart" \| xargs wc -l` | 24,811 lines |

---

## 1. Executive Summary & Quality Scorecard

DayVault is a **mature, thoughtfully-commented offline-first Flutter journal** that is a long way past prototype. There is real engineering judgment on display: PBKDF2 is pushed into isolates (`security_service.dart:223–228`), backup JSON encode/decode runs off the main isolate (`backup_service.dart:100`, `:175`), image decode is bounded to on-screen pixels (`image_widgets.dart:36–50`), the expensive `BackdropFilter` is isolated behind a `RepaintBoundary` (`glass_widgets.dart:83–90`), and several pure functions were deliberately extracted as `static` specifically so they could be unit-tested (`journal_screen.dart:24`, `stats_provider.dart:22`, `glass_widgets.dart:14`). The comments explaining *why* — the `heightFactor: 1.0` note at `main.dart:388–393`, the auto-lock policy rationale at `main.dart:141–156` — are exactly what `testing-quality.md` asks for ("Comment **why**, never what").

That quality is **unevenly distributed**, and the unevenness is the story of this audit. The parts that were recently worked on are good. The parts underneath them — the persistence contract, the credential model, and the thing the product is named after (the vault) — carry defects that the standards classify as non-negotiable failures.

Three structural facts drive most findings:

1. **The Privacy Vault is a UI state flag, not a confidentiality boundary.** `ObjectBoxJournalEntry.headline`/`.content` are stored as plain text by explicit design (`objectbox_models.dart:23–27`, `:147–148`), `isPrivate` is an ordinary unencrypted boolean column (`:50`), and the passcode gates a `setState` enum (`privacy_vault_screen.dart:34`, `:53–56`). On web the entire journal is written to `localStorage` unencrypted (`web_storage_service.dart:64`).
2. **There is no CI.** No `.github/`, no workflow file, nothing that runs `flutter analyze` or `flutter test` on a commit. The 74 analyzer issues and the vacuous test file at `test/objectbox_service_test.dart` are the predictable consequence — `stack-appendices.md §5` requires "CI on every commit: build, lint, typecheck, test, security scan."
3. **Three independent hand-rolled serializers exist for `JournalEntry`** (`objectbox_models.dart:140–158`, `backup_service.dart:69–85`, `entry_editor.dart:169–184`) alongside the generated `toJson`, all encoding enums as `.index`. Adding a field means remembering four places; reordering an enum silently corrupts stored data.

### Scorecard

| Dimension | Score | Basis |
|---|:--:|---|
| **Architecture & State Management** | **5 / 10** | Clean platform seam via conditional imports (`storage_service.dart:14–16`) — but no domain layer, two competing DI dialects, a Riverpod provider living inside the storage *contract* file (`storage_service_interface.dart:16`), and 300–400-line `build()` methods holding business logic. |
| **Standards Compliance (Dart/Flutter)** | **5 / 10** | 74 analyzer issues incl. 35 `annotate_overrides`, 8 unused imports, 2 empty `catch` blocks, an unused security field, and a dead `merge` parameter. Nothing enforces the bar. |
| **Performance, Memory & Resources** | **6 / 10** | Genuinely strong isolate/decode/repaint work, undercut by O(n) filtering inside `build()` (`journal_screen.dart:346–354`), a `FutureBuilder` future constructed per-frame (`image_widgets.dart:103–104`), ≥9 undisposed `TextEditingController`s, and 6 unbounded full-journal loads. |
| **Security, Offline Resilience & Data Integrity** | **3 / 10** | Vault provides no confidentiality; XOR masquerading as encryption is still live in the read path (`native_storage_service.dart:751`); recovery questions bypass rate limiting entirely; `pointycastle` — the crypto primitive behind every PIN — is not a declared dependency. |
| **Testability & Test Quality** | **5 / 10** | 107 green tests with good property-based work (`stats_provider_test.dart`), but **zero tests touch either `StorageService` implementation**, one test file is empty, and the "integration" test mocks away the only thing that can fail. |
| **Product Scalability & Maintainability** | **4 / 10** | A 2,275-line screen, a 395-line `build()`, `computeStreak` implemented three times, no CI, dead code committed to the repo (`original_storage_service.dart.txt`). |
| **Overall** | **4.7 / 10** | Solid product, credible craft in the recent layers, foundational risk in the persistence and credential layers. |

### Top 3 critical risks to address immediately

> **R1 — The Privacy Vault does not make anything private.**
> A "vaulted" entry is plaintext on disk, plaintext in an unencrypted export (`backup_service.dart:47` deliberately exports `PrivacyFilter.all`), and reachable by any caller who passes a different `PrivacyFilter` — no unlock proof is required at the query. This is the product's headline promise and it is not implemented. `security-privacy.md`: *"Authorize at the resource, not the route."*

> **R2 — Three silent data-loss paths are live in production code.**
> (a) A single failed `openStore` **renames the user's entire database away** with no restore path ever implemented (`objectbox_service.dart:51`, `:75–82`). (b) `changePin` re-hashes the PIN but never re-keys the PIN-derived encryption key, orphaning every encrypted draft and encrypted backup (`security_service.dart:325–348`); the crash-recovery guard for exactly this was declared and never written (`security_service.dart:67`, flagged `unused_field` by the analyzer). (c) `getJournalPage` paginates by **row id** while ordering by **date** (`native_storage_service.dart:135` vs `:143`), so backdated entries are skipped and others duplicated — and pagination is only ever *mocked*, never tested.

> **R3 — Nothing enforces any of this.**
> No CI pipeline exists. `flutter analyze` reports 74 issues that no gate blocks; a test file containing only a comment passes; `pointycastle` is imported directly by `pbkdf2.dart` but appears only under `dependency_overrides`, so a routine `pub upgrade` of an unrelated package can move the crypto primitive under every PIN in the app.

---

## 2. Standards Alignment Matrix

| Standard / Skill Guideline | Status | Evidence (File & Line) | Impact / Risk |
|---|---|---|---|
| **SKILL.md** — "Correctness of data over everything. Never ship a change that can corrupt or lose persisted data" | **Non-Compliant** | `objectbox_service.dart:51` renames the live DB to a backup dir on any open failure; `reinitializeAfterConsent` at `:75–82` ignores `backupPath` entirely | Transient open failure (Windows file lock, low disk) permanently orphans the user's journal. Total loss of the product's only asset |
| **SKILL.md** — "Migrations are expand → backfill → contract, each independently deployable and reversible" | **Non-Compliant** | `objectbox_service.dart:32–72`; dialog copy at `main.dart:176–180` tells the user "starting fresh" | The only "migration" is destroy-and-restart. No forward path, no rollback |
| **SKILL.md** — "No silent failure. An empty `catch` is a defect" | **Non-Compliant** | `encryption_service.dart:88` `} catch (_) {}`; `native_storage_service.dart:755` `} catch (_) {}` | Decryption failure is indistinguishable from plaintext; corrupt data renders as garbage with no signal |
| **SKILL.md** — "The codebase stays coherent... two dialects costs more than either saves" | **Non-Compliant** | `StorageService`/`BackupService`/`VaultSecurityService` use Riverpod providers; `SecurityService()` and `EncryptionService()` are hard singletons called directly from 8 UI sites (`lock_screen.dart:23`, `profile_screen.dart:96/120/217`, `pin_setup_screen.dart:20`, `pin_management_screen.dart:19`, `forgot_pin_screen.dart:18`, `entry_editor.dart:217`) | Two DI models. Security services are untestable without mutating a global (`security_service.dart:24`) |
| **SKILL.md** — "Evidence, not assertion" | **Compliant** | 107 tests pass; commit `80e42f5` documents root-cause analysis before the fix | Good practice; the gap is coverage placement, not honesty |
| **security-privacy.md** — "Authorize at the resource, not the route" | **Non-Compliant** | Vault unlock sets `_phase` in widget state (`privacy_vault_screen.dart:34`, `:53–56`); the query layer accepts `PrivacyFilter.all` from any caller with no unlock proof (`native_storage_service.dart:32–46`) | Elevation of privilege by construction. `backup_service.dart:47` and `renameTag`/`deleteTag` (`:308`, `:318`) all read vault contents without a passcode |
| **security-privacy.md** — "Use standard, vetted library primitives. Do not design your own scheme" | **Non-Compliant** | `_batchDecryptEntries` XOR loop at `native_storage_service.dart:751`; `_xorDecrypt` at `encryption_service.dart:249–255`; both live on the *read* path | A repeating-key XOR against a 32-byte key over English prose is trivially broken. It is labelled "legacy" but is still executed |
| **security-privacy.md** — "Rate limit... especially on unauthenticated, expensive paths" | **Non-Compliant** | `SecurityService.verifySecurityQuestions` (`security_service.dart:436–477`) and `VaultSecurityService.verifySecurityQuestions` (`vault_security_service.dart:269–300`) contain **no `_checkLockout()` call** | Recovery questions (2-of-3, low-entropy answers) are an unlimited-attempt bypass around the 5-attempt PIN lockout |
| **security-privacy.md** — "Tokens are long and compared in constant time" | **Partial** | `security_service.dart:231` `inputHash == storedHash`; `vault_security_service.dart:102`; answers at `:289` | Dart `String ==` short-circuits. Local-only attack surface, but the standard is explicit |
| **security-privacy.md** — "Encryption at rest... let the data class drive controls" | **Non-Compliant** | `objectbox_models.dart:23–27`, `:147–148` — "Plain text, no encryption"; `web_storage_service.dart:64` writes the whole journal to `localStorage` | The most sensitive data class in the app (private journal) gets the weakest control (none) |
| **security-privacy.md** — "URLs supplied by users are SSRF vectors: allowlist destinations, block internal ranges, disable redirects" | **Partial** | `image_service.dart:41–99`: allowlist exists but `userApproved: true` bypasses it (`:63`); `http://` permitted (`:52`); no internal-range/metadata block; `http.head` follows redirects by default | User-approved host can be `169.254.169.254` or an intranet address; HEAD-then-render is also a TOCTOU gap |
| **security-privacy.md** — "Pin versions with a lockfile... vet new dependencies" | **Non-Compliant** | `pbkdf2.dart:3–6` imports `pointycastle` directly; `pubspec.yaml` lists it only under `dependency_overrides` — analyzer raises `depend_on_referenced_packages` ×4 | The crypto library behind every PIN hash is transitive and unversioned by this project |
| **security-privacy.md** — "Never log... raw request bodies of sensitive endpoints" | **Partial** | 40 `debugPrint` sites; `security_service.dart:586` returns `'Biometric authentication failed: ${e.toString()}'` to the UI; `journal_screen.dart:254` puts `e.toString()` into user-visible `loadError` | Internals leak into user-facing strings. `debugPrint` is compiled out in release, so the log risk is low |
| **reliability-observability.md** — "Timeouts on everything" | **Partial** | `image_service.dart:71` has a 10s timeout (good). No timeout on `local_auth` (`security_service.dart:562`), on `compute()` PBKDF2, or on `CachedNetworkImage` fetches | Unbounded waits on the unlock path |
| **reliability-observability.md** — "Structured logs with a correlation id... RED metrics" | **Non-Compliant** | 40 bare `debugPrint` calls, no logger, no metrics; `main.dart:32` and `:37` both read `// TODO: forward to crash reporting` | Zero production observability. A crash in the field is invisible |
| **performance-efficiency.md** — "Unbounded result sets — every list query paginates" | **Partial** | Pagination exists (`getJournalPage`) but is bypassed by 6 full-table loads: `getOnThisDay` (`:180`), `getTagCounts` (`:289`), `renameTag` (`:308`), `deleteTag` (`:318`), `StatsNotifier.build` (`stats_provider.dart:12`), `journal_screen._loadFullSet` (`:266`) | Every filter keystroke, every stats refresh, and every tag operation decrypts and materializes the entire journal |
| **performance-efficiency.md** — "Work done per-request that could be done once" | **Non-Compliant** | `journal_screen.dart:346–354` runs `filterEntries` + `availableTags` on **every** `build()`; `image_widgets.dart:103–104` builds a new `Future` per frame | O(n·content-length) string lowercasing per repaint; gallery thumbnails re-fetched every rebuild |
| **testing-quality.md** — "Put the test at the level where the risk lives" | **Non-Compliant** | `test/storage_service_test.dart` covers only static pure helpers; `getJournalPage`, `saveJournalEntry`, `putManyJournalEntries` are **mock-only** (`root_orchestrator_test.dart:34–36`) | The pagination cursor bug (H-1) is invisible to the suite by construction |
| **testing-quality.md** — "A 'unit' test that mocks the database proves nothing" | **Non-Compliant** | `test/integration/pin_security_test.dart:16` mocks `FlutterSecureStorage` wholesale; `:29–31` stubs `attempt_count` to jump from 1 to 4 rather than exercising the counter | The file is named `integration/` but integrates nothing. The real increment path is untested |
| **testing-quality.md** — "No dead code, no unused exports" | **Non-Compliant** | `test/objectbox_service_test.dart` — 8 lines, empty `main()`, first-person comment, 3 unused imports; `original_storage_service.dart.txt` (28KB) tracked in git; `security_service.dart:67` unused field | A test file that tests nothing passes and inflates the green count |
| **testing-quality.md** — "A function does one thing at one level of abstraction" | **Non-Compliant** | `identity_screen.dart:927` `build()` = **395 lines**; `profile_screen.dart:317` = 382; `journal_viewer_screen.dart:177` = 302; `identity_screen.dart:286` `_showAddEditDialog` = 302; `calendar_screen.dart:514` = 292 | Unreviewable, untestable, unreusable |
| **testing-quality.md** — "Commits: subject in imperative mood, body explains why" | **Non-Compliant** | `48849cb` = "Here is a summary of the work accomplished:"; `b80e807` subject is a full ASCII table; `0ad81b3`/`5e4ea3f` = "Config changes" | History is unusable for bisecting or changelog generation |
| **stack-appendices.md §4 (Mobile)** — "Store the minimum locally; use the platform keychain for anything sensitive" | **Partial** | Credentials correctly in `FlutterSecureStorage`; journal content and the drafts index in plaintext ObjectBox / `localStorage` | Keychain used for the small secrets, not for the large ones |
| **stack-appendices.md §4** — "Respect the platform's lifecycle: process death and state restoration" | **Compliant** | `main.dart:141–156` documents a deliberate, reasoned cold-start-only lock policy; `main.dart:283–300` pauses animation on background | Exemplary — a decision recorded with its rationale and the rejected alternative |
| **stack-appendices.md §5** — "CI on every commit: build, lint, typecheck, test, security scan" | **Non-Compliant** | No `.github/`, no workflow file anywhere in the repo | Every other standard here is unenforced by construction |
| **design-judgment.md** Gate 1 — "Evidence of variation: two or more concrete existing cases" | **Partial** | `StorageService` has two real implementations — justified. But `image_service.dart:44` `trustedDomains` is **never passed by any caller** (`entry_editor.dart:1498`, `identity_screen.dart:1771` both omit it) while its doc at `:5` claims "Users can add/remove domains from app settings" | Speculative generality plus a comment that documents a feature that does not exist |
| **design-judgment.md** — "Rule of Three, applied honestly" | **Non-Compliant** | `computeStreak` implemented **three times**: `storage_service_interface.dart:185`, `native_storage_service.dart:614`, `stats_provider.dart:91`. `dedupeByEntryIdKeepingLast` twice (`:229`, `:275`); `applyTagRename`/`applyTagDelete` twice each | Evidence for extraction arrived twice over and was ignored both times |
| **design-judgment.md** — "Adding a boolean to a core function to serve one caller" | **Non-Compliant** | `backup_service.dart:169` `bool merge = true` — documented at `:166` as controlling replace-vs-merge, **never read in the body** | A flag that lies. A caller requesting "replace all" silently gets a merge |
| **design-judgment.md** — "Contract... breaking it breaks someone else" | **Non-Compliant** | `PaginationCursor.lastId` means an **ObjectBox row id** in `native_storage_service.dart:135` and an **array offset** in `web_storage_service.dart:105`, `:113` | One type, two incompatible meanings. The contract is unverifiable and untestable in the abstract |
| **lifecycle-gates.md** Stage 5 — "no unreferenced TODOs, no commented-out code" | **Partial** | `main.dart:32`, `:37` — unowned TODOs on the crash-reporting path; `original_storage_service.dart.txt` is 28KB of superseded code in git | Version control already remembers it |
| **stack-appendices.md §3** — "Every async surface handles loading, empty, error (with retry), success" | **Compliant** | `journal_screen.dart:490–509` handles all four; `:309–311` snackbar on page-load failure | Well done and consistently applied |
| **stack-appendices.md §3/§4** — Accessibility | **Partial** | `main.dart:423–426` `Semantics(button:, selected:, label:)` on nav; `main.dart:434–435` enforces 48dp targets; `Motion.reduceMotion` honored at `main.dart:275` | Genuinely good on the shell. Not evidenced on the 2,275-line `identity_screen` or the PIN keypad |
| **terminology.md** — "'Refactor'/'optimize'/'clean' used loosely" | **Partial** | Commit `8f7fff4` "Storage enhancement" — no metric, no target | Minor, but it is why the history cannot be read |

---

## 3. Deep-Dive Gap Analysis & Findings

### CRITICAL

---

#### C-1 · The Privacy Vault provides concealment, not confidentiality

**Location:** `lib/models/objectbox_models.dart:23–27, 47–50, 139–158` · `lib/screens/privacy_vault_screen.dart:32–56` · `lib/services/storage/web_storage_service.dart:63–65` · `lib/services/backup_service.dart:44–47`

**Observation.** The product's central feature is a passcode-gated vault. What actually exists:

```dart
// objectbox_models.dart:23-27 — the entity that backs a "vaulted" entry
/// Journal headline — stored as plain text (legacy encrypted data auto-decrypted).
String headline = '';
/// Journal content — stored as plain text (legacy encrypted data auto-decrypted).
String content = '';
...
/// Vaulted entries are hidden from all queries outside the Privacy Vault.
bool isPrivate = false;                                    // :50 — an ordinary column
```

```dart
// privacy_vault_screen.dart:34, 53-56 — the entire enforcement mechanism
_VaultPhase _phase = _VaultPhase.checking;
...
if (state == AppLifecycleState.paused && _phase == _VaultPhase.unlocked) {
  setState(() => _phase = _VaultPhase.locked);
}
```

The passcode gates a widget-state enum. The data is plaintext in `objectbox/data.mdb`. On web it is plaintext in `localStorage` (`web_storage_service.dart:64`). And an unencrypted export deliberately includes vaulted entries (`backup_service.dart:44–47`), producing a plain JSON file that is then handed to the OS share sheet (`:140`).

Worse, authorization is at the **route**, not the resource. `_privacyCondition` (`native_storage_service.dart:32–46`) will happily return vault contents to any caller passing `PrivacyFilter.all` — as `renameTag` (`:308`), `deleteTag` (`:318`) and `exportData` (`:47`) all do, none of which requires the vault passcode.

**Impact.** Anyone with device file access, an ADB backup, a synced app-data folder, or a shared unencrypted export reads every "private" entry. On web, any script on the origin reads them. The product makes a confidentiality promise its architecture cannot keep — the exact failure `security-privacy.md` calls out ("Broken object-level authorization is the most common serious API vulnerability") compounded by storing regulated-class data with no at-rest control.

**Remediation.** Encrypt vaulted fields at rest under a key derived from the *vault* passcode, and move the authorization check from the screen to the query.

```dart
// BEFORE — native_storage_service.dart:32
static Condition<ObjectBoxJournalEntry>? _privacyCondition(PrivacyFilter privacy) {
  switch (privacy) {
    case PrivacyFilter.excludePrivate: return ObjectBoxJournalEntry_.isPrivate.equals(false);
    case PrivacyFilter.onlyPrivate:    return ObjectBoxJournalEntry_.isPrivate.equals(true);
    case PrivacyFilter.all:            return null;
  }
}

// AFTER — authorization at the resource. Reading vault rows requires a capability
// token that only a successful passcode verification can mint.
static Condition<ObjectBoxJournalEntry>? _privacyCondition(
  PrivacyFilter privacy,
  VaultGrant? grant,
) {
  switch (privacy) {
    case PrivacyFilter.excludePrivate:
      return ObjectBoxJournalEntry_.isPrivate.equals(false);
    case PrivacyFilter.onlyPrivate:
    case PrivacyFilter.all:
      // Fail closed: no proof of unlock -> no vault rows, ever.
      if (grant == null || !grant.isValid) {
        throw const VaultLockedError('Vault rows require an unlocked VaultGrant');
      }
      return privacy == PrivacyFilter.onlyPrivate
          ? ObjectBoxJournalEntry_.isPrivate.equals(true)
          : null;
  }
}
```

```dart
// AFTER — objectbox_models.dart: vaulted content never lands in plaintext.
static Future<ObjectBoxJournalEntry> fromFreezed(
  JournalEntry entry, {
  required VaultCipher cipher,          // no-op cipher for non-private entries
}) async {
  final protect = entry.isPrivate ? cipher.seal : VaultCipher.identity;
  return ObjectBoxJournalEntry()
    ..entryId   = entry.id
    ..headline  = await protect(entry.headline)   // AES-256-GCM under the vault key
    ..content   = await protect(entry.content)
    ..feeling   = entry.feeling == null ? null : await protect(entry.feeling!)
    ..isPrivate = entry.isPrivate
    /* ...unchanged fields... */;
}
```

Also gate the export: `exportData()` must require the same `VaultGrant` before it may pass `PrivacyFilter.all`, and an unencrypted export must either exclude vaulted entries or refuse.

---

#### C-2 · A failed database open renames the user's journal away, permanently

**Location:** `lib/services/objectbox_service.dart:38–72, 74–82` · `lib/main.dart:169–201`

**Observation.**

```dart
// objectbox_service.dart:43-70
} catch (e, st) {
  debugPrint('ObjectBox init failed: $e\n$st');
  final timestamp  = DateTime.now().millisecondsSinceEpoch;
  final backupPath = '${dir.path}/objectbox_backup_$timestamp';
  try {
    if (await Directory(dbPath).exists()) {
      await Directory(dbPath).rename(backupPath);      // :51  <-- the user's DB, moved
    }
    ...
  }
  return ObjectBoxInitOutcome(InitResult.migrationRequired, backupPath: backupPath);
}
```

```dart
// objectbox_service.dart:75-82 — the "recovery"
static Future<void> reinitializeAfterConsent(String backupPath) async {
  // backupPath already moved away; just open a fresh store
  ...                                       // backupPath is never read again
}
```

`backupPath` is accepted as a parameter and never used. No code anywhere reads an `objectbox_backup_*` directory. The dialog (`main.dart:176–180`) calls this a "Database Security Upgrade" and offers only OK (wipe) or CANCEL (`SystemNavigator.pop()` — the app exits, `main.dart:199`). There is no third option and no path back to the data.

**Impact.** Any transient `openStore` failure — a Windows file lock (a documented hazard in this project's own build notes), a low-disk moment, an interrupted write — triggers an irreversible destructive branch. `SKILL.md`: *"Never ship a change that can corrupt, lose, or leak persisted data."* This also fails the two-way-door test in `design-judgment.md §5` and every clause of the expand→backfill→contract rule.

**Remediation.** Distinguish transient from structural failure, retry the transient case, and never move data you cannot put back.

```dart
// BEFORE — objectbox_service.dart:49-58 (destructive on any exception)
if (await Directory(dbPath).exists()) {
  await Directory(dbPath).rename(backupPath);
}

// AFTER
static Future<ObjectBoxInitOutcome> init() async {
  final dir    = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}/objectbox';

  // 1. Transient failures (lock contention, AV scanner, brief I/O error) are the
  //    common case on desktop. Retry with backoff before considering anything else.
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final store = await openStore(directory: dbPath);
      _instance = ObjectBoxService._()..store = store;
      await _seedDefaultsIfNeeded();
      return const ObjectBoxInitOutcome(InitResult.success);
    } on ObjectBoxException catch (e) {
      if (!_isTransient(e) || attempt == 2) {
        // 2. Structural failure: COPY, never rename. The original stays put so a
        //    later app version (or support) can still recover it.
        final rescuePath = '${dir.path}/objectbox_rescue_'
            '${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}';
        await _copyDirectory(Directory(dbPath), Directory(rescuePath));
        return ObjectBoxInitOutcome(
          InitResult.migrationRequired,
          backupPath: rescuePath,
          errorMessage: e.toString(),
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 200 * (1 << attempt)));
    }
  }
  throw StateError('unreachable');
}
```

and give the dialog a real third option — "Keep my old data and try again later" — that exits without touching `dbPath`.

---

#### C-3 · `changePin` orphans the encryption key; the guard against it was declared and never written

**Location:** `lib/services/security_service.dart:66–67, 217–234, 325–348`

**Observation.** Unlock derives **two independent** values from the PIN — the verification hash (salt `security_salt`) and the data-encryption key (salt `encryption_salt`):

```dart
// security_service.dart:223-234
final derived = await Future.wait([
  compute(pbkdf2Derive, {'pin': pin, 'salt': salt,    'iterations': 100000, 'keyLength': 32}),
  compute(pbkdf2Derive, {'pin': pin, 'salt': encSalt, 'iterations': 100000, 'keyLength': 32}),
]);
if (inputHash == storedHash) {
  _cachedEncryptionKey = derived[1];          // key is a pure function of (PIN, encSalt)
```

`changePin` updates only the first:

```dart
// security_service.dart:339-345
await _storage.delete(key: _pinHashKey);
final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
final hash = await _hashPin(newPin, salt);
await _storage.write(key: _pinHashKey, value: hash);
return PinVerificationResult(success: true);      // encryption_salt untouched; no re-key
```

After a PIN change the derived encryption key is different, so every artefact encrypted under the old key is unreadable: all drafts (`native_storage_service.dart:677` encrypts drafts on every autosave), every `.encrypted` backup file, and any legacy XOR-encrypted row. Nothing warns the user.

The author knew. `security_service.dart:66–67` declares the mitigation and stops there:

```dart
// Crash-recovery guard for PIN change re-key operation
static const String _rekeyPendingKey = 'rekey_pending';
```

`flutter analyze` flags it: `warning - The value of the field '_rekeyPendingKey' isn't used - lib\services\security_service.dart:67:23 - unused_field`. It is referenced nowhere else in `lib/` or `test/`.

**Impact.** Silent, unrecoverable loss of every encrypted artefact on a routine, user-initiated action. Also breaks `security-privacy.md`'s "Rotation must be possible without a code change."

**Remediation.** Break the dependency between the PIN and the data key. Derive a random Data Encryption Key once, and wrap it with a PIN-derived Key Encryption Key — then a PIN change re-wraps a 32-byte blob instead of re-encrypting the corpus, and is atomic.

```dart
// AFTER — security_service.dart
/// The DEK is random and permanent. The PIN only ever wraps it, so changing the
/// PIN re-wraps 32 bytes and can never orphan data. (Envelope encryption.)
Future<PinVerificationResult> changePin(String oldPin, String newPin) async {
  if (!_isValidPin(newPin)) {
    return PinVerificationResult(
      success: false,
      error: 'New PIN must be exactly ${SecurityConstants.pinLength} digits',
    );
  }
  final verify = await verifyPin(oldPin);
  if (!verify.success) return verify;

  final dek = _cachedEncryptionKey;                   // unwrapped by verifyPin
  if (dek == null) {
    return PinVerificationResult(success: false, error: 'Vault not unlocked');
  }

  final newPinSalt = _generateSalt();
  final newKekSalt = _generateSalt();
  final newHash    = await _hashPin(newPin, newPinSalt);
  final newKek     = await compute(pbkdf2Derive,
      {'pin': newPin, 'salt': newKekSalt, 'iterations': 100000, 'keyLength': 32});
  final rewrapped  = await AesGcm.wrap(dek, newKek);

  // Crash-recovery guard: if the process dies mid-write, the next launch sees the
  // journal and can complete or roll back instead of stranding the DEK.
  await _storage.write(key: _rekeyPendingKey, value: jsonEncode({
    'pinSalt': newPinSalt, 'kekSalt': newKekSalt,
    'hash': newHash,       'wrappedDek': rewrapped,
  }));
  await _storage.write(key: _saltKey,           value: newPinSalt);
  await _storage.write(key: _encryptionSaltKey, value: newKekSalt);
  await _storage.write(key: _wrappedDekKey,     value: rewrapped);
  await _storage.write(key: _pinHashKey,        value: newHash);
  await _storage.delete(key: _rekeyPendingKey);       // commit

  return PinVerificationResult(success: true);
}
```

Add `Future<void> completeInterruptedRekey()` to `initialize()` (`:108`) that replays or discards a pending journal entry.

---

#### C-4 · Repeating-key XOR is executed as a decryption primitive on the read path

**Location:** `lib/services/storage/native_storage_service.dart:736–768` · `lib/services/encryption_service.dart:94–109, 234–255`

**Observation.**

```dart
// native_storage_service.dart:741-757 — runs inside compute(), on every journal read
String decryptSync(String encryptedText) {
  if (encryptedText.isEmpty) return '';
  try {
    final combined = base64Decode(encryptedText);
    if (combined.length < 17) return encryptedText;
    final version = combined[0];
    if (version == 1) {
      final data   = combined.sublist(1);
      final result = Uint8List(data.length);
      for (int i = 0; i < data.length; i++) {
        result[i] = data[i] ^ key[i % key.length];        // :751 — repeating-key XOR
      }
      return utf8.decode(result, allowMalformed: true);
    }
  } catch (_) {}                                          // :755 — empty catch
  return encryptedText;
}
```

A 32-byte repeating key XOR'd against long-form English prose is broken by classical Kasiski/frequency analysis in seconds; `allowMalformed: true` guarantees it never even signals failure. `encryption_service.dart:88` and `:106` carry the same empty-catch pattern.

It is labelled "legacy, being phased out" (`encryption_service.dart:13`) — but there is **no migration that phases it out**. Version-1 rows are decrypted on read and, per `objectbox_models.dart:147–148`, rewritten as *plaintext* on the next save. The phase-out target is "no encryption at all."

**Impact.** Two distinct failures: a broken cipher presented as encryption, and two empty `catch` blocks that make cryptographic failure indistinguishable from success — a direct hit on `SKILL.md`'s "An empty `catch` is a defect."

**Remediation.** Migrate v1 rows once, explicitly, then delete the XOR code entirely.

```dart
// AFTER — a one-shot, resumable, idempotent migration; XOR exists only here.
/// Rewrites every version-1 (XOR) row as AES-256-GCM. Idempotent and resumable:
/// re-running after a crash is a no-op for rows already migrated.
Future<MigrationReport> migrateLegacyXorRows(Uint8List key) async {
  var migrated = 0, failed = 0;
  for (final row in _journalBox.getAll()) {
    if (!_isVersion1(row.headline)) continue;
    try {
      final plain = LegacyXor.decryptOrThrow(row.headline, key);   // throws, never swallows
      row.headline = await EncryptionService().encrypt(plain);
      _journalBox.put(row);
      migrated++;
    } on LegacyDecryptFailure catch (e, st) {
      failed++;
      _log.error('xor-migration: row ${row.entryId} unreadable', e, st); // surfaced, not swallowed
    }
  }
  return MigrationReport(migrated: migrated, failed: failed);
}
```

Then delete `_batchDecryptEntries`' XOR branch (`:747–754`), `_xorDecrypt` (`encryption_service.dart:249`), `_decryptXorSync` (`:95`), `_decryptLegacyXor` (`:201`) and `_decryptLegacyXorWithVersion` (`:235`).

---

### HIGH

---

#### H-1 · `getJournalPage` paginates by row id while ordering by date — entries are silently skipped and duplicated

**Location:** `lib/services/storage/native_storage_service.dart:123–145` (specifically `:133–135` vs `:142–143`)

**Observation.**

```dart
final cursorCond = cursor == null
    ? null
    : ObjectBoxJournalEntry_.id.lessThan(cursor.lastId);   // :135 — filters by ROW ID
...
final query = queryBuilder
    .order(ObjectBoxJournalEntry_.date, flags: Order.descending)   // :137 — orders by DATE
    .build()..limit = pageSize + 1;
...
final nextCursor = hasMore ? PaginationCursor.fromLastId(page.last.id) : null;  // :143
```

A cursor is only correct when it is derived from the *same* key the result set is ordered by. Here the ordering key is `date` and the cursor key is the ObjectBox auto-increment `id` (insertion order). Backdating is a first-class feature of this app — `EntryEditor` exposes `selectedDate` freely (`entry_editor.dart:291`) — so insertion order and date order routinely disagree.

Concretely: the user writes today about a trip last year. That entry gets a **high** id and an **old** date. Page 1 (20 newest by date) ends at some entry with id *N*. Page 2 asks for `id < N` ordered by date desc. The backdated entry has `id > N`, so it is **excluded from every subsequent page** — invisible forever. Meanwhile entries with low ids but recent dates satisfy `id < N` and re-sort to the top of page 2, so they **appear twice**.

`web_storage_service.dart:105, 113` uses the *same* `PaginationCursor` type to mean an array index — so the contract has two incompatible meanings and neither implementation can be validated against the other.

The suite cannot catch this: `getJournalPage` appears in the tests only as a Mockito stub (`test/widget/root_orchestrator_test.dart:34–36`, `test/backup_service_test.mocks.dart:104`). No test exercises either real implementation.

**Impact.** Silent data invisibility in the app's primary list — the worst failure class in `performance-efficiency.md` combined with a broken contract. Users conclude entries were lost.

**Remediation.** Make the cursor carry the ordering key, and make the type self-describing.

```dart
// BEFORE — models/paged_result.dart
class PaginationCursor {
  final int _lastId;
  const PaginationCursor.fromLastId(int id) : _lastId = id;
  int get lastId => _lastId;
}

// AFTER — the cursor names the sort key it belongs to. (date DESC, id DESC) is a
// total order, so it is stable across inserts and free of ties.
class PaginationCursor {
  final DateTime lastDate;
  final int lastId;              // tiebreaker for entries sharing a timestamp
  const PaginationCursor({required this.lastDate, required this.lastId});
}
```

```dart
// AFTER — native_storage_service.dart:133
final cursorCond = cursor == null
    ? null
    : ObjectBoxJournalEntry_.date.lessThan(cursor.lastDate.millisecondsSinceEpoch) |
      (ObjectBoxJournalEntry_.date.equals(cursor.lastDate.millisecondsSinceEpoch) &
       ObjectBoxJournalEntry_.id.lessThan(cursor.lastId));
...
final nextCursor = hasMore
    ? PaginationCursor(lastDate: page.last.date, lastId: page.last.id)
    : null;
```

Then add the regression test the standards require (`testing-quality.md`: "Every bug fix earns one"):

```dart
test('backdated entry inserted last still appears on a later page', () async {
  final svc = NativeStorageService(testStore);
  for (var i = 0; i < 25; i++) {
    await svc.saveJournalEntry(entry(id: '$i', date: DateTime(2026, 8, 24 - i)));
  }
  await svc.saveJournalEntry(entry(id: 'backdated', date: DateTime(2019, 1, 1)));

  final seen = <String>[];
  PaginationCursor? c;
  do {
    final page = await svc.getJournalPage(10, c);
    seen.addAll(page.items.map((e) => e.id));
    c = page.nextCursor;
  } while (c != null);

  expect(seen, contains('backdated'));               // fails before the fix
  expect(seen.toSet().length, seen.length);          // and no duplicates
});
```

---

#### H-2 · Security-question recovery bypasses rate limiting entirely

**Location:** `lib/services/security_service.dart:436–477, 496–527` · `lib/services/vault_security_service.dart:269–300, 304–322`

**Observation.** PIN verification opens with a lockout gate:

```dart
// security_service.dart:177-182
Future<PinVerificationResult> verifyPin(String pin) async {
  final lockoutResult = await _checkLockout();          // 5 attempts, then exponential backoff
  if (!lockoutResult.success) return lockoutResult;
```

`verifySecurityQuestions` — the *alternative* route to the same privilege — has no such gate:

```dart
// security_service.dart:436-465  (VaultSecurityService:269-292 is identical in shape)
Future<SecurityQuestionsResult> verifySecurityQuestions(List<String> answers) async {
  if (answers.length != 3) { ... }
  final questionsJson = await _storage.read(key: _securityQuestionsKey);
  final answersJson   = await _storage.read(key: _securityAnswersKey);
  ...
  int correctCount = 0;
  for (int i = 0; i < answers.length; i++) { ... }
  if (correctCount >= 2) return SecurityQuestionsResult(success: true);   // :468 — 2 of 3
```

No `_checkLockout()`, no `_handleFailedAttempt()`, no attempt counter. Success requires only **2 of 3** low-entropy answers (birth city, pet name), and `resetPinViaSecurityQuestions` (`:496`) then resets the PIN and calls `_resetAttempts(clearBackoff: true)` (`:524`) — clearing any lockout the attacker had accrued on the PIN path.

Two secondary weaknesses in the same code: all three answers are hashed under the **same** salt (`:418`, `:455`), so two identical answers produce identical stored hashes — leaking equality — and the comparison at `:462` is non-constant-time.

**Impact.** The 5-attempt lockout is decorative. An attacker with the device ignores the PIN and grinds the recovery questions without limit, then resets the PIN outright. `security-privacy.md`: *"Rate limit and apply resource quotas per principal... especially on unauthenticated, expensive, or fan-out endpoints."*

**Remediation.**

```dart
// AFTER — security_service.dart:436. One gate, shared by every credential path.
Future<SecurityQuestionsResult> verifySecurityQuestions(List<String> answers) async {
  // Recovery is a credential path: it shares the lockout budget with verifyPin so
  // an attacker cannot use it to route around the PIN backoff.
  final lockout = await _checkLockout();
  if (!lockout.success) {
    return SecurityQuestionsResult(success: false, error: lockout.error);
  }
  if (answers.length != 3) {
    return SecurityQuestionsResult(success: false, error: 'Must provide exactly 3 answers');
  }
  ...
  int correctCount = 0;
  for (int i = 0; i < answers.length; i++) {
    final salt   = await _answerSalt(i);                  // per-answer salt, not shared
    final hashed = await _hashPin(SecurityQuestions.normalizeAnswer(answers[i]), salt);
    if (constantTimeEquals(hashed, storedHashes[i] as String)) correctCount++;
  }

  if (correctCount >= 2) {
    await _resetAttempts(clearBackoff: true);
    return SecurityQuestionsResult(success: true);
  }
  await _handleFailedAttempt();                           // recovery failures cost attempts too
  return SecurityQuestionsResult(
    success: false,
    error: '$correctCount/3 answers correct. At least 2 required.',
    correctCount: correctCount,
  );
}
```

Apply the identical change to `vault_security_service.dart:269`. Better still, extract the shared lockout state machine (see H-5) so the fix lands once.

---

#### H-3 · `pointycastle` — the crypto behind every PIN — is not a declared dependency

**Location:** `lib/services/pbkdf2.dart:3–6` · `pubspec.yaml` (`dependency_overrides` block)

**Observation.** Every PIN hash, every vault passcode hash, and every derived encryption key in the app flows through:

```dart
// pbkdf2.dart:3-6
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
```

`pubspec.yaml` never lists `pointycastle` under `dependencies`. It appears only as:

```yaml
dependency_overrides:
  # Override to satisfy both encrypt and objectbox_generator
  pointycastle: ^4.0.0
```

`flutter analyze` reports this four times: `info - The imported package 'pointycastle' isn't a dependency of the importing package - lib\services\pbkdf2.dart:3:8 - depend_on_referenced_packages` (also `:4`, `:5`, `:6`).

**Impact.** The project imports a security primitive it does not declare. Its presence is a side effect of `encrypt`'s and `objectbox_generator`'s transitive graphs, held in place by an override whose stated purpose is conflict resolution — not dependency declaration. If `encrypt` is removed or its graph shifts, PIN hashing breaks or silently resolves to a different implementation. `security-privacy.md`: *"Pin versions with a lockfile; builds must be reproducible... A new dependency is a permanent liability and a Consequential decision."*

**Remediation.**

```yaml
# BEFORE — pubspec.yaml
dependencies:
  crypto: ^3.0.3
  encrypt: ^5.0.3 # AES-256-GCM encryption for journal data

dependency_overrides:
  # Override to satisfy both encrypt and objectbox_generator
  pointycastle: ^4.0.0

# AFTER — declare what you import. The override stays only to resolve the
# encrypt/objectbox_generator conflict, and it now overrides a *declared* dep.
dependencies:
  crypto: ^3.0.3
  encrypt: ^5.0.3
  # Direct dependency: PBKDF2-HMAC-SHA256 for all PIN and vault-passcode hashing
  # (lib/services/pbkdf2.dart). Version is load-bearing for credential security.
  pointycastle: ^4.0.0

dependency_overrides:
  pointycastle: ^4.0.0
```

---

#### H-4 · Undisposed `TextEditingController`s leak on every dialog open

**Location:** `lib/screens/pin_management_screen.dart:75, 165, 218, 219, 220, 278, 279` · `lib/screens/identity_screen.dart:88, 287, 289, 290, 1719` · `lib/screens/profile_screen.dart:137, 234`

**Observation.** `pin_management_screen.dart` creates **nine** controllers across its dialog methods and contains **zero** `.dispose()` calls anywhere in the file:

```dart
// pin_management_screen.dart:75
final answerControllers = List.generate(3, (_) => TextEditingController());
// :165
final pinController = TextEditingController();
// :218-220
final oldPinController     = TextEditingController();
final newPinController     = TextEditingController();
final confirmPinController = TextEditingController();
// :278-279
final answerControllers = List.generate(questions.length, (_) => TextEditingController());
final newPinController  = TextEditingController();
```

Each is created inside an `async` dialog method, handed to a `TextField`, and abandoned when the dialog pops. `identity_screen.dart` repeats the pattern at `:88`, `:287`, `:289`, `:290`, `:1719`, and `profile_screen.dart` at `:137` and `:234`. (`profile_screen.dart:83` shows the team *knows* the correct pattern — `controller.dispose()` after the dialog awaits — it is simply not applied consistently.)

**Impact.** Every `TextEditingController` is a `ChangeNotifier` that registers with the text-input connection. Leaked instances retain their listeners and text buffers for the process lifetime. In `pin_management_screen` the leaked buffers hold **PIN digits and security answers in plaintext heap memory indefinitely** — so this is a memory-hygiene *and* a secrets-lifetime defect.

**Remediation.**

```dart
// BEFORE — pin_management_screen.dart:218
Future<void> _showChangePinDialog() async {
  final oldPinController     = TextEditingController();
  final newPinController     = TextEditingController();
  final confirmPinController = TextEditingController();
  await showDialog(...);
  // controllers abandoned; PIN text stays in memory
}

// AFTER — dispose in a finally so it survives an early return or a throw.
// Clearing first drops the plaintext PIN from the buffer before release.
Future<void> _showChangePinDialog() async {
  final oldPinController     = TextEditingController();
  final newPinController     = TextEditingController();
  final confirmPinController = TextEditingController();
  try {
    await showDialog(...);
  } finally {
    for (final c in [oldPinController, newPinController, confirmPinController]) {
      c.clear();
      c.dispose();
    }
  }
}
```

---

#### H-5 · Credential logic is duplicated across two services; recovery-flow code is duplicated four times

**Location:** `lib/services/vault_security_service.dart:152–229` vs `lib/services/security_service.dart:243–322` · `security_service.dart:339–345, 356–359, 518–521, 568–571`

**Observation.** `VaultSecurityService._checkLockout` / `_handleFailedAttempt` / `_resetAttempts` / `getRemainingAttempts` / `isLockedOut` (`:152–229`) are a line-for-line reimplementation of `SecurityService._checkLockout` / `_handleFailedAttempt` / `_resetAttempts` / `getRemainingAttempts` / `isLockedOut` (`:243–322`), differing only in the storage key prefix. The file's own header comment claims it is "Deliberately much slimmer" (`:22`) — the lockout half is not slimmer, it is copied.

Within `SecurityService` alone, this four-line block appears **four** times:

```dart
await _storage.delete(key: _pinHashKey);
final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
final hash = await _hashPin(newPin, salt);
await _storage.write(key: _pinHashKey, value: hash);
```

at `:339–345` (`changePin`), `:356–359` (`resetPinDirectly`), `:518–521` (`resetPinViaSecurityQuestions`), and `:568–571` (`resetPinViaBiometric`). Note `changePin` alone omits the following `_resetAttempts(clearBackoff: true)` that the other three all call — a divergence already introduced by the copying.

**Impact.** `design-judgment.md §3` is explicit about when to share: *"Do share: ... auth and permission checks."* This is the exact category. The C-3 re-key fix must now be applied in four places; the H-2 lockout fix in two services. Copy-paste of a security state machine guarantees the next fix reaches some copies and not others — which has **already happened** with the missing `_resetAttempts` in `changePin`.

**Remediation.** Extract the state machine once and parameterize it by key namespace only.

```dart
// AFTER — lib/services/credential_gate.dart
/// Shared attempt-counting and escalating-lockout state machine.
///
/// Both the app-lock PIN and the Privacy Vault passcode are credential gates with
/// identical semantics and different key namespaces; they vary for the same
/// reason, so they share one implementation (design-judgment.md Gate 2).
class CredentialGate {
  CredentialGate({required FlutterSecureStorage storage, required String namespace})
      : _storage = storage, _ns = namespace;

  final FlutterSecureStorage _storage;
  final String _ns;
  String get _attemptCountKey      => '${_ns}attempt_count';
  String get _lockoutUntilKey      => '${_ns}lockout_until';
  String get _lockoutCycleCountKey => '${_ns}lockout_cycle_count';

  Future<GateDecision> checkLockout()  { /* was SecurityService:243-267 */ }
  Future<GateDecision> recordFailure() { /* was SecurityService:270-308 */ }
  Future<void> recordSuccess()         => _resetAttempts(clearBackoff: true);
  Future<int>  remainingAttempts()     { /* was SecurityService:385-389 */ }
}

// SecurityService:      _gate = CredentialGate(storage: _storage, namespace: '');
// VaultSecurityService: _gate = CredentialGate(storage: _storage, namespace: 'vault_');
```

Collapse the four PIN-write blocks into one `Future<void> _writeNewPin(String newPin)` — `VaultSecurityService._writeNewPasscode` (`:142–148`) already demonstrates the right shape.

---

#### H-6 · `merge` parameter is documented, accepted, and never read

**Location:** `lib/services/backup_service.dart:163–169`

**Observation.**

```dart
/// Import data from JSON string
///
/// [jsonString] - The JSON data to import
/// [merge] - If true, merge with existing data. If false, replace all.   // :166
Future<BackupResult> importFromJson(
  String jsonString, {
  bool merge = true,                                                       // :169
  BackupProgress? onProgress,
}) async {
```

`grep -n "merge" lib/services/backup_service.dart` returns exactly three hits: the doc comment (`:166`), the parameter declaration (`:169`), and an unrelated call to `_storageService.mergeVisionBoard` (`:245`). The parameter is never read in the 100-line body. `importFromJson` always merges — `putManyJournalEntries` (`:214`) is an upsert.

**Impact.** A caller writing `importFromJson(json, merge: false)` to restore a device to a known state gets a silent merge instead: stale local entries survive alongside the restored set. The API documents a data-destructive-vs-additive choice and honours neither. `testing-quality.md`: *"No dead code, no unused exports, no 'just in case' configuration."*

**Remediation.** Either implement it with the confirmation such an operation demands, or delete it. Given `design-judgment.md`'s Gate 1 (no evidence of a second case), **delete it**:

```dart
// AFTER — the contract now matches the behavior.
/// Import journal, rankings and vision boards from a backup document.
///
/// Semantics are always **upsert-by-id**: entries in [jsonString] overwrite local
/// entries with the same id; local entries absent from the backup are untouched.
/// A destructive "replace all" variant is deliberately not offered — see
/// `docs/adr/00XX-restore-is-always-a-merge.md`.
Future<BackupResult> importFromJson(
  String jsonString, {
  BackupProgress? onProgress,
}) async {
```

---

### MEDIUM

---

#### M-1 · `build()` recomputes the full filtered list and tag set on every frame

**Location:** `lib/screens/journal_screen.dart:337–354`

**Observation.**

```dart
@override
Widget build(BuildContext context) {
  ref.listen(journalRevisionProvider, (_, __) { _reload(); _loadOnThisDay(); });

  final filteredEntries = JournalScreen.filterEntries(       // :346 — O(n) with per-entry
    entries,                                                 //        toLowerCase() over
    query: _searchQuery,                                     //        full content
    spotlightOnly: _spotlightOnly,
    selectedTags: _selectedTags,
    selectedTypes: _selectedTypes,
    selectedMoods: _selectedMoods,
  );
  final availableTags = JournalScreen.availableTags(entries); // :354 — O(n·tags), builds a Map
```

Both run unconditionally on every `build()`. `build()` fires on each `_onScroll` threshold crossing (`:197`), each debounced keystroke (`:133`), each theme change, and each `_isSearching` toggle (`:447`). `filterEntries` allocates a lowercased copy of every headline, body, and tag per call (`:52–54`); with the full set loaded during filtering (`:266`) that is the entire journal, per frame.

The team already knows the right pattern — `CalendarScreen` precomputes `_entriesByDay` once in `_load()` (`calendar_screen.dart:62`) and `build()` just reads it.

**Impact.** Avoidable main-thread work proportional to total journal text on a scroll-driven surface. `performance-efficiency.md`: *"Work done per-request that could be done once."*

**Remediation.** Memoize on the inputs that actually change.

```dart
// AFTER — recompute only when entries or a filter actually changes.
List<JournalEntry> _filteredCache = const [];
List<String>       _tagsCache     = const [];
Object?            _filterKey;

void _recomputeDerived() {
  final key = Object.hash(entries.length, _searchQuery, _spotlightOnly,
      Object.hashAllUnordered(_selectedTags),
      Object.hashAllUnordered(_selectedTypes),
      Object.hashAllUnordered(_selectedMoods));
  if (key == _filterKey) return;
  _filterKey     = key;
  _filteredCache = JournalScreen.filterEntries(entries,
      query: _searchQuery, spotlightOnly: _spotlightOnly,
      selectedTags: _selectedTags, selectedTypes: _selectedTypes,
      selectedMoods: _selectedMoods);
  _tagsCache     = JournalScreen.availableTags(entries);
}

@override
Widget build(BuildContext context) {
  ref.listen(journalRevisionProvider, (_, __) { _reload(); _loadOnThisDay(); });
  _recomputeDerived();
  final filteredEntries = _filteredCache;
  final availableTags   = _tagsCache;
  ...
```

Also lift `ref.listen` out of `build()` — Riverpod tolerates it, but the reload side effect is easier to reason about registered once.

---

#### M-2 · `FutureBuilder` constructs its future inside `build()`, re-fetching thumbnails every frame

**Location:** `lib/widgets/image_widgets.dart:101–121`

**Observation.**

```dart
Widget _buildGalleryImage() {
  final cacheDim = _cacheDimension(context);
  return FutureBuilder<Uint8List?>(
    future: _loadGalleryThumbnail(cacheDim),   // :104 — new Future on EVERY rebuild
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingIndicator();
```

Each rebuild calls `_loadGalleryThumbnail` afresh, which does `AssetEntity.fromId` + `thumbnailDataWithSize` (`:125–131`) — a platform-channel round trip and a decode. Because a new future starts in the `waiting` state, the widget also **flashes its spinner** on every rebuild. Ironic given the surrounding code is otherwise careful about decode cost (`resolveCacheDimension`, `:36–50`).

`_loadGalleryThumbnail` also swallows every error into `null` (`:132–134`), so a revoked photo permission is indistinguishable from a missing asset.

**Impact.** Repeated platform-channel calls and image decodes on scroll; visible flicker. In a `ListView.builder` of image-bearing entries this multiplies per visible item.

**Remediation.**

```dart
// AFTER — create the future once per (asset, size), in initState/didUpdateWidget.
class _ImageThumbnailWidgetState extends State<ImageThumbnailWidget> {
  Future<Uint8List?>? _thumbFuture;
  int? _thumbDim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dim = _cacheDimension(context);
    // Rebuild the future only when the asset or the required decode size changes.
    if (dim != _thumbDim || _thumbFuture == null) {
      _thumbDim    = dim;
      _thumbFuture = _loadGalleryThumbnail(dim);
    }
  }

  @override
  void didUpdateWidget(covariant ImageThumbnailWidget old) {
    super.didUpdateWidget(old);
    if (old.imageRef.source != widget.imageRef.source) {
      _thumbFuture = _loadGalleryThumbnail(_thumbDim ?? 400);
    }
  }

  Widget _buildGalleryImage() => FutureBuilder<Uint8List?>(
        future: _thumbFuture,
        builder: (context, snapshot) { /* unchanged */ },
      );
}
```

---

#### M-3 · Enum ordinals are the persisted wire format in three hand-rolled serializers

**Location:** `lib/models/objectbox_models.dart:17–18, 29–30, 41–42, 77, 81, 91, 145, 149, 154` · `lib/services/backup_service.dart:72, 76, 80, 322, 326, 333` · `lib/screens/entry_editor.dart:171, 175, 178, 226, 233, 237`

**Observation.** `JournalEntry` gets a generated `toJson`/`fromJson` (`types.dart:81–82`, backed by `types.g.dart`), yet three separate hand-written serializers exist, all encoding enums by ordinal:

```dart
// objectbox_models.dart:145-154 (storage)
..typeIndex       = entry.type.index
..moodIndex       = entry.mood.index
..timeBucketIndex = entry.timeBucket?.index ?? -1

// backup_service.dart:72-80 (export)
'type': entry.type.index, 'mood': entry.mood.index, 'timeBucket': entry.timeBucket?.index,

// entry_editor.dart:171-178 (draft)
'type': type.index, 'mood': selectedMood.index, 'timeBucket': selectedBucket.index,
```

`Mood` has 13 values (`types.dart:6–20`). Inserting a mood anywhere but the end, or alphabetizing the list, silently reassigns the mood of **every stored entry, every backup file, and every draft**. Nothing in the codebase pins the ordinals.

Decoding is inconsistent about the same risk. `backup_service.dart:343–350` guards it properly:

```dart
T _safeEnumValue<T>(List<T> values, int? index, String fieldName) {
  if (index == null || index < 0 || index >= values.length) {
    throw FormatException('Invalid $fieldName value: $index ...');
  }
  return values[index];
}
```

while the storage and draft paths do not:

```dart
// objectbox_models.dart:77, 81, 91 — unguarded
type: EntryType.values[typeIndex],
mood: Mood.values[moodIndex],
timeBucket: timeBucketIndex >= 0 ? TimeBucket.values[timeBucketIndex] : null,

// entry_editor.dart:226, 233, 237 — unguarded, and inside a setState callback
type           = EntryType.values[draftData['type'] as int];
selectedMood   = Mood.values[draftData['mood'] as int];
selectedBucket = TimeBucket.values[draftData['timeBucket'] as int];
```

`objectbox_models.dart:85` compounds it: `List<String>.from(jsonDecode(tagsJson))` is unguarded, so one corrupt `tagsJson` row throws and fails the **entire** journal load.

**Impact.** A one-way-door data-model decision (`design-judgment.md §5`) taken implicitly, in triplicate, with no invariant protecting it. `stack-appendices.md §2`: *"Types matter: ... enums as constrained values."* The RangeError paths turn a single bad row into a total-load failure.

**Remediation.** Persist stable string names, and make one serializer the source of truth.

```dart
// types.dart — pin the wire format explicitly.
enum Mood {
  @JsonValue('euphoric')   euphoric,
  @JsonValue('happy')      happy,
  @JsonValue('productive') productive,
  /* ... */
}
```

```dart
// objectbox_models.dart — store the name, decode defensively.
// BEFORE
..moodIndex = entry.mood.index
mood: Mood.values[moodIndex],

// AFTER
..moodName = entry.mood.name          // migrate via expand -> backfill -> contract
mood: Mood.values.asNameMap()[moodName] ?? Mood.neutral,   // unknown -> safe default, logged
tags: _safeDecodeTags(tagsJson),      // one bad row must not fail the whole load
```

Then collapse the three serializers onto the generated `toJson`/`fromJson`, keeping only a thin ObjectBox column mapping. That also retires the four-places-to-edit hazard for new `JournalEntry` fields.

---

#### M-4 · Two dependency-injection dialects; security services are unmockable without a global mutation

**Location:** `lib/services/security_service.dart:19–27` · `lib/screens/lock_screen.dart:23`, `pin_setup_screen.dart:20`, `pin_management_screen.dart:19`, `forgot_pin_screen.dart:18`, `profile_screen.dart:96, 120, 217`, `entry_editor.dart:217`, `main.dart:47`

**Observation.** `StorageService`, `BackupService` and `VaultSecurityService` are all resolved through Riverpod (`storage_service.dart:25`, `backup_service.dart:494`, `vault_security_service.dart:15`). `SecurityService` and `EncryptionService` are not — they are singletons constructed at eight UI call sites. The test seam is a mutable static reassigned by a constructor:

```dart
// security_service.dart:19-27
static SecurityService _instance = SecurityService._internal(const FlutterSecureStorage());
factory SecurityService() => _instance;

@visibleForTesting
SecurityService.withStorage(FlutterSecureStorage storage) : _storage = storage {
  _instance = this;                                    // :24 — mutates global state
}
```

Every test that touches security must mutate process-global state (`test/integration/pin_security_test.dart:16`), and the mutation persists across tests in the same file — order-dependence that `testing-quality.md` explicitly forbids ("no shared mutable state between tests").

`EncryptionService` is worse: a `static final` singleton (`encryption_service.dart:16–18`) with no seam at all, reached directly from a widget (`entry_editor.dart:217`) and from the ObjectBox model layer (`objectbox_models.dart:59–61`), coupling the data model to a global.

**Impact.** Two dialects in one codebase — the coherence non-negotiable in `SKILL.md`. The consequence is concrete: the credential logic carrying findings C-3 and H-2 is the *hardest* code in the app to write a test for.

**Remediation.**

```dart
// AFTER — one dialect. Constructor injection, exposed through Riverpod.
class SecurityService {
  SecurityService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : _storage   = storage   ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();
  // no static _instance, no withStorage, no global mutation
}

final securityServiceProvider = Provider<SecurityService>((ref) => SecurityService());

// lock_screen.dart:23
// BEFORE: final _securityService = SecurityService();
// AFTER:  late final _securityService = ref.read(securityServiceProvider);

// Tests then override cleanly, with no cross-test bleed:
ProviderScope(overrides: [
  securityServiceProvider.overrideWithValue(SecurityService(storage: mockStorage)),
]);
```

`EncryptionService` needs the same treatment; `objectbox_models.dart:59–61` should take the cipher as a parameter rather than reaching for a global.

---

#### M-5 · A Riverpod provider lives inside the storage contract file

**Location:** `lib/services/storage/storage_service_interface.dart:16–25`

**Observation.** The file's own header states its purpose (`:5–6`): *"It deliberately avoids any ObjectBox or dart:ffi imports so it can be compiled for web."* It then imports `flutter_riverpod` and declares a UI-refresh provider:

```dart
// storage_service_interface.dart:16-25
final journalRevisionProvider =
    NotifierProvider<JournalRevisionNotifier, int>(JournalRevisionNotifier.new);

class JournalRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}
```

`journalRevisionProvider` is a presentation concern — a counter screens watch to know when to reload (`journal_screen.dart:340`, `privacy_vault_screen.dart:97`). It has nothing to do with the storage contract.

**Impact.** `design-judgment.md §3`: *"dependencies point from volatile to stable, and from specific to general... a shared primitive must never import a domain module."* The storage contract — the most stable thing in the app — now depends on the state-management library. Swapping Riverpod, or reusing `StorageService` in a CLI/isolate/test harness, drags the whole framework along.

**Remediation.** Move it to `lib/providers/journal_revision_provider.dart` and re-export from `providers.dart`. Zero behaviour change; the contract file loses its Riverpod import. Longer term, replace the counter with a `Stream<JournalChanged>` on `StorageService` so screens react to a domain event rather than polling a revision integer — that is the seam `design-judgment.md §4` recommends for persistence boundaries.

---

#### M-6 · Non-atomic read-modify-write on the draft index loses drafts

**Location:** `lib/services/storage/native_storage_service.dart:676–689, 699–709`

**Observation.**

```dart
Future<void> saveDraft(String draftId, String draftData) async {
  final encrypted = await EncryptionService().encrypt(draftData);
  await _draftStorage.write(key: 'draft_$draftId', value: encrypted);

  final existingDrafts = await getAllDraftIds();      // :681  READ
  if (!existingDrafts.contains(draftId)) {
    existingDrafts.add(draftId);                      //       MODIFY
    await _draftStorage.write(key: '_draft_keys_',    // :684  WRITE
        value: jsonEncode(existingDrafts));
  }
}
```

No lock, no compare-and-swap. `EntryEditor` autosaves on a timer (`entry_editor.dart:163`) and the Privacy Vault flow can trigger `_scheduleAutoSave()` concurrently (`:159`), so two `saveDraft` calls can interleave: both read the same list, both append their own id, the second write clobbers the first. `deleteDraft` (`:699–709`) has the identical race.

**Impact.** The orphaned draft blob stays in secure storage but disappears from the index, so `clearAllDrafts` (`:727`) never removes it — an unreachable, encrypted, un-garbage-collectable blob. `reliability-observability.md`: *"Read-modify-write without [optimistic locking or a transaction] is a lost-update bug that appears only under load."*

**Remediation.**

```dart
// AFTER — serialize index mutations through a single-entry queue.
// FlutterSecureStorage offers no CAS, so the mutex is the correct minimum.
final _draftIndexLock = Lock();   // package:synchronized

Future<void> saveDraft(String draftId, String draftData) async {
  final encrypted = await EncryptionService().encrypt(draftData);
  await _draftStorage.write(key: 'draft_$draftId', value: encrypted);
  await _draftIndexLock.synchronized(() async {
    final ids = await getAllDraftIds();
    if (ids.contains(draftId)) return;
    await _draftStorage.write(key: '_draft_keys_', value: jsonEncode([...ids, draftId]));
  });
}
```

---

#### M-7 · Image URL validation is bypassable and does not block internal ranges

**Location:** `lib/services/image_service.dart:41–99` · callers at `entry_editor.dart:1498`, `identity_screen.dart:1771`

**Observation.**

```dart
if (!uri.isScheme('http') && !uri.isScheme('https')) {          // :52 — http:// allowed
  return (false, 'URL must use http:// or https://');
}
final domains   = trustedDomains ?? defaultTrustedDomains;      // :57
final isTrusted = domains.any((d) => host == d.toLowerCase() || host.endsWith('.${d}'));
if (!isTrusted && !userApproved) {                              // :63 — full bypass
  return (false, 'Domain "$host" is not in trusted list. Approve manually?');
}
final response = await http.head(uri).timeout(const Duration(seconds: 10));   // :71
```

Four gaps: (1) `userApproved: true` skips the allowlist entirely — and the UI offers exactly that prompt; (2) no block on private/loopback/link-local ranges, so an approved host may be `169.254.169.254` (cloud metadata) or `10.0.0.1`; (3) `http.head` follows redirects by default, so an allowlisted host can redirect anywhere; (4) validation is HEAD-only and the render path (`CachedNetworkImage`, `image_widgets.dart:138`) re-fetches with no check — a TOCTOU gap.

Separately, `trustedDomains` (`:44`) is **never passed by any caller**, while `:5` documents "Users can add/remove domains from app settings." That feature does not exist — speculative generality plus a false comment (`design-judgment.md` Gate 1).

**Impact.** `security-privacy.md`: *"URLs supplied by users... are SSRF vectors: allowlist destinations, block internal ranges and metadata endpoints, disable redirects to new hosts."* Low severity for a local-first app with no server, but the mitigation is cheap and the code already pretends to do it.

**Remediation.**

```dart
// AFTER — the checks that actually stop SSRF, applied even to approved hosts.
Future<(bool, String?)> validateImageUrl(String url, {bool userApproved = false}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return (false, 'Invalid URL format');
  if (!uri.isScheme('https')) return (false, 'Images must be served over HTTPS');

  // Applies regardless of userApproved: manual approval is consent to a *domain*,
  // never consent to reach the loopback, LAN, or a cloud metadata endpoint.
  if (await _resolvesToPrivateRange(uri.host)) {
    return (false, 'That address is not reachable');            // generic to the user
  }
  final trusted = defaultTrustedDomains
      .any((d) => uri.host == d || uri.host.endsWith('.$d'));
  if (!trusted && !userApproved) {
    return (false, 'Domain "${uri.host}" is not in the trusted list. Approve manually?');
  }

  final client = http.Client();
  try {
    final req = http.Request('HEAD', uri)..followRedirects = false;  // no host hopping
    final res = await client.send(req).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return (false, 'Image is not available');
    /* content-type + content-length checks unchanged */
    return (true, null);
  } finally {
    client.close();
  }
}
```

Delete the unused `trustedDomains` parameter and the comment at `:5` that describes a feature that was never built.

---

#### M-8 · Ambient orb animation rebuilds and repaints the root stack at 60fps

**Location:** `lib/main.dart:257–260, 306–351` · `lib/widgets/glass_widgets.dart:161–181`

**Observation.**

```dart
_bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
  ..repeat(reverse: true);                       // :260 — always running while foregrounded
...
AnimatedBuilder(
  animation: _bgCtrl,
  builder: (ctx, child) {                        // :311 — no `child:` hoisting
    return Stack(children: [
      Positioned(top: -50 + (_bgCtrl.value * 20), left: -50,
        child: AnimatedOrb(width: 400, height: 400, ...)),      // rebuilt every frame
      ...
    ]);
  },
),
IndexedStack(index: _idx, children: _screens),   // :347 — sibling in the same Stack
```

Three `AnimatedOrb`s (each a 250–400px `Container` with a circular `BoxDecoration`, `glass_widgets.dart:174–180`) are reconstructed 60×/second and are **not** wrapped in a `RepaintBoundary` — so the orb layer shares a paint layer with the `IndexedStack` holding every screen. The team clearly understands the fix; `GlassContainer` applies `RepaintBoundary` around its `BackdropFilter` for exactly this reason (`glass_widgets.dart:83–90`).

Mitigations already present and good: the controller stops on background (`main.dart:292–294`) and honours reduced-motion (`:275–279`).

**Impact.** Continuous GPU work and unnecessary widget-tree churn on every screen, on battery, forever. `stack-appendices.md §4`: *"Battery, data, and thermal cost are user-visible."*

**Remediation.**

```dart
// AFTER — isolate the animated layer and hoist the static subtree out of the builder.
RepaintBoundary(
  child: AnimatedBuilder(
    animation: _bgCtrl,
    // The orbs never change; only their offsets do. Build them once and let the
    // builder reposition the prebuilt child.
    child: const _OrbCluster(),
    builder: (ctx, child) => Transform.translate(
      offset: Offset(0, _bgCtrl.value * 20),
      child: child,
    ),
  ),
),
```

---

### LOW

---

#### L-1 · 74 analyzer issues with no gate; 35 are missing `@override`

**Location:** whole repo; concentrated in `lib/services/storage/native_storage_service.dart:48–727`

**Observation.** `flutter analyze --no-pub` → **74 issues**:

| Rule | Count |
|---|---:|
| `annotate_overrides` | 35 |
| `unused_import` | 8 |
| `depend_on_referenced_packages` | 5 |
| `curly_braces_in_flow_control_structures` | 5 |
| `use_build_context_synchronously` | 4 |
| `override_on_non_overriding_member` | 4 |
| `unused_field` | 2 |
| `unnecessary_import` | 2 |
| `prefer_const_constructors` | 2 |
| `deprecated_member_use` | 2 |
| `dead_null_aware_expression` | 2 |
| others | 3 |

`NativeStorageService` has **zero** `@override` annotations across 35 interface implementations; `WebStorageService` has all 35. Two files suppress the lint wholesale rather than fixing it (`entry_editor.dart:1`, `vision_board_screen.dart:1` — `// ignore_for_file: use_build_context_synchronously`). The two `dead_null_aware_expression` warnings at `web_storage_service.dart:41–42` reveal a real misunderstanding: `decrypt` returns non-nullable `Future<String>`, so `decryptedHeadline ?? entry.headline` is dead code written under the belief that decryption could return null.

**Remediation.** Add the annotations (mechanical), delete the unused imports and `_rekeyPendingKey`/`_biometricStatus`, replace the two `ignore_for_file` directives with real `mounted` guards, and add the CI gate from Phase 1 so the count cannot climb again.

---

#### L-2 · A test file that tests nothing, and an "integration" test that integrates nothing

**Location:** `test/objectbox_service_test.dart` (whole file) · `test/integration/pin_security_test.dart:16, 29–31`

**Observation.**

```dart
// test/objectbox_service_test.dart — the complete file
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/objectbox_service.dart';
import 'dart:io';

void main() {
  // Testing ObjectBoxService.init() requires a real environment and path_provider mocking.
  // I will focus on unit testing the static logic if possible.
}
```

An empty `main()`, three unused imports (all flagged by the analyzer), and a first-person note left in the repo. It passes vacuously and inflates the green count. The one service it names is the one carrying finding C-2.

```dart
// test/integration/pin_security_test.dart:16, 29-31
securityService = SecurityService.withStorage(mockStorage);      // storage fully mocked
...
when(mockStorage.read(key: 'attempt_count')).thenAnswer((_) async => '1');
// ... simulate 4 more
when(mockStorage.read(key: 'attempt_count')).thenAnswer((_) async => '4');
```

Filed under `integration/`, it mocks the only component that can fail and *stubs the counter forward* rather than driving it — so the increment path it claims to test never executes. `testing-quality.md`: *"mocking away the thing that can fail tests only your mock."*

**Remediation.** Delete `objectbox_service_test.dart` or write it against a real temp-directory store. Rename `pin_security_test.dart` to `test/security_service_lockout_test.dart` (it is a unit test) and add a genuine integration test using a real `FlutterSecureStorage` on a temp path that drives five actual failures.

---

#### L-3 · Repository and commit hygiene

**Location:** `original_storage_service.dart.txt` (28KB, tracked) · `dayvault-technical-resume-breakdown.txt` (25KB, tracked) · git history

**Observation.** Both files are committed. The first is a superseded copy of a source file — `testing-quality.md`: *"Delete commented-out code. Version control remembers it."* Commit subjects include `48849cb` "Here is a summary of the work accomplished:", `b80e807` (a full ASCII table as the subject line), and `0ad81b3`/`5e4ea3f` both "Config changes". The two `// TODO: forward to crash reporting` notes at `main.dart:32` and `:37` have no owner and no issue reference — *"Every TODO has an owner and a reference, or it's not a TODO — it's litter."*

**Remediation.** `git rm` the two `.txt` artefacts. Adopt Conventional Commits (`feat:`/`fix:`/`refactor:`) with the *why* in the body. Convert the two TODOs into tracked issues and reference the id inline.

---

## 4. Architectural & Product Evolution Strategy

### What is genuinely good, and should be protected

Naming the strengths matters, because the remediation must not break them.

- **The platform seam is textbook.** `storage_service.dart:14–16` uses conditional imports so `NativeStorageService` and `WebStorageService` resolve at compile time with no runtime branching and no `dart:ffi` leaking into the web build. Two real implementations exist, so it clears `design-judgment.md` Gate 1 — this is a *seam*, not a framework, and it is exactly right.
- **Pure functions extracted for testability, deliberately.** `JournalScreen.filterEntries` (`:24`), `StatsNotifier.computeStats` (`:22`), `GlassContainer.clampBlur` (`:14`), `ImageThumbnailWidget.resolveCacheDimension` (`:36`) are all `static`, all documented as "exposed for testing", and all actually tested — including property-based tests over 0–500 randomized entries (`stats_provider_test.dart`). This is `testing-quality.md`'s "push side effects to the edges" done properly.
- **Decisions recorded with their rationale.** `main.dart:141–156` explains the auto-lock policy *and* the rejected alternative (`AppLifecycleState`) *and* the bug that rejection prevented. `main.dart:388–393` explains why `heightFactor: 1.0` is load-bearing. `design-judgment.md §7`: *"Recording the losing options matters more than recording the winner."* These comments are the single best thing in the codebase.
- **Performance work grounded in measurement.** Commit `80e42f5` documents root-cause analysis (two sequential 100k-iteration PBKDF2 passes) before the parallelization at `security_service.dart:223–228`. That is `performance-efficiency.md`'s "measure, then change" done right.

### The core structural problem: no domain layer

There are two layers, not three. Widgets talk directly to `StorageService`, and business rules live inside `build()` methods and dialog closures. `identity_screen.dart` is 2,275 lines with a 395-line `build()` (`:927`) and a 302-line dialog method (`:286`); `profile_screen.dart` is 1,518 lines with a 382-line `build()` (`:317`).

The tell is that domain logic is written **three separate times** because there is nowhere for it to live once: `computeStreak` at `storage_service_interface.dart:185`, `native_storage_service.dart:614`, and `stats_provider.dart:91`. That is not laziness — it is a missing layer. When there is no `JournalDomain`, streak logic ends up wherever it is first needed.

**Do not respond with cargo-cult layering.** `design-judgment.md §6` names it: *"Repository → service → controller with zero logic in two of them → Collapse until each layer earns its existence."* This app needs exactly **one** new layer, and only where logic actually exists:

```
lib/
  domain/                       <-- NEW: pure, no Flutter, no ObjectBox, no Riverpod
    journal/
      streak.dart               computeStreak — one implementation, deleting three
      entry_filter.dart         filterEntries + availableTags (moved from JournalScreen)
      tag_operations.dart       applyTagRename / applyTagDelete (moved from the two copies)
      stats.dart                computeStats (moved from StatsNotifier)
    vault/
      vault_grant.dart          the capability token from C-1
  services/                     I/O boundary only — no business rules
  providers/                    orchestration, all DI (M-4, M-5 land here)
  screens/                      presentation; no rule may live here
```

Everything in `domain/` is a pure function over data with no imports outside `dart:core` and `models/`. It is trivially testable, and the "extract a static for testing" pattern already sprinkled through the screens becomes the default rather than an exception.

### Feature modularity: what it costs to add a feature today

Concretely, adding one field to `JournalEntry` requires edits in **five** places: `types.dart`, `ObjectBoxJournalEntry.fromFreezed` + `toFreezedFromDecrypted` (`objectbox_models.dart:140`, `:71`), `BackupService._serializeEntry` + `_deserializeEntry` (`:69`, `:319`), `EntryEditor._saveDraft` + `_loadDraft` (`:169`, `:222`), and `WebStorageService` (which uses generated JSON, so it diverges from all of the above). Miss one and the field silently vanishes from backups, or from drafts, or from web.

Collapsing all of these onto the generated `toJson`/`fromJson` (M-3) reduces that to one edit plus a column mapping. This is the highest-leverage maintainability change available and it costs a day.

### Extensibility: seams to add, frameworks to avoid

`design-judgment.md §4` — *"Build seams freely. Build frameworks only with evidence and a named owner."*

**Add these seams** (each cheap, each pays for itself immediately):

| Seam | Where | Unlocks |
|---|---|---|
| `Clock` interface | replace 8 direct `DateTime.now()` calls (`storage_service_interface.dart:195`, `stats_provider.dart:25`, `security_service.dart:253`, `objectbox_service.dart:47`, …) | Deterministic streak/lockout tests without `fake_async` gymnastics |
| `IdGenerator` | replace `const Uuid().v4()` (`native_storage_service.dart:519`) | Reproducible fixtures |
| `VaultCipher` | injected into `ObjectBoxJournalEntry.fromFreezed` | Makes C-1 implementable and testable |
| `AppLogger` | replace 40 `debugPrint` calls | Structured logs + the crash reporting both TODOs ask for |
| `Stream<JournalChanged>` | replace `journalRevisionProvider` | Removes M-5's inverted dependency; screens react to a domain event |

**Explicitly do not build:** a plugin system for storage backends (two is not three), a generalized migration framework (write the one migration M-3 needs), or a rules engine for privacy filters (three enum cases are three cases).

### The reusability question, answered honestly

`design-judgment.md §3` requires four properties before promoting code to shared status: stability, single meaning, no hidden context, an owner.

`SecurityService` and `VaultSecurityService` **pass all four** for their lockout state machine (H-5): it is stable, it means precisely one thing, it depends only on injected storage, and it has one obvious owner. Extract it.

`GlassContainer` also passes and is already correctly shared.

`filterEntries` currently lives on `JournalScreen` as a `static`. It passes too — but it should move to `domain/journal/entry_filter.dart` rather than stay attached to a widget class, so the vault screen and calendar can use it without importing a screen.

Counter-example — what **not** to share: the near-identical PIN-confirmation dialogs at `profile_screen.dart:119–199` and `:216–~300`. They look alike today but they gate *opposite* operations (enable vs. disable security) and will diverge the moment either grows step-up auth or a different warning. That is `design-judgment.md` Gate 2 (coincidental duplication): extract only the shared `PinConfirmField` *widget*, keep the two flows separate.

### Reversibility ledger

| Decision | Door | Current state |
|---|---|---|
| Enum ordinals as the persisted format (M-3) | **One-way** | Taken implicitly, in triplicate, unprotected. Fix now — it only gets more expensive per user |
| `PaginationCursor` semantics (H-1) | **One-way**-ish | Two incompatible meanings already shipped. Fix before the cursor is persisted anywhere |
| Plaintext-at-rest for vault entries (C-1) | **One-way** | Migrating plaintext→encrypted needs an expand→backfill→contract pass. Cost grows with corpus size |
| PIN-derived DEK with no envelope (C-3) | **One-way** | Every day this ships, more users hit the change-PIN loss path |
| ObjectBox as the datastore | Two-way | Well-insulated behind `StorageService`. Leave it |
| Riverpod as the state library | Two-way | Except where it leaked into the contract file (M-5). Fix that leak and it stays two-way |
| Glass/orb visual language | Two-way | Token-driven (`theme/app_tokens.dart`). Cheap to change |

The pattern: **every one-way door in this codebase was walked through without being noticed.** The single most valuable process change is to name them before implementing — `design-judgment.md §5` costs one paragraph per decision.

---

## 5. Prioritized Remediation Roadmap (Action Plan)

Tiers per `SKILL.md`'s "Applying the bar proportionally". Each phase is independently shippable; nothing here is a big-bang.

### Phase 1 — Critical Stability & Compliance (Weeks 1–3)

*Goal: no live path can silently lose or expose user data; the standards become enforceable.*

| # | Action | Finding | Tier | Verification (evidence required) |
|---|---|---|---|---|
| 1.1 | **Add CI** — `.github/workflows/ci.yml` running `flutter analyze --fatal-infos`, `flutter test`, `dart format --set-exit-if-changed` on every push | R3, L-1 | Standard | Pipeline green on a PR; a deliberately-introduced lint fails the build |
| 1.2 | Declare `pointycastle` in `dependencies` | H-3 | Consequential | `flutter analyze` shows 0 × `depend_on_referenced_packages` |
| 1.3 | Make DB-open failure non-destructive: retry transient, **copy** never rename, add a "keep my data" dialog option | C-2 | Consequential | Test: simulated lock → retry succeeds; simulated corruption → original `dbPath` still exists on disk after the flow |
| 1.4 | Fix `getJournalPage` cursor to `(date, id)` in both implementations; unify `PaginationCursor` semantics | H-1 | Consequential | The backdated-entry regression test in §H-1 — confirmed **red** before the fix, green after |
| 1.5 | Gate `verifySecurityQuestions` behind the lockout in both services; per-answer salts; constant-time compare | H-2 | Consequential | Test: 6 wrong answer-sets → 6th returns a lockout, not a result |
| 1.6 | Envelope encryption — random DEK wrapped by a PIN-derived KEK; implement the `rekey_pending` journal | C-3 | Consequential | Test: encrypt → `changePin` → decrypt succeeds. Test: kill mid-rekey → next `initialize()` recovers |
| 1.7 | Dispose every dialog-scoped controller in a `finally`; clear PIN buffers first | H-4 | Standard | Widget tests assert no `TextEditingController` leak after dialog dismissal |
| 1.8 | Replace both empty `catch (_) {}` blocks with logged, typed failures | C-4 (part) | Standard | `grep -rn "catch (_) {}" lib/` returns nothing |
| 1.9 | Delete the unused `merge` parameter; make `_rekeyPendingKey` live via 1.6 | H-6, L-1 | Trivial | Analyzer `unused_field` count = 0 |

**Exit gate:** `flutter analyze` clean at `--fatal-infos`; new regression tests demonstrably fail without their fix; CI blocks merge.

---

### Phase 2 — Architectural Refactoring (Weeks 4–9)

*Goal: the vault becomes real; one DI dialect; one home for domain logic.*

| # | Action | Finding | Tier | Verification |
|---|---|---|---|---|
| 2.1 | **Encrypt vaulted entries at rest** under a vault-passcode-derived key; expand→backfill→contract migration | C-1 | **Foundational** — needs an ADR with alternatives | Test: vaulted row's `headline` column is not readable as plaintext. Migration test on a populated fixture DB, run twice (idempotent) |
| 2.2 | Introduce `VaultGrant`; move authorization from the screen to `_privacyCondition`; **fail closed** | C-1 | Consequential | Test: `getJournal(privacy: all)` without a grant **throws**. Test: `exportData` without a grant excludes vaulted entries |
| 2.3 | One-shot XOR→AES migration; then delete all five XOR code paths | C-4 | Consequential | `grep -rn "\^ key\[" lib/` returns nothing outside the migration. Migration test with a v1 fixture |
| 2.4 | Move all enum persistence to stable string names; expand→backfill→contract | M-3 | Consequential | Test: reorder `Mood` in a fixture → existing rows still decode correctly |
| 2.5 | Collapse the three hand-rolled serializers onto generated `toJson`/`fromJson` | M-3 | Standard | Test: add a field to `JournalEntry` → it round-trips storage, backup and draft with no extra edits |
| 2.6 | Unify DI — constructor injection + providers for `SecurityService` and `EncryptionService`; delete `withStorage` | M-4 | Consequential | `grep -rn "SecurityService()" lib/screens/` returns nothing. Tests use `ProviderScope(overrides:)` only |
| 2.7 | Extract `CredentialGate`; both services delegate | H-5 | Standard | One lockout test suite covers both namespaces |
| 2.8 | Create `lib/domain/`; move `computeStreak` (delete 2 copies), `computeStats`, `filterEntries`, tag ops | §4 | Standard | `grep -rn "computeStreak" lib/` shows exactly one definition |
| 2.9 | Move `journalRevisionProvider` out of the contract file | M-5 | Trivial | `storage_service_interface.dart` no longer imports `flutter_riverpod` |
| 2.10 | Serialize draft-index mutations behind a lock | M-6 | Standard | Concurrency test: 50 parallel `saveDraft` calls → index contains all 50 ids |

**Exit gate:** vaulted content is unreadable in a raw DB dump; a single DI dialect; `domain/` imports nothing from Flutter.

---

### Phase 3 — Performance, Scalability & Test Depth (Weeks 10–14)

*Goal: budgets stated and met; tests where the risk actually lives.*

| # | Action | Finding | Tier | Verification |
|---|---|---|---|---|
| 3.1 | Memoize `filterEntries`/`availableTags` outside `build()` | M-1 | Standard | DevTools timeline: `build()` cost flat while scrolling a 1,000-entry journal |
| 3.2 | Hoist the `FutureBuilder` future out of `build()` | M-2 | Standard | Test: rebuilding the widget 10× triggers exactly one `thumbnailDataWithSize` call |
| 3.3 | `RepaintBoundary` + `child:` hoisting on the orb layer | M-8 | Trivial | `debugRepaintRainbowEnabled` shows the screen layer no longer repainting per frame |
| 3.4 | Replace the 6 unbounded `getJournal()` calls with bounded/aggregate queries | Matrix row | Standard | Query-count / row-count assertions; `getTagCounts` no longer materializes the corpus |
| 3.5 | **Integration tests against a real ObjectBox store** covering `saveJournalEntry`, `putManyJournalEntries`, `getJournalPage`, privacy filters, tag ops | L-2, H-1 | Consequential | Both storage implementations exercised for real, not mocked |
| 3.6 | Delete `test/objectbox_service_test.dart`; move `pin_security_test.dart` out of `integration/`; write a real one | L-2 | Trivial | No test file has an empty `main()` |
| 3.7 | Harden `validateImageUrl` (HTTPS-only, private-range block, no redirects); delete the unused `trustedDomains` param | M-7 | Standard | Tests: `169.254.169.254` rejected even when `userApproved: true`; redirect to a new host rejected |
| 3.8 | Introduce `AppLogger`; replace 40 `debugPrint` calls; wire the two crash-reporting TODOs | Matrix row | Standard | `grep -rn "debugPrint" lib/` returns nothing; a forced crash appears in the reporter |
| 3.9 | Decompose the 5 `build()` methods over 250 lines into named widget classes | §4 | Standard | No `build()` over 80 lines; widget tests target the extracted components |
| 3.10 | Repo hygiene: `git rm` the two stray `.txt` files; adopt Conventional Commits | L-3 | Trivial | `git ls-files \| grep "\.txt$"` returns only `CMakeLists.txt` entries |
| 3.11 | State NFR budgets in `CONTRIBUTING.md` (cold start, unlock latency, list scroll p95) and assert them in CI | `performance-efficiency.md` | Standard | Budgets documented and CI-enforced |

**Exit gate:** stated budgets met on a 1,000-entry corpus; both storage implementations covered by real integration tests; observability sufficient to diagnose a field crash without shipping code.

---

### Sequencing rationale

Phase 1 is ordered by `design-judgment.md §5` — **irreversibility first**. Every day the enum-ordinal format (M-3) and the PIN-derived DEK (C-3) stay shipped, the migration gets more expensive per user. CI comes first of all because without it Phase 2 and 3 regressions land silently, and the analyzer count climbs straight back to 74.

Phase 2's item 2.1 is the only **Foundational**-tier change here and it is the one that should not be started without a written decision record (`design-judgment.md §7`: decision / context / alternatives / consequences). The alternative worth writing down and rejecting explicitly: encrypting the *whole* database via ObjectBox's encrypted-store support, rather than field-level encryption for vaulted rows only. It is simpler, but it puts every read behind the PIN and would break the app's deliberate cold-start-only unlock policy documented at `main.dart:141–156` — which is a good policy and should not be sacrificed silently.

---

*Audit performed by static analysis of every file in `lib/` and `test/`, plus `flutter analyze --no-pub` (74 issues) and `flutter test --no-pub` (107 passing) executed against commit `8f7fff4`. No source files were modified. Every line reference was verified against the working tree at audit time.*
