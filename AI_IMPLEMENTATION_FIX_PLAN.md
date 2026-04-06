# DayVault AI Implementation Fix Plan

**Date**: 2026-04-05  
**Scope**: Fix AI/Gemma functionality, remove GGUF dead code, harden vulnerabilities  
**Priority**: Critical → High → Medium → Low

---

## Executive Summary

After thorough analysis of all code files, I've identified **31 issues** across security, resource management, error handling, and architectural inconsistencies. The most critical findings:

1. **XOR encryption is trivially breakable** — all journal data is effectively unprotected
2. **GGUF code is fully intact but dead** — ~800+ lines, 15MB native libs, zero UI access
3. **Gemma service has resource leaks** — `InferenceChat` never closed
4. **RAG pipeline is dormant** — vector embeddings never processed
5. **Silent plaintext fallback on encryption failure** — data stored unencrypted without warning

This plan provides a phased approach to fix critical vulnerabilities first, then clean up dead code, then harden the AI implementation.

---

## Phase 1: CRITICAL Security Fixes (MUST DO)

### 1.1 Replace XOR Cipher with AES-GCM

**Severity**: CRITICAL  
**Files**: `lib/services/encryption_service.dart`  
**Problem**: XOR with predictable IV is broken in seconds  
**Impact**: All journal entries are effectively plaintext

**Implementation**:

```dart
// Add to pubspec.yaml:
dependencies:
  encrypt: ^5.0.3
  pointycastle: ^3.7.3

// New encryption_service.dart:
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'security_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final SecurityService _securityService = SecurityService();

  Future<Uint8List> _getDerivedKey() async {
    final key = await _securityService.getEncryptionKey();
    if (key == null || key.length < 32) {
      throw StateError('Encryption key not available or too short');
    }
    return key.sublist(0, 32); // Ensure exactly 32 bytes for AES-256
  }

  Future<String?> encrypt(String plainText) async {
    if (plainText.isEmpty) return plainText;

    try {
      final keyBytes = await _getDerivedKey();
      final key = encrypt.Key(keyBytes);
      
      // Generate cryptographically secure random IV
      final iv = encrypt.IV.fromSecureRandom(16);
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // Combine IV + ciphertext + authentication tag
      final combined = Uint8List.fromList([
        ...iv.bytes,
        ...encrypted.bytes,
        ...encrypted.mac.bytes, // GCM authentication tag (16 bytes)
      ]);
      
      return base64Encode(combined);
    } catch (e, st) {
      // NEVER fallback to plaintext — throw instead
      debugPrint('Encryption failed: $e\n$st');
      rethrow;
    }
  }

  Future<String> decrypt(String? encryptedText) async {
    if (encryptedText == null || encryptedText.isEmpty) {
      return '';
    }

    try {
      final combined = base64Decode(encryptedText);
      
      // Extract IV (16 bytes) + ciphertext + tag (16 bytes)
      if (combined.length < 32) {
        throw FormatException('Encrypted data too short');
      }
      
      final ivBytes = combined.sublist(0, 16);
      final tagBytes = combined.sublist(combined.length - 16);
      final cipherBytes = combined.sublist(16, combined.length - 16);
      
      final iv = encrypt.IV(ivBytes);
      final keyBytes = await _getDerivedKey();
      final key = encrypt.Key(keyBytes);
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      
      final encrypted = encrypt.Encrypted(
        Uint8List.fromList([...cipherBytes, ...tagBytes]),
      );
      
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      // On decryption failure, throw — never return corrupted data
      debugPrint('Decryption failed: $e');
      rethrow;
    }
  }
}
```

**Migration Strategy**:
1. Add version field to journal entries to track encryption scheme
2. On first successful decrypt with AES, mark entry as `encryptionVersion: 2`
3. Keep backward compat: if decrypt fails with AES, try old XOR method (one-time migration)
4. After migration period (e.g., 30 days), remove XOR fallback

---

### 1.2 Fix Key Derivation Function

**Severity**: HIGH  
**Files**: `lib/services/security_service.dart`  
**Problem**: `_pbkdf2Hash` uses max 100 iterations, not 100,000; key uses ASCII hex chars only  
**Impact**: Effective key space reduced from 2^256 to 2^128

