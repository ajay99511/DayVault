# GGUF Local Model Reference — DayVault

> **Date**: 2026-04-05  
> **Status**: GGUF is retained in code but HIDDEN from user-facing UI.  
> **Default engine**: Android AICore (Gemini Nano)

## Purpose

This document catalogs all GGUF/llama.cpp related code in DayVault. The GGUF
pipeline was removed from the user-facing UI because:

1. **OOM crash risk** — Loading GGUF models allocates 400MB-2GB+ of native RAM
   with no OS guardrails. On mobile, this frequently causes the Low Memory
   Killer to terminate the app.
2. **Crash loop** — The background RAG worker auto-started on every app launch,
   which meant a single bad model import created an unrecoverable crash loop.
3. **UX friction** — Users must manually find, download, and import `.gguf`
   files. This is not suitable for a consumer-facing journal app.
4. **APK bloat** — `llamadart` bundles ~10-15MB of llama.cpp native libraries
   per ABI.

Google's Android AICore (Gemini Nano) handles all of these issues: managed
model lifecycle, system-level memory management, one-tap model download, and
zero APK size impact.

---

## Quick Restore Guide

To re-enable GGUF in the UI, you need to:

1. Restore the full `AiSettingsScreen` (see Section B below)
2. Restore the full `AiAssistantScreen` (see Section C below)
3. Optionally restore eager RAG worker start in `main.dart` (see Section D)

---

## A. GGUF Service Files (FULLY INTACT — NO CODE REMOVED)

All service files are untouched and can be called programmatically at any time.

### `lib/services/llama_runtime_service.dart`
- **Class**: `LlamaRuntimeService` (singleton)
- **Key methods**:
  - `ensureModelLoaded({modelPath, policy})` — Loads GGUF model into native
    memory with single-flight lock and GPU fallback. Now includes RAM pre-check.
  - `embed(text, {modelPath, policy})` — Generate embedding vector from text
  - `generate(prompt, {modelPath, policy, params})` — Stream text generation
  - `cancelGeneration()` — Cancel in-flight generation
  - `dispose()` — Unload model and free native memory
  - `getDiagnostics()` — Returns loaded model info
  - `getModelDirectory()` — Returns `{appDocs}/models/` directory
  - `hasAnyModel()` — Checks if any `.gguf` files exist in model directory

### `lib/services/ai_model_registry_service.dart`
- **Class**: `AiModelRegistryService`
- **Provider**: `aiModelRegistryServiceProvider`
- **Key methods**:
  - `pickAndImportModel({roleIndex})` — Opens file picker for `.gguf` files
  - `importModel({roleIndex, sourcePath, sourceBytes, sourceName})` — Import
    with validation (header magic, size, checksum, dedup)
  - `activateModel({roleIndex, modelId})` — Set active model per role
  - `deleteModel(modelId)` — Delete model file and metadata
  - `getModels({roleIndex})` — List imported models
  - `getRuntimeConfig()` / `saveRuntimeConfig()` — Runtime config CRUD
- **Role indexes**: `0` = chat model, `1` = embedding model

### `lib/services/ai_runtime_policy_service.dart`
- **Class**: `AiRuntimePolicyService`
- **Provider**: `aiRuntimePolicyServiceProvider`
- **Purpose**: Device-aware runtime parameter tuning
- **Key methods**:
  - `buildPolicy({forEmbedding})` — Returns `AiRuntimePolicy` with device-tuned
    ModelParams (context size, threads, GPU layers, batch sizes)
  - `getDeviceProfile()` — Returns `AiDeviceProfile` with RAM, CPU, tier
- **Device tiers**: low (≤4GB), mid (≤6GB), high (≤8GB), ultra (>8GB)
- **Imports `llamadart`** — uses `ModelParams`, `GenerationParams`, `GpuBackend`

### `lib/services/rag_service.dart`
- **Class**: `RagService`
- **Provider**: `ragServiceProvider` (lazy-start — does NOT auto-start)
- **GGUF code paths**:
  - `_processNextJob()` — Uses `LlamaRuntimeService.embed()` for embedding
    generation. Falls back gracefully if no model available.
  - `ask()` — Tries AICore first (if `chatEngineIndex == 1`), falls back to
    GGUF runtime if AICore fails, then to GGUF if `chatEngineIndex == 0`.
  - `_resolveModelPath(roleIndex)` — Checks active model in registry, then
    fallback name in model directory.
- **RAG pipeline**: chunk text → embed chunks → store in ObjectBox HNSW → query
  nearest neighbors → pack context → generate answer

