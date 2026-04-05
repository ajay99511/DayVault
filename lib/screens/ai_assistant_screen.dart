import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../services/android_aicore_service.dart';
import '../services/rag_service.dart';
import '../widgets/glass_widgets.dart';
import 'ai_settings_screen.dart';

/// AI Assistant screen — AICore-focused chat interface.
///
/// GGUF model status checks have been removed from the user-facing UI.
/// The chat backend defaults to Android AICore (Gemini Nano).
/// See GGUF_REFERENCE.md for the original GGUF-aware implementation.
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
  bool _aicoreReady = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);

    final aicoreStatus =
        await ref.read(androidAicoreServiceProvider).getStatus();

    if (!mounted) return;
    setState(() {
      // AICore is the default engine. Treat it as ready if model is available.
      _aicoreReady = aicoreStatus.modelReady;
      _loading = false;
    });
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
      final stream = ref.read(ragServiceProvider).ask(q);
      _activeSub = stream.listen(
        (token) {
          if (!mounted) return;
          setState(() => _response += token);
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _error = e.toString());
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isGenerating = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
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
                      await _loadStatus();
                    },
                  ),
                ],
              ),
            ),
            // Status bar
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _aicoreReady
                            ? Icons.check_circle
                            : Icons.cloud_download_outlined,
                        color: _aicoreReady
                            ? AppColors.emerald500
                            : AppColors.amber500,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _aicoreReady
                              ? 'Gemini Nano ready — on-device & private'
                              : 'AI model not ready. Open settings to download.',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadStatus,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_aicoreReady && !_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                        'Download the Google AI model to start chatting about your journal entries. '
                        'All processing happens on-device — your data never leaves your phone.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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
                            await _loadStatus();
                          },
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Open AI Settings'),
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
            // Response area
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
                        color:
                            _error != null ? AppColors.rose500 : Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Input area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GlassContainer(
                borderRadius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          (_isGenerating || !_aicoreReady) ? null : _ask,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