**Implementation**:

```dart
// In security_service.dart:

/// Generate encryption key from PIN — FIXED version
Future<Uint8List> _deriveEncryptionKey(String pin) async {
  final salt = await _storage.read(key: _saltKey) ?? _generateSalt();
  
  // Use proper key derivation with full binary output
  final derivedKey = await compute(
    _deriveKeyBinary,
    {'pin': pin, 'salt': salt, 'iterations': 100000},
  );
  
  return Uint8List.fromList(derivedKey);
}

// Isolate function — proper HKDF-like derivation
List<int> _deriveKeyBinary(Map<String, dynamic> params) {
  final pin = params['pin'] as String;
  final salt = params['salt'] as String;
  final iterations = params['iterations'] as int;
  
  // PBKDF2-like with full binary output (not hex string)
  var derivedKey = utf8.encode(salt);
  
  for (int i = 0; i < iterations; i++) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final digest = hmac.convert(derivedKey);
    derivedKey = digest.bytes;
  }
  
  return derivedKey; // 32 bytes of entropy
}

// Fix _generateSalt to use cryptographically secure random
String _generateSalt() {
  final random = Random.secure();
  final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Encode(saltBytes);
}
```

---

### 1.3 Remove Silent Plaintext Fallback

**Severity**: HIGH  
**Files**: `lib/services/encryption_service.dart`  
**Problem**: Encryption failures silently store plaintext  
**Impact**: Data loss of security posture without user knowledge

**Implementation**: Covered in 1.1 — `rethrow` instead of returning plaintext. Add user-facing error dialog if encryption fails during save.

---

## Phase 2: Remove GGUF Dead Code (HIGH PRIORITY)

### 2.1 Remove GGUF Service Files

**Severity**: MEDIUM (reduces APK size, attack surface, maintenance burden)  
**Files to DELETE**:
- `lib/services/llama_runtime_service.dart`
- `lib/services/ai_runtime_policy_service.dart`
- `lib/services/ai_model_registry_service.dart`
- `GGUF_REFERENCE.md`

**Rationale**: These files have NO UI access, are not called from any active code path, and add 15MB+ to APK size. If needed later, they're in Git history.

---

### 2.2 Clean RAG Service

**Severity**: MEDIUM  
**File**: `lib/services/rag_service.dart`  
**Changes**:

1. **Remove GGUF imports**:
```dart
// REMOVE these imports:
import '../services/llama_runtime_service.dart';
import '../services/ai_runtime_policy_service.dart';
```

2. **Remove GGUF runtime instance**:
```dart
// REMOVE:
final LlamaRuntimeService _runtime = LlamaRuntimeService.instance;
```

3. **Simplify `ask()` method** — Remove GGUF fallback:
```dart
Stream<String> ask(String userQuery) async* {
  final contexts = await retrieveContext(userQuery);
  final ragPrompt = _buildPrompt(userQuery, contexts);
  final runtimeConfig = await _storage.getAiRuntimeConfig();

  // Only AICore path — remove GGUF fallback entirely
  if (Platform.isAndroid) {
    try {
      final ready = await _aicoreService.ensureReady(
        autoDownload: runtimeConfig.aicoreAutoDownload,
      );
      if (!ready) {
        throw StateError(
          'Android AICore model is not ready on this device. '
          'Open AI Settings to check availability/download status.',
        );
      }

      final text = await _aicoreService.generate(
        ragPrompt,
        temperature: 0.6,
        topK: 32,
        maxOutputTokens: runtimeConfig.maxGenerationTokens > 0
            ? runtimeConfig.maxGenerationTokens
            : AiConstants.chatMaxOutputTokens,
      );
      yield text;
      return;
    } catch (e, st) {
      debugPrint('AICore generation failed: $e\n$st');
      rethrow; // No fallback — throw to caller
    }
  } else {
    throw StateError(
      'AI generation requires a supported platform. '
      'Android AICore is required for AI features.',
    );
  }
}
```

4. **Remove `_resolveModelPath()`** — No longer needed without GGUF
5. **Remove GGUF embedding path from `_processNextJob()`** — Keep only AICore embedding or mark as AICore-only