### `lib/services/android_aicore_service.dart`
- **Class**: `AndroidAicoreService` (active default)
- **Provider**: `androidAicoreServiceProvider`
- **Platform channel**: `dayvault/aicore`
- **Methods**: `getStatus()`, `requestDownload()`, `ensureReady()`, `generate()`

---

## B. Original AI Settings Screen (GGUF-enabled version)

The original `AiSettingsScreen` had these additional UI sections. To restore,
add these back to `lib/screens/ai_settings_screen.dart`:

### Imports to add back
```dart
import '../services/ai_runtime_policy_service.dart';
import '../services/llama_runtime_service.dart';
import '../services/rag_service.dart';
import '../services/storage_service.dart';
```

### State variables to add back
```dart
List<ObjectBoxAiModel> _chatModels = [];
List<ObjectBoxAiModel> _embeddingModels = [];
LlamaRuntimeDiagnostics? _diagnostics;
AiRuntimePolicy? _chatPolicy;
```

### Model import buttons (originally in MODEL REGISTRY section)
```dart
_actionRow(
  leftLabel: 'Import Chat Model',
  leftAction: () => _importModel(0),
  rightLabel: 'Import Embed Model',
  rightAction: () => _importModel(1),
),
```

### Chat engine dropdown (GGUF vs AICore)
```dart
DropdownButton<int>(
  value: config?.chatEngineIndex ?? 0,
  dropdownColor: AppColors.slate900,
  style: const TextStyle(color: Colors.white),
  items: const [
    DropdownMenuItem(value: 0, child: Text('Local GGUF')),
    DropdownMenuItem(value: 1, child: Text('Android AICore')),
  ],
  onChanged: (v) {
    if (config == null || v == null) return;
    setState(() => config.chatEngineIndex = v);
  },
),
```

### Backend selector (Auto/CPU/Vulkan)
```dart
DropdownButton<int>(
  value: config?.backendIndex ?? 0,
  items: const [
    DropdownMenuItem(value: 0, child: Text('Auto')),
    DropdownMenuItem(value: 1, child: Text('CPU')),
    DropdownMenuItem(value: 2, child: Text('Vulkan')),
  ],
  // ...
),
```

### GGUF runtime tuning controls
- Auto device policy toggle
- Pause embedding on low battery toggle
- Low battery threshold input
- Forced context size input (0=auto)
- Forced threads input (0=auto)
- Forced GPU layers input (-1=auto)
- Max output tokens input

### GGUF diagnostics
```dart
Text('Loaded: ${_diagnostics?.isLoaded == true ? "Yes" : "No"}'),
Text('Backend: ${_diagnostics?.backendName ?? "N/A"}'),
Text('GPU layers: ${_diagnostics?.resolvedGpuLayers?.toString() ?? "N/A"}'),
Text('Policy: ${_chatPolicy?.explanation ?? "N/A"}'),
```

### Model list card widget
The `_modelListCard` method displayed each imported model with:
- Display name, file size, import date
- ACTIVE badge for the currently selected model
- Activate / Delete action buttons
- Last error display (red text)

### Action methods
```dart
Future<void> _importModel(int roleIndex) async { ... }
Future<void> _activateModel(ObjectBoxAiModel model) async { ... }
Future<void> _deleteModel(ObjectBoxAiModel model) async { ... }
Future<void> _reindexNow() async { ... }
```

---

## C. Original AI Assistant Screen (GGUF-aware version)

The original `AiAssistantScreen` had these additional elements:

### Extra imports
```dart
import 'dart:io';
import '../services/ai_model_registry_service.dart';
import '../services/llama_runtime_service.dart';
```

### Extra state variables
```dart
bool _hasModels = false;
bool _hasChatModel = false;
bool _hasEmbeddingModel = false;
int _chatEngineIndex = 0;
String? _chatModelPath;
String? _embeddingModelPath;
String? _chatModelName;
String? _embeddingModelName;
```

### GGUF model status check logic
```dart
final runtime = LlamaRuntimeService.instance;
final has = await runtime.hasAnyModel();
final chatModel = await ref.read(aiModelRegistryServiceProvider)
    .getModels(roleIndex: 0);
final embedModel = await ref.read(aiModelRegistryServiceProvider)
    .getModels(roleIndex: 1);
```

### GGUF-specific UI elements
- Model path display for chat and embedding models
- "No local GGUF model found" warning
- Active chat/embedding model name display
- "Select an active chat model" warning
- "No active embedding model" warning

