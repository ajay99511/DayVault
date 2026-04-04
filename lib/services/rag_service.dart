import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/ai_constants.dart';
import '../models/objectbox_models.dart';
import '../services/encryption_service.dart';
import '../services/llama_runtime_service.dart';
import '../services/storage_service.dart';

class RagAnswerContext {
  final String entryId;
  final int chunkIndex;
  final double score;
  final String text;

  const RagAnswerContext({
    required this.entryId,
    required this.chunkIndex,
    required this.score,
    required this.text,
  });
}

class RagService {
  final StorageService _storage;
  final EncryptionService _encryption = EncryptionService();
  final LlamaRuntimeService _runtime = LlamaRuntimeService.instance;

  Timer? _workerTimer;
  bool _processing = false;
  bool _started = false;

  RagService(this._storage);

  void start() {
    if (_started) return;
    _started = true;
    _workerTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _processNextJob(),
    );
    unawaited(_processNextJob());
  }

  Future<void> dispose() async {
    _workerTimer?.cancel();
    _workerTimer = null;
    _started = false;
  }

  Future<void> kickWorker() async => _processNextJob();

  Future<void> _processNextJob() async {
    if (_processing) return;
    _processing = true;

    try {
      final job = await _storage.getNextEmbeddingJob();
      if (job == null) return;

      if (job.opType == 1) {
        await _storage.deleteChunksForEntry(job.entryId);
        await _storage.completeEmbeddingJob(job.id);
        return;
      }

      final entry = await _storage.getJournalEntryById(job.entryId);
      if (entry == null) {
        await _storage.deleteChunksForEntry(job.entryId);
        await _storage.completeEmbeddingJob(job.id);
        return;
      }

      final plainHeadline = await _encryption.decrypt(entry.headline);
      final plainContent = await _encryption.decrypt(entry.content);
      final plainFeeling =
          entry.feeling != null ? await _encryption.decrypt(entry.feeling) : '';

      final sourceText = [
        if (plainHeadline.trim().isNotEmpty) plainHeadline.trim(),
        if (plainFeeling.trim().isNotEmpty) 'Feeling: ${plainFeeling.trim()}',
        if (plainContent.trim().isNotEmpty) plainContent.trim(),
      ].join('\n\n');

      final chunks = _chunkText(sourceText);

      final now = DateTime.now();
      final modelHash = _shortHash(AiConstants.embeddingModelId);
      final writeChunks = <ObjectBoxJournalChunk>[];

      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final vector = await _runtime.embed(chunk.text);
        final fitted =
            _fitVectorDimensions(vector, AiConstants.embeddingDimensions);
        final encryptedChunk =
            await _encryption.encrypt(chunk.text) ?? chunk.text;

        writeChunks.add(
          ObjectBoxJournalChunk()
            ..chunkId = '${entry.entryId}:$i:$modelHash'
            ..entryId = entry.entryId
            ..chunkIndex = i
            ..tokenEstimate = chunk.tokenEstimate
            ..chunkText = encryptedChunk
            ..embeddingModelId = AiConstants.embeddingModelId
            ..embedding = fitted
            ..updatedAt = now,
        );
      }

      await _storage.replaceEntryChunks(entry.entryId, writeChunks);
      await _storage.completeEmbeddingJob(job.id);
    } catch (e, st) {
      debugPrint('RAG job failed: $e\n$st');
      final job = await _storage.getNextEmbeddingJob();
      if (job != null) {
        await _storage.failEmbeddingJob(job, e.toString());
      }
    } finally {
      _processing = false;
    }
  }

  Future<List<RagAnswerContext>> retrieveContext(String userQuery) async {
    final queryVec = _fitVectorDimensions(
      await _runtime.embed(userQuery),
      AiConstants.embeddingDimensions,
    );
    final scored = <RagAnswerContext>[];
    try {
      final nearest = await _storage.findNearestChunks(
        queryVec,
        limit: AiConstants.retrievalTopK,
      );
      for (final hit in nearest) {
        final plainChunk = await _encryption.decrypt(hit.object.chunkText);
        scored.add(
          RagAnswerContext(
            entryId: hit.object.entryId,
            chunkIndex: hit.object.chunkIndex,
            score: hit.score,
            text: plainChunk,
          ),
        );
      }
    } catch (_) {
      // Fallback keeps the feature available if HNSW query fails at runtime.
      final chunks = await _storage.getAllChunks();
      for (final chunk in chunks) {
        final score = _cosineDistance(queryVec, chunk.embedding);
        final plainChunk = await _encryption.decrypt(chunk.chunkText);
        scored.add(
          RagAnswerContext(
            entryId: chunk.entryId,
            chunkIndex: chunk.chunkIndex,
            score: score,
            text: plainChunk,
          ),
        );
      }
      scored.sort((a, b) => a.score.compareTo(b.score));
    }

    final selected = <RagAnswerContext>[];
    var tokenBudget = 0;
    for (final hit in scored.take(AiConstants.retrievalTopK)) {
      final estimate = _estimateTokens(hit.text);
      if (tokenBudget + estimate > AiConstants.retrievalMaxContextTokens) {
        continue;
      }
      selected.add(hit);
      tokenBudget += estimate;
    }

    return selected;
  }

  Stream<String> ask(String userQuery) async* {
    final contexts = await retrieveContext(userQuery);
    final ragPrompt = _buildPrompt(userQuery, contexts);
    yield* _runtime.generate(
      ragPrompt,
      maxOutputTokens: AiConstants.chatMaxOutputTokens,
    );
  }

  String _buildPrompt(String userQuery, List<RagAnswerContext> contexts) {
    final buffer = StringBuffer()
      ..writeln('You are DayVault, a private local AI assistant.')
      ..writeln(
        'Answer using ONLY the provided diary context. '
        'If context is insufficient, say you do not have enough diary context.',
      )
      ..writeln();

    if (contexts.isEmpty) {
      buffer.writeln('Diary context: [none]');
    } else {
      buffer.writeln('Diary context chunks:');
      for (final c in contexts) {
        buffer.writeln(
          '- [Entry ${c.entryId}, Chunk ${c.chunkIndex}] ${c.text.replaceAll('\n', ' ')}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('User question: $userQuery')
      ..writeln('Assistant:');

    return buffer.toString();
  }

  List<_ChunkDraft> _chunkText(String source) {
    final text = source.trim();
    if (text.isEmpty) return const [];

    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) return const [];

    final chunks = <_ChunkDraft>[];
    const target = AiConstants.chunkTargetTokens;
    const maxChunk = AiConstants.chunkMaxTokens;
    const overlap = AiConstants.chunkOverlapTokens;

    final words = paragraphs.join(' \n ').split(RegExp(r'\s+'));
    var start = 0;
    while (start < words.length) {
      var end = math.min(start + target, words.length);
      if (end - start > maxChunk) {
        end = start + maxChunk;
      }
      final slice = words.sublist(start, end).join(' ').trim();
      if (slice.isNotEmpty) {
        chunks.add(
          _ChunkDraft(
            text: slice,
            tokenEstimate: _estimateTokens(slice),
          ),
        );
      }
      if (end == words.length) break;
      start = math.max(0, end - overlap);
    }

    return chunks;
  }

  int _estimateTokens(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.length;
  }

  static List<double> _fitVectorDimensions(List<double> src, int dims) {
    if (src.length == dims) return src;
    if (src.length > dims) return src.sublist(0, dims);
    return [...src, ...List<double>.filled(dims - src.length, 0)];
  }

  static double _cosineDistance(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 1.0;
    final len = math.min(a.length, b.length);
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < len; i++) {
      final av = a[i];
      final bv = b[i];
      dot += av * bv;
      na += av * av;
      nb += bv * bv;
    }
    if (na == 0 || nb == 0) return 1.0;
    final cosine = dot / (math.sqrt(na) * math.sqrt(nb));
    return 1.0 - cosine;
  }

  static String _shortHash(String input) {
    final bytes = utf8.encode(input);
    var hash = 2166136261;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

final ragServiceProvider = Provider<RagService>((ref) {
  final service = RagService(ref.read(storageServiceProvider));
  service.start();
  ref.onDispose(() => service.dispose());
  return service;
});

class _ChunkDraft {
  final String text;
  final int tokenEstimate;

  const _ChunkDraft({
    required this.text,
    required this.tokenEstimate,
  });
}
