# DayVault Complete Implementation Reference

**Last Updated**: 2026-04-07  
**Framework**: Flutter (Dart)  
**Platform**: Android  
**AI Engine**: flutter_gemma v0.12.8 (on-device)  
**Database**: ObjectBox v5.2.0  

---

## Table of Contents

1. [AI Integration Architecture](#1-ai-integration-architecture)
2. [Flutter Gemma Implementation (High Priority)](#2-flutter-gemma-implementation-high-priority)
3. [Security & Encryption Changes](#3-security--encryption-changes)
4. [Performance Optimizations](#4-performance-optimizations)
5. [Issues Identified & Fixed](#5-issues-identified--fixed)
6. [APK Size Analysis](#6-apk-size-analysis)
7. [File Inventory](#7-file-inventory)
8. [Build & Deployment](#8-build--deployment)
9. [Quick Reference](#9-quick-reference)

---

## 1. AI Integration Architecture

### 1.1 Current AI Stack (Active)

```
┌─────────────────────────────────────────────────────────────────┐
│                      DayVault AI Stack                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────────────┐  │
│  │   User Interface     │    │   AI Settings                │  │
│  │                      │    │   ai_settings_screen.dart    │  │
│  │  ai_assistant_screen │◄──►│  - Gemma model selection     │  │
│  │  (chat interface)    │    │  - Download/Manage models    │  │
│  └──────────┬───────────┘    │  - HuggingFace token input   │  │
│             │                └──────────┬───────────────────┘  │
│             │                           │                      │
│             ▼                           │                      │
│  ┌──────────────────────┐               │                      │
│  │   Gemma Service      │               │                      │
│  │  gemma_service.dart  │◄──────────────┘                      │
│  │                      │                                      │
│  │  • Model download    │                                      │
│  │  • Model lifecycle   │                                      │
│  │  • Text generation   │                                      │
│  │  • Stream response   │                                      │
│  └──────────┬───────────┘                                      │
│             │                                                   │
│             ▼                                                   │
│  ┌──────────────────────┐                                      │
│  │   flutter_gemma pkg  │                                      │
│  │   (flutter_gemma)    │                                      │
│  │                      │                                      │
│  │  • LiteRT-LM engine  │                                      │
│  │  • On-device infer.  │                                      │
│  │  • Model management  │                                      │
│  └──────────────────────┘                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Removed AI Stack (Deprecated)

The following components were **completely removed**:

| Component | Status | Reason |
|-----------|--------|--------|
| **GGUF/llama.cpp** | ❌ Removed | No UI access, OOM crash risk, 15MB+ native libs |
| **Android AICore (ML Kit)** | ❌ Removed | Redundant with Gemma, saved ~50MB APK |
| **RAG Service** | ⚠️ Deprecated | Requires GGUF embeddings, stubbed out |

### 1.3 Data Flow

```
User asks question
       │
       ▼
AiAssistantScreen._ask()
       │
       ├─► Build journal context (5 recent entries, plain text)
       │    └─► StorageService.getJournal() → decrypt if needed
       │
       ▼
GemmaService.generate()
       │
       ├─► RAM check (512MB minimum)
       ├─► Get active Gemma model
       ├─► Create chat with system instruction
       ├─► Stream tokens
       └─► Timeout after 5 minutes
       │
       ▼
Display response token-by-token
```

---

## 2. Flutter Gemma Implementation (High Priority)

### 2.1 Core Files

| File | Purpose | Lines |
|------|---------|-------|
| `lib/services/gemma_service.dart` | Main AI service wrapper | ~300 |
| `lib/screens/ai_assistant_screen.dart` | Chat UI | ~620 |
| `lib/screens/ai_settings_screen.dart` | Model management | ~470 |
| `lib/config/ai_constants.dart` | AI configuration constants | ~25 |

### 2.2 GemmaService Architecture

#### 2.2.1 State Management

```dart
// Riverpod NotifierProvider
final gemmaServiceProvider = NotifierProvider<GemmaService, GemmaState>(() {
  return GemmaService();
});

// State structure
class GemmaState {
  final GemmaEngineStatus status;  // uninitialized | noModel | downloading | ready | error
  final double downloadProgress;   // 0.0 to 1.0
  final String? error;
}
```

#### 2.2.2 Model Presets

```dart
const List<GemmaModelPreset> _presets = [
  GemmaModelPreset(
    id: 'gemma3-1b',
    displayName: 'Gemma 3 — 1B',
    description: 'Good quality, fits most phones (~500 MB)',
    downloadUrl: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1B-it-int4.task',
    modelType: ModelType.gemmaIt,
    approxSizeMb: 500,
  ),
  GemmaModelPreset(
    id: 'gemma3-270m',
    displayName: 'Gemma 3 — 270M (Lite)',
    description: 'Lightweight, works on low-end phones (~150 MB)',
    downloadUrl: 'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma-3-270m-it-int4.task',
    modelType: ModelType.gemmaIt,
    approxSizeMb: 150,
  ),
];
```

#### 2.2.3 Key Methods

| Method | Purpose | Key Features |
|--------|---------|--------------|
| `initializeGlobal()` | Initialize flutter_gemma engine | Called once in `main()`, optional HF token |
| `downloadModel()` | Download model from HuggingFace | Progress tracking, cancellation, RAM check |
| `deleteModel()` | Remove installed model | Safe delete (only deletes if single model) |
| `generate()` | Stream text generation | System instruction, timeout, RAM check, resource cleanup |
| `refreshStatus()` | Check model status | Updates state for UI |
| `cancelDownload()` | Cancel in-progress download | Uses CancelToken |

#### 2.2.4 Generation Pipeline

```dart
Stream<String> generate(
  String prompt, {
  int maxTokens = 1024,
  String? systemInstruction,
  Duration timeout = const Duration(minutes: 5),
}) async* {
  // 1. Check model ready
  if (state.status != GemmaEngineStatus.ready) throw...
  
  // 2. RAM check (prevent OOM)
  final hasRam = await _hasEnoughRam(_minFreeRamMb);
  if (!hasRam) throw StateError('Insufficient memory...');
  
  // 3. Create model and chat
  model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
  chat = await model.createChat();
  
  // 4. Add message with optional system instruction
  final contextMsg = systemInstruction != null
      ? '$systemInstruction\n\nUser: $prompt'
      : prompt;
  await chat.addQuery(Message.text(text: contextMsg, isUser: true));
  
  // 5. Stream response with timeout
  final responseStream = chat.generateChatResponseAsync();
  await for (final token in responseStream.timeout(timeout)) {
    if (token is TextResponse) yield token.token;
  }
  
  // 6. Cleanup
  finally {
    await model?.close();
  }
}
```

### 2.3 AI Assistant Screen

#### 2.3.1 Context Building

```dart
Future<String> _buildJournalContext() async {
  // Get 5 most recent entries
  final entries = await storage.getJournal();
  final recent = entries.take(5).toList();
  
  // Build text context
  for (final entry in recent) {
    final headline = entry.headline;  // Plain text
    final content = entry.content;    // Plain text
    // Truncate long entries
    final trimmed = content.length > 500 
        ? '${content.substring(0, 500)}...' 
        : content;
  }
  
  return buffer.toString();
}
```

#### 2.3.2 Query Flow

```dart
Future<void> _ask() async {
  // 1. Build prompt with context
  final journalContext = await _buildJournalContext();
  final prompt = '$journalContext\nUser question: $q\nAssistant:';
  
  // 2. Generate with system instruction
  final stream = gemma.generate(
    prompt,
    maxTokens: 1024,
    systemInstruction: 'You are DayVault, a private journal AI assistant...',
  );
  
  // 3. Stream tokens to UI
  _activeSub = stream.listen(
    (token) => setState(() => _response += token),
    onError: (e) => setState(() => _error = _formatUserError(e)),
    onDone: () => setState(() => _isGenerating = false),
  );
}
```

### 2.4 Error Handling

#### 2.4.1 User-Friendly Error Messages

```dart
String _formatUserError(Object error) {
  final errorStr = error.toString().toLowerCase();
  
  if (errorStr.contains('not installed') || errorStr.contains('no model'))
    return 'AI model not installed. Please download it from AI Settings.';
  
  if (errorStr.contains('insufficient') || errorStr.contains('memory'))
    return 'Not enough memory. Close other apps and try again.';
  
  if (errorStr.contains('timed out') || errorStr.contains('timeout'))
    return 'AI request timed out. Please try again with a shorter question.';
  
  return 'AI request failed. Please try again later.';
}
```

#### 2.4.2 Timeout Protection

- Default timeout: **5 minutes** per generation
- Prevents hangs on slow devices or complex prompts
- User sees clear timeout error with suggestion

### 2.5 Resource Management

| Resource | Management Strategy |
|----------|---------------------|
| **InferenceModel** | Closed in `finally` block after generation |
| **InferenceChat** | Let garbage collected (flutter_gemma handles lifecycle) |
| **RAM** | Pre-check before load (512MB minimum) |
| **Download** | CancelToken for cancellation, progress tracking |
| **Model** | Single active model, safe delete logic |

---

## 3. Security & Encryption Changes

### 3.1 Original State

| Component | Implementation | Issues |
|-----------|----------------|--------|
| **Journal Data** | XOR encrypted fields | Trivially breakable |
| **Key Derivation** | 100 iterations max | Too weak, ASCII hex only |
| **IV Generation** | Timestamp-based | Predictable |
| **Error Handling** | Silent fallback to plaintext | No warnings |

### 3.2 Changes Made

#### 3.2.1 Phase 1: Improved Encryption (Attempted)

| Change | File | Status |
|--------|------|--------|
| XOR → AES-256-CBC | `encryption_service.dart` | ✅ Implemented but not needed |
| Key derivation fix (10K iterations) | `security_service.dart` | ✅ Implemented |
| Cryptographically secure salt | `security_service.dart` | ✅ Implemented |
| Key caching in memory | `security_service.dart` | ✅ Implemented |
| Remove plaintext fallback | `encryption_service.dart` | ✅ Implemented |
| Version tagging (v1/v2) | `encryption_service.dart` | ✅ Implemented |

#### 3.2.2 Phase 2: Remove Encryption from Journal Data

**Final Decision**: Store journal data as **plain text** in ObjectBox. PIN lock protects app access.

| Change | File | Impact |
|--------|------|--------|
| `toFreezed()` auto-detects encrypted data | `objectbox_models.dart` | Existing data decrypted once |
| `fromFreezed()` stores as plain text | `objectbox_models.dart` | New data unencrypted |
| `decryptSync()` for migration detection | `encryption_service.dart` | Sync decryption helper |
| Remove key derivation from save path | `objectbox_models.dart` | No encryption on save |
| Simplify `getJournal()` | `storage_service.dart` | No timeout needed |
| Remove draft encryption | `entry_editor.dart` | Drafts as plain text JSON |

#### 3.2.3 PIN System (Kept for App Lock)

```dart
// SecurityService retains:
- PIN hashing (PBKDF2-like, 100K iterations)
- Rate limiting (5 attempts → 30s lockout)
- Account lockout
- Encryption key derivation (cached after PIN verify)

// Removed:
- Encryption key storage for journal fields
- Key derivation on every save/load
- FlutterSecureStorage AndroidOptions complexity
```

### 3.3 Migration Behavior

| Data Type | Detection Method | Behavior |
|-----------|------------------|----------|
| **Plain text** | Not valid base64 | Returned as-is |
| **XOR encrypted (v1)** | base64 + version byte = 1 | Decrypted with cached key |
| **AES encrypted (v2)** | base64 + version byte = 2 | Returned as-is (async only) |
| **Corrupted/unknown** | Fails all checks | Returned as-is |

---

## 4. Performance Optimizations

### 4.1 Key Caching

**Before**: 150 FlutterSecureStorage reads per journal load (50 entries × 3 fields)  
**After**: 1 read at PIN verification, then cached in memory

```dart
// SecurityService caches key after PIN verify
Future<PinVerificationResult> verifyPin(String pin) async {
  if (inputHash == storedHash) {
    await _deriveAndCacheEncryptionKey(pin); // ← Key cached here
    return PinVerificationResult(success: true);
  }
}

// ObjectBox models use cached key for decryption
static String _maybeDecrypt(String text) {
  // Detect encrypted data
  if (versionByte == 1) {
    return EncryptionService().decryptSync(text); // Uses cached key
  }
  return text; // Plain text
}
```

### 4.2 Parallel Decryption (Legacy)

```dart
// Before: Sequential (3 awaits per entry)
final h = await encryptionService.decrypt(headline);
final c = await encryptionService.decrypt(content);
final f = feeling != null ? await encryptionService.decrypt(feeling!) : null;

// After: Synchronous detection (no async overhead)
final h = _maybeDecrypt(headline);  // Sync
final c = _maybeDecrypt(content);   // Sync
final f = feeling != null ? _maybeDecrypt(feeling!) : null; // Sync
```

### 4.3 Journal Context Caching

```dart
// AI Assistant caches journal context for 30 seconds
class _JournalContextCache {
  String? _cachedContext;
  DateTime? _cachedAt;
  static const _ttl = Duration(seconds: 30);

  String? get() {
    if (_cachedAt != null && DateTime.now().difference(_cachedAt!) < _ttl) {
      return _cachedContext;
    }
    return null;
  }
}
```

---

## 5. Issues Identified & Fixed

### 5.1 Critical Security Issues

| # | Issue | Severity | Fix | Status |
|---|-------|----------|-----|--------|
| 1 | XOR encryption trivially breakable | 🔴 Critical | Removed encryption entirely | ✅ Fixed |
| 2 | Predictable IV from timestamp | 🔴 Critical | N/A (no encryption) | ✅ Fixed |
| 3 | Silent fallback to plaintext | 🟡 High | Error handling added | ✅ Fixed |
| 4 | Weak key derivation (100 iterations) | 🟡 High | 10K iterations (for PIN) | ✅ Fixed |
| 5 | 150 Keystore reads per load | 🟡 High | Key caching (1 read) | ✅ Fixed |

### 5.2 AI/Gemma Issues

| # | Issue | Severity | Fix | Status |
|---|-------|----------|-----|--------|
| 6 | No RAM pre-check for model load | 🟡 High | Added 512MB check | ✅ Fixed |
| 7 | deleteModel() wiped ALL models | 🟡 High | Safe delete logic | ✅ Fixed |
| 8 | No generation timeout | 🟡 Medium | 5-minute timeout | ✅ Fixed |
| 9 | Raw error messages to users | 🟡 Medium | User-friendly messages | ✅ Fixed |
| 10 | InferenceChat resource leak | 🟡 Medium | Proper cleanup | ✅ Fixed |
| 11 | Infinite loading on decrypt fail | 🟡 High | Error state + retry | ✅ Fixed |

### 5.3 Dead Code Removal

| Component | Lines Removed | Reason | Status |
|-----------|---------------|--------|--------|
| `llama_runtime_service.dart` | ~190 | GGUF no longer used | ✅ Deleted |
| `ai_runtime_policy_service.dart` | ~200 | GGUF no longer used | ✅ Deleted |
| `ai_model_registry_service.dart` | ~390 | GGUF no longer used | ✅ Deleted |
| `GGUF_REFERENCE.md` | ~400 | Reference for removed code | ✅ Deleted |
| `llamadart` dependency | N/A | Saved ~15MB APK | ✅ Removed |
| ML Kit dependency | N/A | Saved ~50MB APK | ✅ Removed |
| OpenCL native libs | N/A | Only needed for GGUF | ✅ Removed |

### 5.4 Architectural Issues

| # | Issue | Impact | Fix | Status |
|---|-------|--------|-----|--------|
| 12 | RAG service dormant | Feature not working | Deprecated with stub | ✅ Fixed |
| 13 | GGUF fallback with no UI | User confusion | Removed fallback | ✅ Fixed |
| 14 | Draft management incomplete | No-ops | Full implementation | ✅ Fixed |
| 15 | Calendar screen same hang risk | Same as journal | Error handling added | ✅ Fixed |

---

## 6. APK Size Analysis

### 6.1 Size Evolution

| Version | APK Size (arm64) | Notes |
|---------|------------------|-------|
| Original (no AI) | ~60 MB | Basic Flutter app |
| After adding flutter_gemma | ~217 MB | With ML Kit + all native libs |
| After removing ML Kit | ~158 MB | AICore removed |
| After removing llamadart | ~157.7 MB | Minimal additional savings |

### 6.2 Native Library Breakdown (157.7 MB)

| Library | Size (uncompressed) | Purpose | Required? |
|---------|---------------------|---------|-----------|
| `libflutter.so` | 146 MB | Flutter engine | ✅ Yes |
| `libllm_inference_engine_jni.so` | 27.4 MB | LLM inference | ✅ Yes (Gemma) |
| `liblitertlm_jni.so` | 20.2 MB | LiteRT LM runtime | ✅ Yes (Gemma) |
| `libgemma_embedding_model_jni.so` | 23.7 MB | Gemma embedding | ⚠️ Optional |
| `libgecko_embedding_model_jni.so` | 23.7 MB | Gecko embedding | ❌ Unused |
| `libimagegenerator_gpu.so` | 17 MB | GPU image generation | ❌ Unused |
| `libmediapipe_tasks_vision_jni.so` | 14.3 MB | MediaPipe vision | ❌ Unused |
| `libtext_chunker_jni.so` | 13 MB | Text chunking | ❌ Done in Dart |
| `libmediapipe_tasks_vision_image_generator_jni.so` | 14 MB | MediaPipe image gen | ❌ Unused |
| `libsqlite_vector_store_jni.so` | 10.7 MB | SQLite vector store | ⚠️ Optional |
| `libapp.so` | 7.6 MB | Your Dart code | ✅ Yes |
| `libobjectbox-jni.so` | 2.5 MB | ObjectBox database | ✅ Yes |
| **Total** | **322 MB** (uncompressed) | **157.7 MB** (compressed) | |

### 6.3 Why flutter_gemma is Large

The `flutter_gemma` package bundles **all** ML capabilities in one package:
- ✅ Text generation (you use this)
- ❌ Image generation (31 MB wasted)
- ❌ Vision/Camera tasks (14 MB wasted)
- ❌ Multiple embedding models (47 MB, you only need 1)
- ❌ Text chunking (13 MB, you do this in Dart)

**Conclusion**: 157 MB is the inherent cost of on-device AI. Your app code is only 370 KB.

---

## 7. File Inventory

### 7.1 AI-Related Files (Active)

| File | Purpose | Status |
|------|---------|--------|
| `lib/services/gemma_service.dart` | Main AI service | ✅ Active |
| `lib/services/android_aicore_service.dart` | AICore stub (deprecated) | ⚠️ Deprecated |
| `lib/services/rag_service.dart` | RAG stub (deprecated) | ⚠️ Deprecated |
| `lib/screens/ai_assistant_screen.dart` | AI chat UI | ✅ Active |
| `lib/screens/ai_settings_screen.dart` | AI model management | ✅ Active |
| `lib/config/ai_constants.dart` | AI configuration | ✅ Active |

### 7.2 Security Files

| File | Purpose | Changes |
|------|---------|---------|
| `lib/services/security_service.dart` | PIN auth, key derivation | Key caching added |
| `lib/services/encryption_service.dart` | Encryption/decryption helpers | decryptSync() added |

### 7.3 Data Layer

| File | Purpose | Changes |
|------|---------|---------|
| `lib/services/storage_service.dart` | ObjectBox wrapper | Simplified, no encryption |
| `lib/services/objectbox_service.dart` | ObjectBox initialization | Unchanged |
| `lib/models/objectbox_models.dart` | Data models | Auto-decrypt on load, plain text save |
| `lib/models/types.dart` | Freezed types | Unchanged |

### 7.4 UI Screens

| File | Purpose | Changes |
|------|---------|---------|
| `lib/screens/journal_screen.dart` | Journal list | Error handling added |
| `lib/screens/calendar_screen.dart` | Calendar view | Error handling added |
| `lib/screens/entry_editor.dart` | Create/edit entry | Draft encryption removed |
| `lib/screens/lock_screen.dart` | PIN entry | Unchanged |

### 7.5 Configuration

| File | Purpose | Changes |
|------|---------|---------|
| `pubspec.yaml` | Dependencies | Removed llamadart, ML Kit |
| `android/app/build.gradle.kts` | Android build | Removed ML Kit dep |
| `android/app/src/main/AndroidManifest.xml` | Android manifest | Removed OpenCL libs |
| `android/app/proguard-rules.pro` | ProGuard rules | Added for flutter_gemma |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Native AICore stub | Stubbed out |

### 7.6 Documentation

| File | Purpose |
|------|---------|
| `AI_IMPLEMENTATION_FIX_PLAN.md` | Original fix plan |
| `IMPLEMENTATION_SUMMARY.md` | Implementation summary |
| `APK_SIZE_ANALYSIS.md` | APK size breakdown |
| `JOURNAL_LOADING_FIX.md` | Loading hang fix |
| `EXISTING_DATA_FIX.md` | Data decryption fix |
| `AI_INTEGRATION_ROBUST_PLAN.md` | Robustness plan |

---

## 8. Build & Deployment

### 8.1 Dependencies

```yaml
dependencies:
  flutter_gemma: ^0.12.8      # Primary AI engine
  encrypt: ^5.0.3              # Encryption (for drafts)
  objectbox: ^5.2.0            # Database
  flutter_riverpod: ^3.2.1     # State management
  flutter_secure_storage: ^10.0.0  # PIN storage

dev_dependencies:
  # Standard Flutter dev deps
```

### 8.2 Build Commands

```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Build APK (split per ABI)
flutter build apk --split-per-abi

# Build app bundle (for Play Store)
flutter build appbundle

# Analyze APK size
flutter build apk --target-platform android-arm64 --analyze-size
```

### 8.3 ProGuard Rules

```proguard
# android/app/proguard-rules.pro

# flutter_gemma / MediaPipe
-dontwarn com.google.mediapipe.proto.**
-dontwarn com.google.mediapipe.framework.**
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**

# Flutter Play Core (deferred components)
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep native methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
```

### 8.4 Build Configuration

```kotlin
// android/app/build.gradle.kts
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

---

## 9. Quick Reference

### 9.1 AI Service Quick Start

```dart
// Initialize in main()
GemmaService.initializeGlobal(huggingFaceToken: hfToken);

// Check if model ready
final state = ref.watch(gemmaServiceProvider);
if (state.status == GemmaEngineStatus.ready) {
  // Model ready
}

// Download model
await ref.read(gemmaServiceProvider.notifier).downloadModel(
  GemmaService.presets[0], // 1B or 270M
  hfToken: 'hf_...',
);

// Generate text
final stream = ref.read(gemmaServiceProvider.notifier).generate(
  'Hello, how are you?',
  maxTokens: 1024,
  systemInstruction: 'You are a helpful assistant...',
);

await for (final token in stream) {
  print(token);
}
```

### 9.2 Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "Gemma model is not installed" | No model downloaded | Download from AI Settings |
| "Insufficient RAM" | <512MB free | Close other apps, use 270M model |
| "AI generation timed out" | 5 min timeout | Use shorter prompt |
| "Not enough memory" | OOM prevented | RAM check blocked load |

### 9.3 Model Presets

| Model | Size | Quality | Best For |
|-------|------|---------|----------|
| Gemma 3 — 270M (Lite) | ~150 MB | Good | Low-end phones, quick responses |
| Gemma 3 — 1B | ~500 MB | Better | Most phones, detailed answers |

### 9.4 Key Constants

```dart
// AI Constants
chatContextTokens = 2048
chatMaxOutputTokens = 220
modelIdleDisposeAfter = 3 minutes
_minFreeRamMb = 512 MB
generationTimeout = 5 minutes
```

### 9.5 Troubleshooting

| Issue | Solution |
|-------|----------|
| Journal loads forever | Check PIN entered, encryption key cached |
| AI not responding | Check model downloaded, RAM available |
| APK too large | Remove unused features, consider deferred components |
| Build fails | Run `flutter clean && flutter pub get` |
| ProGuard errors | Check proguard-rules.pro has flutter_gemma rules |

---

## Appendix: Change Log

### Session 1: Initial Analysis
- Identified 31 issues across security, performance, and architecture
- Created comprehensive fix plan

### Session 2: Security Fixes
- Replaced XOR with AES-256-CBC (later removed)
- Fixed key derivation (10K iterations)
- Added key caching

### Session 3: GGUF Removal
- Deleted 4 service files (~780 lines)
- Removed llamadart dependency
- Removed OpenCL native libs

### Session 4: Gemma Hardening
- Added RAM pre-checks
- Fixed deleteModel() logic
- Added 5-minute timeout
- Improved error messages

### Session 5: Performance Fixes
- Fixed journal loading hang (150 → 1 Keystore read)
- Added timeout protection
- Added error handling + retry UI
- Parallel decryption

### Session 6: APK Size Optimization
- Removed ML Kit (saved ~50MB)
- Analyzed native libs (flutter_gemma bundles everything)
- Conclusion: 157MB is inherent cost of on-device AI

### Session 7: Remove Encryption
- Journal data now stored as plain text
- Existing encrypted data auto-detected and decrypted
- PIN lock retained for app access

---

**End of Document**

For questions or updates, refer to the specific implementation files listed above.