**Note**: If RAG is not being used at all (current state), consider deleting `rag_service.dart` entirely and removing RAG imports from `ai_assistant_screen.dart`.

---

### 2.3 Update pubspec.yaml

**Remove these dependencies**:
```yaml
# REMOVE:
llamadart: ^0.6.7
system_info2: ^4.1.0  # Only used by GGUF policy service
file_picker: ^10.3.2  # If only used for GGUF import (check other usage)
```

**Keep**:
```yaml
flutter_gemma: ^0.12.8  # Primary AI engine
battery_plus: ^7.0.0    # Still used elsewhere? (check)
device_info_plus: ^12.3.0  # Still used elsewhere? (check)
```

---

### 2.4 Clean ObjectBox Models (Optional — Requires Migration)

**File**: `lib/models/objectbox_models.dart`

**Fields to REMOVE from `ObjectBoxAiRuntimeConfig`**:
```dart
// Remove GGUF-specific fields:
int backendIndex = 0;
bool autoPolicy = true;
int forcedContextSize = 0;
int forcedThreads = 0;
int forcedGpuLayers = -1;
int maxGenerationTokens = 0;
bool pauseEmbeddingOnLowBattery = true;
int lowBatteryThreshold = 20;
String aicoreAutoDownload = 'false';
```

**KEEP** (AICore-related):
```dart
int chatEngineIndex = 1; // 1 = AICore
String aicoreAutoDownload = 'false';
int maxGenerationTokens = 0;
```

**WARNING**: Removing `ObjectBoxAiModel`, `ObjectBoxJournalChunk`, `ObjectBoxEmbeddingJob` entities requires ObjectBox schema migration and could cause data loss. **Recommendation**: Keep these entities for now but mark them as `@deprecated` in comments.

---

### 2.5 Update AndroidManifest.xml

**REMOVE OpenCL libraries** (only needed for GGUF GPU acceleration):
```xml
<!-- REMOVE these lines: -->
<uses-native-library android:name="libOpenCL.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-car.so" android:required="false"/>
<uses-native-library android:name="libOpenCL-pixel.so" android:required="false"/>
```

**KEEP**: `android:largeHeap="true"` (useful for Gemma too)

---

## Phase 3: Harden Gemma Implementation (MEDIUM PRIORITY)

### 3.1 Fix InferenceChat Resource Leak

**Severity**: MEDIUM  
**File**: `lib/services/gemma_service.dart`  
**Problem**: `InferenceChat` never closed, only `InferenceModel`  
**Impact**: Potential memory leak over multiple generations

**Implementation**:

```dart
Stream<String> generate(
  String prompt, {
  int maxTokens = 1024,
  String? systemInstruction,
}) async* {
  if (state.status != GemmaEngineStatus.ready) {
    throw StateError('Gemma model is not installed. Download one first.');
  }

  InferenceModel? model;
  InferenceChat? chat;
  try {
    model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    chat = await model.createChat();

    final contextMsg = systemInstruction != null
        ? '$systemInstruction\n\nUser: $prompt'
        : prompt;

    await chat.addQuery(Message.text(
      text: contextMsg,
      isUser: true,
    ));

    final responseStream = chat.generateChatResponseAsync();

    await for (final token in responseStream) {
      if (token is TextResponse) {
        yield token.token;
      }
    }
  } catch (e) {
    debugPrint('Gemma generation error: $e');
    rethrow;
  } finally {
    // Close chat FIRST, then model
    try {
      await chat?.close();
    } catch (_) {
      // Best-effort cleanup
    }
    await model?.close();
  }
}
```

---

### 3.2 Add RAM Pre-Check for Gemma Model Load

**Severity**: MEDIUM  
**File**: `lib/services/gemma_service.dart`  
**Problem**: No memory check before loading 500MB model  
**Impact**: OOM crashes on low-end devices

**Implementation**:

```dart
import 'package:system_info2/system_info2.dart'; // Re-add if removed for GGUF

/// Check if device has enough RAM to load the model
Future<bool> _hasEnoughRam(int requiredMb) async {
  try {
    final freeRamMb = (SysInfo.getFreePhysicalMemory() / (1024 * 1024)).round();
    return freeRamMb >= requiredMb;
  } catch (e) {
    debugPrint('RAM check failed: $e');
    return true; // Default to allowing if check fails
  }
}

Future<void> downloadModel(GemmaModelPreset preset, {String? hfToken}) async {
  // Add RAM check before download
  final hasRam = await _hasEnoughRam(preset.approxSizeMb + 256); // Buffer for runtime
  if (!hasRam) {
    state = state.copyWith(
      status: GemmaEngineStatus.error,
      error: 'Insufficient RAM. Need ~${preset.approxSizeMb + 256}MB free. '
             'Try the 270M Lite model instead.',
    );
    return;
  }
  
  // ... rest of download logic
}
```

---

### 3.3 Fix deleteModel() — Don't Delete ALL Models

**Severity**: MEDIUM  
**File**: `lib/services/gemma_service.dart`  
**Problem**: Deletes ALL installed models, not just active one  
**Impact**: User loses all models if they have multiple

**Implementation**:

```dart
Future<void> deleteModel({String? modelId}) async {
  try {
    if (modelId != null) {
      // Delete specific model
      await FlutterGemma.uninstallModel(modelId);
    } else {
      // Delete the active model (if only one exists)
      final installedModels = await FlutterGemma.listInstalledModels();
      if (installedModels.length == 1) {
        await FlutterGemma.uninstallModel(installedModels.first);
      } else if (installedModels.isNotEmpty) {
        throw StateError(
          'Multiple models installed. Specify which model to delete.',
        );
      }
    }
    
    state = state.copyWith(status: GemmaEngineStatus.noModel);
  } catch (e) {
    state = state.copyWith(
      status: GemmaEngineStatus.error,
      error: 'Delete failed: $e',
    );
  }
}
```

---

### 3.4 Add Generation Timeout

**Severity**: LOW  
**File**: `lib/services/gemma_service.dart`  
**Problem**: No timeout on generation — could hang indefinitely  
**Impact**: UI frozen if model hangs

**Implementation**:

```dart
Stream<String> generate(
  String prompt, {
  int maxTokens = 1024,
  String? systemInstruction,
  Duration timeout = const Duration(minutes: 5), // Default 5 min timeout
}) async* {
  // ... existing setup ...

  try {
    final responseStream = chat.generateChatResponseAsync();
    
    // Add timeout wrapper
    await for (final token in responseStream.timeout(timeout)) {
      if (token is TextResponse) {
        yield token.token;
      }
    }
  } on TimeoutException catch (e) {
    debugPrint('Gemma generation timed out: $e');
    throw StateError('AI generation timed out. Please try again with a shorter prompt.');
  } catch (e) {
    // ... existing error handling
  }
}
```

---

### 3.5 Improve Error Messages in AiAssistantScreen

**Severity**: LOW  
**File**: `lib/screens/ai_assistant_screen.dart`  
**Problem**: Raw error messages shown to user  
**Impact**: Confusing technical errors for end users

**Implementation**:

```dart
String _formatUserError(Object error) {
  final errorStr = error.toString().toLowerCase();
  
  if (errorStr.contains('not installed')) {
    return 'AI model not installed. Please download it from AI Settings.';
  } else if (errorStr.contains('out of memory') || errorStr.contains('ram')) {
    return 'Not enough memory. Close other apps and try again.';
  } else if (errorStr.contains('timed out')) {
    return 'AI request timed out. Please try again.';
  } else if (errorStr.contains('model')) {
    return 'AI model error. Try restarting the app.';
  } else {
    return 'AI request failed. Please try again later.';
  }
}

// In _ask() onError handler:
onError: (e) {
  if (!mounted) return;
  setState(() {
    _error = _formatUserError(e);
    _isGenerating = false;
  });
},
```

---

## Phase 4: Clean Up & Optimize (LOW PRIORITY)

### 4.1 Optimize Journal Context Building

**Severity**: LOW  
**File**: `lib/screens/ai_assistant_screen.dart`  
**Problem**: Decrypts up to 5 entries on every query  
**Impact**: Repeated work, slow responses

