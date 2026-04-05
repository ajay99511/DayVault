# DayVault Local AI Integration - Robust Implementation Plan

Date: 2026-04-05

## 1) Objective
Integrate fully local RAG on Android (no cloud dependency) using:
- ObjectBox vector search (HNSW)
- On-device embedding generation
- llama.cpp runtime through Dart bindings (`llamadart`)

Primary goals:
- Preserve existing DayVault functionality (journal CRUD, encryption, backup, UI flows)
- Keep UI responsive under AI load
- Provide safe model lifecycle and predictable behavior on low-memory devices

## 2) Current State Snapshot
Already integrated in codebase:
- Vector chunk/entity model and embedding job queue in ObjectBox
- AI model registry with CRUD and active-model selection
- Runtime policy with device-aware defaults (RAM/CPU/battery)
- Llama runtime manager with single-engine lifecycle and CPU fallback
- RAG retrieval + context assembly + AI assistant screen
- AI Settings screen for import/activate/delete and runtime tuning

## 3) Android Model Placement (User Guidance)
Recommended workflow:
1. Keep downloaded `.gguf` files in `Download/` (or any accessible folder)
2. In app: `Profile -> AI Model Settings`
3. Tap `Import Chat Model` / `Import Embed Model`
4. Pick the file in Android file picker

After import, DayVault copies the model into app-private storage (`getApplicationDocumentsDirectory()/models`).
No manual copy into sandbox paths is required.

Developer/debug option:
- `adb push model.gguf /sdcard/Download/`
- Then import from file picker

## 4) Architecture Decisions
- Single loaded model at a time (shared engine) to avoid peak RAM spikes
- Explicit active model per role:
  - `roleIndex=0`: chat
  - `roleIndex=1`: embedding
- Embedding model switch triggers full re-index of journal chunks
- HNSW vectors constrained to fixed dimension (`768`) and cache hint (`256 MB`) for mobile safety
- Battery-aware embedding pause to avoid thermal/battery drain

## 5) Phased Plan and Acceptance Gates

### Phase A - Data Integrity Gate (Blocker)
- Verify encryption roundtrip deterministically:
  - Save entry -> read entry -> decrypted plaintext must match input
- If this fails, AI pipeline is blocked

Acceptance:
- 100% pass on roundtrip test set (headline/content/feeling, special chars, emoji, multiline)

### Phase B - Model Registry and GGUF Safety
- Maintain model metadata in ObjectBox (`ObjectBoxAiModel`)
- Validate imports:
  - extension is `.gguf`
  - header magic is `GGUF`
  - minimum size sanity
  - checksum (sha256)
- Safe file copy with temp path + atomic rename
- Deduplicate by role + checksum
- Handle missing-file metadata gracefully

Acceptance:
- Import/activate/delete cycles are deterministic
- Active model always resolves to an existing file or clear error state

### Phase C - Embedding Job Pipeline
- Queue-on-save (`upsert`) and queue-on-delete (`delete`)
- Worker retries with capped attempts (prevent queue deadlock)
- Reindex-all trigger when embedding model changes
- Filter retrieval to active embedding model ID to avoid mixed-vector drift

Acceptance:
- Save/edit/delete operations remain responsive
- Chunks remain consistent with current embedding model

### Phase D - LLM Runtime Lifecycle
- Single-flight load lock
- Unload-before-reload behavior
- GPU/auto failure fallback to CPU + 0 gpu layers
- Cancellation-safe streaming generation
- Idle auto-dispose

Acceptance:
- No concurrent-load race
- No stuck generation stream after cancel/dispose

### Phase E - RAG Assembly and Prompt Safety
- Query embedding -> nearest chunk retrieval -> token-budget packing
- Prompt contract:
  - answer only from provided diary context
  - if insufficient context, say so
  - treat diary chunks as untrusted text

Acceptance:
- No context-window overflow in standard queries
- Deterministic fallback behavior when no embedding model is active

### Phase F - UX + Operational Controls
- Settings UI:
  - import/activate/delete models
  - backend (auto/cpu/vulkan)
  - auto policy on/off
  - forced context/threads/gpu layers
  - low-battery pause threshold
- Diagnostics surface:
  - backend name
  - resolved gpu layers
  - policy summary

Acceptance:
- User can recover from bad configuration without reinstalling app

## 6) Edge Cases and Handling Matrix

1. GGUF file is invalid/corrupted
- Detect by header + size checks
- Reject with clear message

2. GGUF metadata exists but file missing
- Mark unusable and force re-import

3. Active embedding model deleted
- Auto-switch to another embedding model if available
- Queue full reindex

4. Embedding job repeatedly fails
- Cap attempts and remove dead job to avoid queue starvation

5. Vulkan fails on device
- Runtime falls back to CPU automatically

6. User has no active chat model
- Chat action disabled/clear warning

7. User has chat model but no embedding model
- Chat allowed with reduced/no diary-context retrieval

8. Battery APIs unavailable (OEM quirks)
- Fail-open: do not block pipeline due battery-read exception

9. Prompt-injection-style diary text
- Prompt guards treat diary content as untrusted notes

10. Low-RAM device pressure
- Conservative defaults (context, threads, cache hint)
- CPU-first policy on low-tier devices

## 7) Remaining High-Risk Items (Post-v1 Hardening)
1. True isolate partition for heavy DB + embedding work (`Store.attach` worker lifecycle)
2. Android WorkManager bridge for resilient background jobs across app kills
3. Tokenizer-accurate budgeting (instead of word-count approximation)
4. Device-level soak tests (thermal + OOM) on 4GB/6GB/8GB RAM classes

## 8) Performance Targets
- UI interaction: no frame jank from AI tasks
- First token latency target: <2.0s on mid-range device for short queries
- Background re-index: no ANR, no foreground UI freeze
- Memory guardrail: avoid simultaneous chat+embed model residency

## 9) Regression Protection Checklist
Before release candidate:
- Journal CRUD, edit, delete, spotlight unaffected
- Backup/export/restore unaffected
- Security lock flow unaffected
- Calendar and profile performance unaffected
- App startup unaffected when no models installed

## 10) Approval Decision
Ready for rollout with current safeguards.
Recommended rollout strategy:
1. Internal alpha on 3 Android tiers (4GB, 6GB, 8GB RAM)
2. Enable CPU-default policy first
3. Enable Vulkan opt-in after device compatibility matrix is validated