### dispose() had GGUF cleanup
```dart
LlamaRuntimeService.instance.cancelGeneration();
```

---

## D. Eager RAG Worker Start (REMOVED from main.dart)

The original `RootOrchestrator.initState()` contained:
```dart
import 'services/rag_service.dart';

// In initState():
ref.read(ragServiceProvider);  // This triggered RagService.start()
```

This was the PRIMARY cause of the crash loop. Removing this means:
- Embedding jobs are NOT processed in the background on app start
- Jobs remain queued in ObjectBox until the user explicitly enters the AI
  Assistant screen
- To re-enable, add the import and `ref.read()` call back, BUT only if you also
  add a guard in `RagService.start()` that checks for available memory first

---

## E. ObjectBox Entities (FULLY INTACT)

### `ObjectBoxAiModel` (lib/models/objectbox_models.dart)
- Stores imported GGUF model metadata
- Fields: modelId, roleIndex, displayName, filePath, checksum, fileSizeBytes,
  isActive, isUsable, lastError, importedAt, updatedAt

### `ObjectBoxAiRuntimeConfig` (lib/models/objectbox_models.dart)
- Single-row config pattern (id=1)
- `chatEngineIndex`: now defaults to `1` (AICore) instead of `0` (GGUF)
- GGUF fields retained: backendIndex, autoPolicy, forcedContextSize,
  forcedThreads, forcedGpuLayers, etc.

### `ObjectBoxJournalChunk` (lib/models/objectbox_models.dart)
- Stores chunked+embedded journal text for RAG retrieval
- HNSW vector index (768 dimensions, cosine distance)

### `ObjectBoxEmbeddingJob` (lib/models/objectbox_models.dart)
- Queue for pending embedding operations
- opType: 0=upsert, 1=delete

---

## F. Configuration Files

### `pubspec.yaml`
- `llamadart: ^0.6.7` — Retained with comment
- `file_picker: ^10.3.2` — Used by GGUF import, also used elsewhere
- `system_info2: ^4.1.0` — Used by policy service for device profiling

### `lib/config/ai_constants.dart`
- All constants retained (model IDs, dimensions, chunk params, etc.)

### `android/app/src/main/AndroidManifest.xml`
- `android:largeHeap="true"` added as safety net

### `android/app/build.gradle.kts`
- `com.google.mlkit:genai-prompt:1.0.0-beta2` — AICore dependency

### `android/app/src/main/kotlin/.../MainActivity.kt`
- Full AICore native bridge: checkStatus, downloadModel, generate
- Platform channel: `dayvault/aicore`

---

## G. Dependency Chain

```
ai_assistant_screen.dart
  └── rag_service.dart
       ├── llama_runtime_service.dart  ← GGUF core
       │    ├── llamadart (pub)
       │    └── ai_runtime_policy_service.dart
       │         └── llamadart (pub) — ModelParams, GpuBackend
       ├── android_aicore_service.dart ← AICore core (DEFAULT)
       ├── encryption_service.dart
       └── storage_service.dart
            └── objectbox models (AiModel, Chunk, Job, Config)

ai_settings_screen.dart
  └── ai_model_registry_service.dart
       ├── llama_runtime_service.dart (for model directory)
       ├── rag_service.dart (for kickWorker on import)
       └── storage_service.dart
```

---

## H. How to Fully Remove GGUF (NOT RECOMMENDED)

If you decide to completely remove GGUF in the future:

1. Remove `llamadart` from `pubspec.yaml`
2. Delete `lib/services/llama_runtime_service.dart`
3. Delete `lib/services/ai_runtime_policy_service.dart`
4. Remove GGUF paths from `lib/services/rag_service.dart`
5. Remove GGUF paths from `lib/services/ai_model_registry_service.dart`
6. Remove `ObjectBoxAiModel` entity (requires ObjectBox migration)
7. Remove `ObjectBoxJournalChunk` entity (requires ObjectBox migration)
8. Remove `ObjectBoxEmbeddingJob` entity (requires ObjectBox migration)
9. Remove GGUF fields from `ObjectBoxAiRuntimeConfig`
10. Remove `lib/config/ai_constants.dart` or reduce to AICore-only constants
11. Remove `file_picker` from pubspec if not used elsewhere
12. Run `dart run build_runner build --delete-conflicting-outputs`

**Warning**: Steps 6-9 require ObjectBox schema migration which can cause data
loss if not handled correctly. This is why keeping the code as-is is the safer
approach.
