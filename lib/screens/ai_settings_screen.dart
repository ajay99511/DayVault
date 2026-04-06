import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../services/gemma_service.dart';
import '../services/android_aicore_service.dart';
import '../widgets/glass_widgets.dart';

/// AI Settings screen — Gemma-powered with model management.
///
/// Users can choose a Gemma model preset, download it from Hugging Face,
/// and manage the installed model. AICore status is shown as a secondary
/// indicator for devices that support it.
///
/// GGUF model management has been removed from the user-facing UI.
/// See GGUF_REFERENCE.md for restoration instructions.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _hfTokenCtrl = TextEditingController();
  bool _showToken = false;
  int _selectedPresetIndex = 0;
  AicoreStatus? _aicoreStatus;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final gemmaNotifier = ref.read(gemmaServiceProvider.notifier);
    await gemmaNotifier.refreshStatus();

    // Also check AICore in background (for informational badge).
    final aicoreStatus =
        await ref.read(androidAicoreServiceProvider).getStatus();
    if (mounted) setState(() => _aicoreStatus = aicoreStatus);
  }

  Future<void> _downloadModel() async {
    final gemmaNotifier = ref.read(gemmaServiceProvider.notifier);
    final preset = GemmaService.presets[_selectedPresetIndex];
    final token = _hfTokenCtrl.text.trim();
    await gemmaNotifier.downloadModel(
      preset,
      hfToken: token.isNotEmpty ? token : null,
    );
  }

  @override
  void dispose() {
    _hfTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gemmaServiceProvider);
    final isReady = state.status == GemmaEngineStatus.ready;
    final isDownloading = state.status == GemmaEngineStatus.downloading;
    final hasError = state.status == GemmaEngineStatus.error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'AI Settings',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _refreshAll,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // ── Status card ──
                  _statusCard(state, isReady, isDownloading, hasError),
                  const SizedBox(height: 20),

                  // ── Model selection ──
                  if (!isReady) ...[
                    _sectionTitle('CHOOSE MODEL'),
                    const SizedBox(height: 8),
                    _modelSelectionCard(),
                    const SizedBox(height: 20),
                  ],

                  // ── HuggingFace Token ──
                  if (!isReady) ...[
                    _sectionTitle('HUGGING FACE TOKEN'),
                    const SizedBox(height: 8),
                    _tokenCard(),
                    const SizedBox(height: 20),
                  ],

                  // ── Download / Manage ──
                  _sectionTitle(isReady ? 'MANAGE MODEL' : 'DOWNLOAD'),
                  const SizedBox(height: 8),
                  _actionCard(state, isReady, isDownloading),
                  const SizedBox(height: 20),

                  // ── AICore info ──
                  if (_aicoreStatus != null) ...[
                    _sectionTitle('AICORE (BONUS)'),
                    const SizedBox(height: 8),
                    _aicoreInfoCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Status card
  // ──────────────────────────────────────────────────────────────────
  Widget _statusCard(
      GemmaState state, bool isReady, bool isDownloading, bool hasError) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReady
                    ? Icons.check_circle
                    : (isDownloading
                        ? Icons.downloading
                        : (hasError
                            ? Icons.error_outline
                            : Icons.cloud_download_outlined)),
                color: isReady
                    ? AppColors.emerald500
                    : (hasError ? AppColors.rose500 : AppColors.amber500),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isReady
                      ? 'Gemma AI — Ready'
                      : (isDownloading
                          ? 'Downloading model...'
                          : (hasError
                              ? 'Error'
                              : 'No AI model installed')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.downloadProgress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.indigo500),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(state.downloadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (isReady)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'On-device AI is ready. All processing happens locally — '
                'your data never leaves your phone.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          if (!isReady && !isDownloading && !hasError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Download a Gemma model to enable AI features. '
                'Models run 100% on-device for privacy.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          if (hasError && state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColors.rose500, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Model selection
  // ──────────────────────────────────────────────────────────────────
  Widget _modelSelectionCard() {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(GemmaService.presets.length, (i) {
          final preset = GemmaService.presets[i];
          final selected = _selectedPresetIndex == i;
          return Padding(
            padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
            child: InkWell(
              onTap: () => setState(() => _selectedPresetIndex = i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.indigo500 : Colors.white12,
                    width: selected ? 2 : 1,
                  ),
                  color: selected
                      ? AppColors.indigo500.withAlpha(25)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? AppColors.indigo500
                          : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.displayName,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '~${preset.approxSizeMb} MB',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // HF Token input
  // ──────────────────────────────────────────────────────────────────
  Widget _tokenCard() {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Some models require a free Hugging Face token.\n'
            'Get one at huggingface.co/settings/tokens',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hfTokenCtrl,
            obscureText: !_showToken,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'hf_...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withAlpha(8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showToken ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(() => _showToken = !_showToken),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Action buttons
  // ──────────────────────────────────────────────────────────────────
  Widget _actionCard(GemmaState state, bool isReady, bool isDownloading) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!isReady && !isDownloading)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadModel,
                icon: const Icon(Icons.download),
                label: Text(
                  'Download ${GemmaService.presets[_selectedPresetIndex].displayName}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (isDownloading)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(gemmaServiceProvider.notifier).cancelDownload();
                },
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('Cancel Download'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose500,
                  side: const BorderSide(color: AppColors.rose500),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (isReady) ...[
            const Row(
              children: [
                Icon(Icons.verified, color: AppColors.emerald500, size: 16),
                SizedBox(width: 6),
                Text(
                  'Model installed and ready',
                  style:
                      TextStyle(color: AppColors.emerald500, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.slate900,
                      title: const Text('Delete Model',
                          style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'This will remove the downloaded AI model and free storage. '
                        'You can re-download it anytime.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: AppColors.rose500)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(gemmaServiceProvider.notifier).deleteModel();
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Model'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rose500,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // AICore informational badge
  // ──────────────────────────────────────────────────────────────────
  Widget _aicoreInfoCard() {
    final status = _aicoreStatus!;
    final isAvailable = status.modelReady;

    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            isAvailable ? Icons.auto_awesome : Icons.info_outlined,
            color: isAvailable ? AppColors.amber500 : Colors.white38,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAvailable
                  ? 'Google AICore (Gemini Nano) is also available on this device as an enhanced option.'
                  : 'Google AICore (Gemini Nano) is not available on this device. '
                      'It requires flagship hardware (Pixel 8+, Samsung S24+).',
              style: TextStyle(
                color: isAvailable ? Colors.white70 : Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.slate400,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}