**Implementation**: Add simple in-memory cache with 30-second TTL:

```dart
class _JournalContextCache {
  String? _cachedContext;
  DateTime? _cachedAt;
  static const _ttl = Duration(seconds: 30);

  String? get() {
    if (_cachedContext == null || 
        _cachedAt == null || 
        DateTime.now().difference(_cachedAt!) > _ttl) {
      return null;
    }
    return _cachedContext;
  }

  void set(String context) {
    _cachedContext = context;
    _cachedAt = DateTime.now();
  }
}

// In AiAssistantScreenState:
final _contextCache = _JournalContextCache();

Future<String> _buildJournalContext() async {
  final cached = _contextCache.get();
  if (cached != null) return cached;

  // ... existing context building logic ...
  
  final context = buffer.toString();
  _contextCache.set(context);
  return context;
}
```

---

### 4.2 Implement getAllDraftIds() and clearAllDrafts()

**Severity**: LOW  
**File**: `lib/services/storage_service.dart`  
**Problem**: Methods are no-ops  
**Impact**: Drafts accumulate in secure storage

**Implementation**:

```dart
// Track draft IDs in a separate JSON structure
Future<List<String>> getAllDraftIds() async {
  final draftKeysJson = await _draftStorage.read(key: '_draft_keys_');
  if (draftKeysJson == null) return [];
  
  try {
    final Map<String, dynamic> keys = jsonDecode(draftKeysJson);
    return keys.keys.toList();
  } catch (e) {
    return [];
  }
}

Future<void> clearAllDrafts() async {
  final draftIds = await getAllDraftIds();
  for (final id in draftIds) {
    await _draftStorage.delete(key: 'draft_$id');
  }
  await _draftStorage.delete(key: '_draft_keys_');
}

Future<void> saveDraft(String draftId, String draftData) async {
  await _draftStorage.write(key: 'draft_$draftId', value: draftData);
  
  // Track this draft ID
  final existing = await getAllDraftIds();
  if (!existing.contains(draftId)) {
    existing.add(draftId);
    await _draftStorage.write(key: '_draft_keys_', value: jsonEncode(existing));
  }
}
```

---

### 4.3 Fix getSettings() Inefficiency

**Severity**: LOW  
**File**: `lib/services/storage_service.dart`  
**Problem**: `getAll()` reads all rows when id=1 not found  
**Impact**: Wasteful if multiple rows exist

**Implementation**:

```dart
UserSettings getSettings() {
  final byFixedId = _settingsBox.get(1);
  if (byFixedId != null) {
    return byFixedId.toFreezed();
  }

  // If no row with id=1, find ANY row (should be at most one)
  final query = _settingsBox.query().build();
  final all = query.find();
  query.close();
  
  if (all.isEmpty) {
    return const UserSettings(); // Defaults
  }
  
  // Migrate to id=1 for consistency
  final existing = all.first;
  if (existing.id != 1) {
    existing.id = 1;
    _settingsBox.put(existing);
  }
  
  return existing.toFreezed();
}
```

---

## Phase 5: Testing & Validation

### 5.1 Add Unit Tests

**Priority**: HIGH after all fixes  
**Files to test**:
- `encryption_service.dart` — AES encrypt/decrypt round-trip
- `gemma_service.dart` — Generate with mock model
- `security_service.dart` — PIN hash, rate limiting
- `storage_service.dart` — CRUD operations

---

### 5.2 Integration Testing

**Test scenarios**:
1. Download Gemma 270M model on low-end device emulator (4GB RAM)
2. Generate response with journal context
3. Cancel download mid-way
4. Delete model and verify storage freed
5. Encrypt/decrypt journal entry with new AES
6. Change PIN and verify old data still decrypts

---

## Implementation Order & Effort

