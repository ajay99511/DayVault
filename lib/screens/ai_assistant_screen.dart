import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../services/llama_runtime_service.dart';
import '../services/rag_service.dart';
import '../widgets/glass_widgets.dart';

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
  bool _hasModels = false;
  String? _chatModelPath;
  String? _embeddingModelPath;

  @override
  void initState() {
    super.initState();
    _loadModelStatus();
  }

  Future<void> _loadModelStatus() async {
    final runtime = LlamaRuntimeService.instance;
    final has = await runtime.hasAnyModel();
    final chatPath = await runtime.getChatModelPath();
    final embedPath = await runtime.getEmbeddingModelPath();
    if (!mounted) return;
    setState(() {
      _hasModels = has;
      _chatModelPath = chatPath;
      _embeddingModelPath = embedPath;
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
                    'Local AI',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _hasModels ? Icons.memory : Icons.warning_amber_rounded,
                      color: _hasModels
                          ? AppColors.emerald500
                          : AppColors.amber500,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasModels
                            ? 'Local GGUF model detected'
                            : 'No local GGUF model found',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadModelStatus,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
            if (!_hasModels)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Place model files at:',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _chatModelPath ?? '',
                        style: const TextStyle(
                            color: AppColors.slate400, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _embeddingModelPath ?? '',
                        style: const TextStyle(
                            color: AppColors.slate400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
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
                      onPressed: (_isGenerating || !_hasModels) ? null : _ask,
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
