import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../models/objectbox_models.dart';
import '../services/android_aicore_service.dart';
import '../services/ai_model_registry_service.dart';
import '../widgets/glass_widgets.dart';

/// AI Settings screen — AICore-focused.
///
/// GGUF model management has been removed from the user-facing UI.
/// All GGUF-related code (services, models, runtime) is retained in the
/// codebase as a backup. See GGUF_REFERENCE.md for restoration instructions.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  bool _loading = true;
  String? _status;
  ObjectBoxAiRuntimeConfig? _config;
  AicoreStatus? _aicoreStatus;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    final registry = ref.read(aiModelRegistryServiceProvider);
    final config = await registry.getRuntimeConfig();
    final aicoreStatus =
        await ref.read(androidAicoreServiceProvider).getStatus();

    if (!mounted) return;
    setState(() {
      _config = config;
      _aicoreStatus = aicoreStatus;
      _loading = false;
    });
  }

  Future<void> _saveRuntimeConfig() async {
    final config = _config;
    if (config == null) return;
    // Ensure AICore is the selected engine.
    config.chatEngineIndex = 1;
    await ref.read(aiModelRegistryServiceProvider).saveRuntimeConfig(config);
    if (!mounted) return;
    setState(() => _status = 'Settings saved');
    await _refresh();
  }

  Future<void> _checkAicoreStatus() async {
    final status = await ref.read(androidAicoreServiceProvider).getStatus();
    if (!mounted) return;
    setState(() {
      _aicoreStatus = status;
      _status = 'AICore status: ${status.label}';
    });
  }

  Future<void> _downloadAicoreModel() async {
    setState(() => _status = 'Requesting model download...');
    final status =
        await ref.read(androidAicoreServiceProvider).requestDownload();
    if (!mounted) return;
    setState(() {
      _aicoreStatus = status;
      _status = 'AICore download state: ${status.label}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white70),
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
                          icon:
                              const Icon(Icons.refresh, color: Colors.white70),
                          onPressed: _refresh,
                        ),
                      ],
                    ),
                  ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GlassContainer(
                        borderRadius: 12,
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _status!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      children: [
                        _sectionTitle('AI ENGINE'),
                        const SizedBox(height: 8),
                        _aicoreCard(),
                        const SizedBox(height: 24),
                        _sectionTitle('GENERATION SETTINGS'),
                        const SizedBox(height: 8),
                        _generationSettingsCard(config),
                        const SizedBox(height: 24),
                        _sectionTitle('STATUS'),
                        const SizedBox(height: 8),
                        _diagnosticsCard(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _aicoreCard() {
    final status = _aicoreStatus;
    final isReady = status?.modelReady ?? false;
    final isDownloading = status?.code == AicoreStatus.downloading;
    final canDownload = status?.canDownload ?? false;

    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle : Icons.cloud_download_outlined,
                color: isReady ? AppColors.emerald500 : AppColors.amber500,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isReady
                      ? 'Google AI (Gemini Nano) — Ready'
                      : (isDownloading
                          ? 'Google AI (Gemini Nano) — Downloading...'
                          : 'Google AI (Gemini Nano) — Not Ready'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isReady
                ? 'On-device AI is ready. Your data stays private — all processing happens locally.'
                : 'Download the on-device AI model to enable local AI features. No internet needed after download.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if ((status?.message ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              status!.message!,
              style:
                  const TextStyle(color: AppColors.slate400, fontSize: 11),
            ),
          ],
          if (!isReady) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (canDownload || !isReady) ? _downloadAicoreModel : null,
                icon: isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(isDownloading
                    ? 'Downloading...'
                    : 'Download AI Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (isReady) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.verified_user,
                    color: AppColors.emerald500, size: 14),
                SizedBox(width: 6),
                Text(
                  'Powered by Google Gemini Nano',
                  style: TextStyle(color: AppColors.emerald500, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _generationSettingsCard(ObjectBoxAiRuntimeConfig? config) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            value: config?.aicoreAutoDownload ?? true,
            onChanged: (v) {
              if (config == null) return;
              setState(() => config.aicoreAutoDownload = v);
            },
            activeThumbColor: AppColors.indigo500,
            title: const Text(
              'Auto-download AI model',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            subtitle: const Text(
              'Automatically download updates when available',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Max output tokens',
                  style: TextStyle(color: Colors.white70)),
              const Spacer(),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue:
                      (config?.maxGenerationTokens ?? 220).toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    if (config == null) return;
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      config.maxGenerationTokens = parsed.clamp(64, 2048);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveRuntimeConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticsCard() {
    final status = _aicoreStatus;
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Engine', style: TextStyle(color: Colors.white54)),
              Spacer(),
              Text(
                'Android AICore (Gemini Nano)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Model Status',
                  style: TextStyle(color: Colors.white54)),
              const Spacer(),
              Text(
                status?.label ?? 'Unknown',
                style: TextStyle(
                  color: (status?.modelReady ?? false)
                      ? AppColors.emerald500
                      : AppColors.amber500,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Platform',
                  style: TextStyle(color: Colors.white54)),
              const Spacer(),
              Text(
                (status?.platformSupported ?? false)
                    ? 'Supported'
                    : 'Not Supported',
                style: TextStyle(
                  color: (status?.platformSupported ?? false)
                      ? Colors.white70
                      : AppColors.rose500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _checkAicoreStatus,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Refresh Status'),
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