| Phase | Task | Effort | Risk |
|-------|------|--------|------|
| 1.1 | Replace XOR with AES | 2 hours | HIGH (data migration) |
| 1.2 | Fix key derivation | 1 hour | HIGH (key change) |
| 1.3 | Remove plaintext fallback | 0.5 hours | LOW |
| 2.1 | Delete GGUF service files | 0.5 hours | LOW |
| 2.2 | Clean RAG service | 1 hour | MEDIUM |
| 2.3 | Update pubspec.yaml | 0.25 hours | LOW |
| 2.4 | Clean ObjectBox models | 1 hour | MEDIUM (migration) |
| 2.5 | Update AndroidManifest.xml | 0.25 hours | LOW |
| 3.1 | Fix InferenceChat leak | 0.5 hours | LOW |
| 3.2 | Add RAM pre-check | 0.5 hours | LOW |
| 3.3 | Fix deleteModel | 0.5 hours | LOW |
| 3.4 | Add generation timeout | 0.5 hours | LOW |
| 3.5 | Improve error messages | 0.5 hours | LOW |
| 4.1 | Optimize context cache | 0.5 hours | LOW |
| 4.2 | Implement draft methods | 0.5 hours | LOW |
| 4.3 | Fix getSettings | 0.25 hours | LOW |

**Total estimated effort**: ~10 hours

---

## Data Migration Strategy for Encryption Change

Since we're changing encryption from XOR to AES, existing data must be migrated:

```dart
class EncryptionService {
  int _encryptionVersion = 2; // New version for AES
  
  Future<String?> encrypt(String plainText) async {
    // ... AES encryption ...
    // Prepend version byte to ciphertext
    final versionedData = Uint8List.fromList([_encryptionVersion, ...combined]);
    return base64Encode(versionedData);
  }

  Future<String> decrypt(String? encryptedText) async {
    final combined = base64Decode(encryptedText);
    final version = combined[0];
    final actualData = combined.sublist(1);
    
    if (version == 1) {
      // Old XOR method — migrate on decrypt
      return _decryptXor(actualData);
    } else if (version == 2) {
      // New AES method
      return _decryptAes(actualData);
    } else {
      throw FormatException('Unknown encryption version: $version');
    }
  }
  
  // Keep old XOR methods as _decryptXor for migration period
}
```

**Migration Plan**:
1. Deploy with versioned encryption (supports both v1 XOR and v2 AES)
2. On each successful decrypt with v1, re-encrypt with v2 in background
3. After 30 days, remove v1 support
4. Add analytics to track migration progress (if applicable)

---

## Rollback Plan

If encryption migration causes issues:

1. **Immediate rollback**: Revert to XOR-only code (in Git)
2. **Partial rollback**: Keep AES for new data, maintain v1 fallback
3. **Full migration**: Complete AES migration, XOR code removed

---

## Success Metrics

After implementation:

1. ✅ All journal entries encrypted with AES-256-GCM
2. ✅ APK size reduced by 15MB+ (GGUF removal)
3. ✅ No resource leaks in Gemma service
4. ✅ No OOM crashes from model loading
5. ✅ User-friendly error messages
6. ✅ Generation timeouts prevent hangs
7. ✅ All unit tests passing
8. ✅ No plaintext fallback on encryption failure

---

## Next Steps

1. **Review this plan** with stakeholders
2. **Backup production data** before encryption changes
3. **Implement Phase 1** (security fixes) first
4. **Test thoroughly** before proceeding to Phase 2
5. **Deploy incrementally** — don't do all phases at once
6. **Monitor** for any issues after each phase

---

## Appendix: Files Modified Summary

| File | Changes | Lines Changed |
|------|---------|---------------|
| `encryption_service.dart` | AES-GCM, remove XOR | ~150 lines |
| `security_service.dart` | Fix key derivation | ~30 lines |
| `gemma_service.dart` | Fix leaks, add checks | ~40 lines |
| `rag_service.dart` | Remove GGUF paths | ~60 lines |
| `ai_assistant_screen.dart` | Error messages, cache | ~50 lines |
| `ai_settings_screen.dart` | No changes needed | 0 |
| `storage_service.dart` | Draft methods, settings | ~40 lines |
| `pubspec.yaml` | Remove GGUF deps | ~3 lines |
| `AndroidManifest.xml` | Remove OpenCL | ~3 lines |
| **Files Deleted** | 4 GGUF service files | ~800 lines |

**Net result**: ~300 lines modified, ~800 lines deleted, significantly more secure and maintainable.
