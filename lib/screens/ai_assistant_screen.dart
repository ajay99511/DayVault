import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../services/gemma_service.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../widgets/glass_widgets.dart';
import 'ai_settings_screen.dart';

/// AI Assistant screen — Gemma-powered chat interface.
///
/// Uses flutter_gemma for on-device inference. Journal context is provided
/// via recent entries (simple text approach — no vector embeddings required).
/// See GGUF_REFERENCE.md for the original RAG-based implementation.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _queryCtrl = TextEditingController();
  String _response = '';
  bool _isGenerating = false;
  String? _error;
  StreamSubscription<String>? _activeSub;
  
  // Journal context cache with 30-second TTL
  String? _cachedJournalContext;
  DateTime? _contextCachedAt;
  static const _contextTtl = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // Ensure Gemma service has latest status.
    Future.microtask(
        () => ref.read(gemmaServiceProvider.notifier).refreshStatus());
  }

  /// Build journal context from the N most recent entries (offline, no
  /// embeddings needed). This replaces the full RAG pipeline with a simple
  /// text-context approach that works without a separate embedding model.
  Future<String> _buildJournalContext() async {
    // Check cache first
    if (_cachedJournalContext != null && _contextCachedAt != null) {
      final age = DateTime.now().difference(_contextCachedAt!);
      if (age < _contextTtl) {
        return _cachedJournalContext!;
      }
    }

    try {
      final storage = ref.read(storageServiceProvider);
      final encryption = EncryptionService();
      final entries = await storage.getJournal();
      // Take up to 5 most recent entries for context.
      final recent = entries.take(5).toList();
      if (recent.isEmpty) return '';

      final buffer = StringBuffer();
      buffer.writeln('Recent journal entries for context:');
      for (final entry in recent) {
        final headline = await encryption.decrypt(entry.headline);
        final content = await encryption.decrypt(entry.content);
        final date = entry.date.toIso8601String().substring(0, 10);
        buffer.writeln('--- Entry ($date) ---');
        if (headline.trim().isNotEmpty) buffer.writeln('Title: $headline');
        if (content.trim().isNotEmpty) {
          // Truncate long entries to keep context within token budget.
          final trimmed = content.length > 500
              ? '${content.substring(0, 500)}...'
              : content;
          buffer.writeln(trimmed);
        }
        buffer.writeln();
      }
      
      final context = buffer.toString();
      _cachedJournalContext = context;
      _contextCachedAt = DateTime.now();
      return context;
    } catch (e) {
      debugPrint('Failed to build journal context: $e');
      return '';
    }
  }

  /// Format error messages for user display
  String _formatUserError(Object error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('not installed') || errorStr.contains('no model')) {
      return 'AI model not installed. Please download it from AI Settings.';
    } else if (errorStr.contains('insufficient') || 
               errorStr.contains('memory') || 
               errorStr.contains('ram') ||
               errorStr.contains('oom')) {
      return 'Not enough memory. Close other apps and try again.';
    } else if (errorStr.contains('timed out') || 
               errorStr.contains('timeout')) {
      return 'AI request timed out. Please try again with a shorter question.';
    } else if (errorStr.contains('multiple models')) {
      return 'Multiple AI models detected. Please contact support.';
    } else if (errorStr.contains('model')) {
      return 'AI model error. Try restarting the app or redownloading the model.';
    } else if (errorStr.contains('cancelled')) {
      return 'AI request was cancelled.';
    } else {
      return 'AI request failed. Please try again later. '
             'If the issue persists, check AI Settings.';
    }
  }

  Future<void> _ask() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty || _isGenerating) return;

    setState(() {
      _isGenerating = true;
      _response = '';
      _error = null;
    });

    try {
      await _activeSub?.cancel();

      // Build a prompt with journal context.
      final journalContext = await _buildJournalContext();
      final prompt = journalContext.isNotEmpty
          ? '$journalContext\nUser question: $q\nAssistant:'
          : q;

      final gemma = ref.read(gemmaServiceProvider.notifier);
      final stream = gemma.generate(
        prompt,
        maxTokens: 1024,
        systemInstruction:
            'You are DayVault, a private journal AI assistant. '
            'Answer using the provided journal entries as context. '
            'If context is insufficient, say so honestly. '
            'Be helpful, concise, and never fabricate journal content.',
      );
      _activeSub = stream.listen(
        (token) {
          if (!mounted) return;
          setState(() => _response += token);
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _error = _formatUserError(e);
            _isGenerating = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isGenerating = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatUserError(e);
        _isGenerating = false;
      });
    }
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gemmaState = ref.watch(gemmaServiceProvider);
    final isReady = gemmaState.status == GemmaEngineStatus.ready;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AI Assistant',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white70),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiSettingsScreen(),
                        ),
                      );
                      // Re-check status after returning from settings.
                      ref.read(gemmaServiceProvider.notifier).refreshStatus();
                    },
                  ),
                ],
              ),
            ),

            // ── Status bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      isReady
                          ? Icons.check_circle
                          : Icons.cloud_download_outlined,
                      color: isReady
                          ? AppColors.emerald500
                          : AppColors.amber500,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isReady
                            ? 'Gemma AI ready — on-device & private'
                            : 'AI model not installed. Open settings to download.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Setup prompt if model not installed ──
            if (!isReady)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Setup Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Download the Gemma AI model to start chatting about your '
                        'journal entries. All processing happens on-device — '
                        'your data never leaves your phone.',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AiSettingsScreen(),
                              ),
                            );
                            ref
                                .read(gemmaServiceProvider.notifier)
                                .refreshStatus();
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download AI Model'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.indigo500,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Response area ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: Text(
                      _error != null
                          ? 'Error: $_error'
                          : (_response.isEmpty
                              ? 'Ask DayVault about your journal history.'
                              : _response),
                      style: TextStyle(
                        color: _error != null
                            ? AppColors.rose500
                            : Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Input area ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryCtrl,
                        enabled: !_isGenerating,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Ask about your memories...',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          (_isGenerating || !isReady) ? null : _ask,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      color: AppColors.indigo500,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
