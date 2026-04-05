import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/constants.dart';
import '../models/objectbox_models.dart';
import '../services/ai_model_registry_service.dart';
import '../services/ai_runtime_policy_service.dart';
import '../services/llama_runtime_service.dart';
import '../services/rag_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  bool _loading = true;
  String? _status;
  List<ObjectBoxAiModel> _chatModels = [];
  List<ObjectBoxAiModel> _embeddingModels = [];
  ObjectBoxAiRuntimeConfig? _config;
  LlamaRuntimeDiagnostics? _diagnostics;
  AiRuntimePolicy? _chatPolicy;

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
    final policyService = ref.read(aiRuntimePolicyServiceProvider);
    final chatModels = await registry.getModels(roleIndex: 0);
    final embeddingModels = await registry.getModels(roleIndex: 1);
    final config = await registry.getRuntimeConfig();
    final diagnostics = await LlamaRuntimeService.instance.getDiagnostics();
    final chatPolicy = await policyService.buildPolicy(forEmbedding: false);

    if (!mounted) return;
    setState(() {
      _chatModels = chatModels;
      _embeddingModels = embeddingModels;
      _config = config;
      _diagnostics = diagnostics;
      _chatPolicy = chatPolicy;
      _loading = false;
    });
  }

  Future<void> _importModel(int roleIndex) async {
    final result = await ref
        .read(aiModelRegistryServiceProvider)
        .pickAndImportModel(roleIndex: roleIndex);
    if (!mounted) return;
    setState(() => _status = result.message);
    await _refresh();
  }

  Future<void> _activateModel(ObjectBoxAiModel model) async {
    await ref.read(aiModelRegistryServiceProvider).activateModel(
          roleIndex: model.roleIndex,
          modelId: model.modelId,
        );
    if (!mounted) return;
    setState(() => _status = 'Activated ${model.displayName}');
    await _refresh();
  }

  Future<void> _deleteModel(ObjectBoxAiModel model) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.slate900,
            title: const Text('Delete model?',
                style: TextStyle(color: Colors.white)),
            content: Text(
              model.displayName,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: AppColors.rose500),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await ref.read(aiModelRegistryServiceProvider).deleteModel(model.modelId);
    if (!mounted) return;
    setState(() => _status = 'Deleted ${model.displayName}');
    await _refresh();
  }

  Future<void> _saveRuntimeConfig() async {
    final config = _config;
    if (config == null) return;
    await ref.read(aiModelRegistryServiceProvider).saveRuntimeConfig(config);
    if (!mounted) return;
    setState(() => _status = 'Runtime policy saved');
    await _refresh();
  }

  Future<void> _reindexNow() async {
    await ref.read(storageServiceProvider).enqueueReindexAllEntries();
    await ref.read(ragServiceProvider).kickWorker();
    if (!mounted) return;
    setState(() => _status = 'Full reindex queued');
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
                        _sectionTitle('MODEL REGISTRY'),
                        const SizedBox(height: 8),
                        _actionRow(
                          leftLabel: 'Import Chat Model',
                          leftAction: () => _importModel(0),
                          rightLabel: 'Import Embed Model',
                          rightAction: () => _importModel(1),
                        ),
                        const SizedBox(height: 10),
                        _modelListCard('Chat Models', _chatModels),
                        const SizedBox(height: 10),
                        _modelListCard('Embedding Models', _embeddingModels),
                        const SizedBox(height: 24),
                        _sectionTitle('RUNTIME POLICY'),
                        const SizedBox(height: 8),
                        GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Text('Backend',
                                      style: TextStyle(color: Colors.white70)),
                                  const Spacer(),
                                  DropdownButton<int>(
                                    value: config?.backendIndex ?? 0,
                                    dropdownColor: AppColors.slate900,
                                    style: const TextStyle(color: Colors.white),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 0, child: Text('Auto')),
                                      DropdownMenuItem(
                                          value: 1, child: Text('CPU')),
                                      DropdownMenuItem(
                                          value: 2, child: Text('Vulkan')),
                                    ],
                                    onChanged: (v) {
                                      if (config == null || v == null) return;
                                      setState(() => config.backendIndex = v);
                                    },
                                  ),
                                ],
                              ),
                              SwitchListTile(
                                value: config?.autoPolicy ?? true,
                                onChanged: (v) {
                                  if (config == null) return;
                                  setState(() => config.autoPolicy = v);
                                },
                                activeThumbColor: AppColors.indigo500,
                                title: const Text(
                                  'Auto device policy',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              SwitchListTile(
                                value:
                                    config?.pauseEmbeddingOnLowBattery ?? true,
                                onChanged: (v) {
                                  if (config == null) return;
                                  setState(() =>
                                      config.pauseEmbeddingOnLowBattery = v);
                                },
                                activeThumbColor: AppColors.indigo500,
                                title: const Text(
                                  'Pause embedding on low battery',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              Row(
                                children: [
                                  const Text(
                                    'Low battery threshold',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: 72,
                                    child: TextFormField(
                                      initialValue:
                                          (config?.lowBatteryThreshold ?? 20)
                                              .toString(),
                                      keyboardType: TextInputType.number,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        if (config == null) return;
                                        final parsed = int.tryParse(v);
                                        if (parsed != null) {
                                          config.lowBatteryThreshold =
                                              parsed.clamp(5, 80);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Forced context (0=auto)',
                                      style: TextStyle(color: Colors.white70)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 88,
                                    child: TextFormField(
                                      initialValue:
                                          (config?.forcedContextSize ?? 0)
                                              .toString(),
                                      keyboardType: TextInputType.number,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        if (config == null) return;
                                        final parsed = int.tryParse(v);
                                        if (parsed != null) {
                                          config.forcedContextSize =
                                              parsed.clamp(0, 8192);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Forced threads (0=auto)',
                                      style: TextStyle(color: Colors.white70)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 88,
                                    child: TextFormField(
                                      initialValue: (config?.forcedThreads ?? 0)
                                          .toString(),
                                      keyboardType: TextInputType.number,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        if (config == null) return;
                                        final parsed = int.tryParse(v);
                                        if (parsed != null) {
                                          config.forcedThreads =
                                              parsed.clamp(0, 24);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Forced GPU layers (-1=auto)',
                                      style: TextStyle(color: Colors.white70)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 88,
                                    child: TextFormField(
                                      initialValue:
                                          (config?.forcedGpuLayers ?? -1)
                                              .toString(),
                                      keyboardType: TextInputType.number,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        if (config == null) return;
                                        final parsed = int.tryParse(v);
                                        if (parsed != null) {
                                          config.forcedGpuLayers =
                                              parsed.clamp(-1, 80);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Max output tokens',
                                      style: TextStyle(color: Colors.white70)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 72,
                                    child: TextFormField(
                                      initialValue:
                                          (config?.maxGenerationTokens ?? 220)
                                              .toString(),
                                      keyboardType: TextInputType.number,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        if (config == null) return;
                                        final parsed = int.tryParse(v);
                                        if (parsed != null) {
                                          config.maxGenerationTokens =
                                              parsed.clamp(64, 2048);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saveRuntimeConfig,
                                  child: const Text('Save Runtime Policy'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle('DIAGNOSTICS'),
                        const SizedBox(height: 8),
                        GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loaded: ${_diagnostics?.isLoaded == true ? "Yes" : "No"}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Backend: ${_diagnostics?.backendName ?? "N/A"}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'GPU layers: ${_diagnostics?.resolvedGpuLayers?.toString() ?? "N/A"}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Policy: ${_chatPolicy?.explanation ?? "N/A"}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              _actionRow(
                                leftLabel: 'Queue Full Reindex',
                                leftAction: _reindexNow,
                                rightLabel: 'Unload Runtime',
                                rightAction: () async {
                                  await LlamaRuntimeService.instance.dispose();
                                  if (!mounted) return;
                                  setState(() => _status = 'Runtime unloaded');
                                  await _refresh();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _modelListCard(String title, List<ObjectBoxAiModel> models) {
    final dateFormat = DateFormat('MMM d, HH:mm');
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (models.isEmpty)
            const Text('No models imported yet.',
                style: TextStyle(color: AppColors.slate400)),
          for (final model in models)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: model.isActive ? AppColors.indigo500 : Colors.white24,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.displayName,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (model.isActive)
                        const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: AppColors.emerald500,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(model.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB • ${dateFormat.format(model.importedAt)}',
                    style: const TextStyle(
                        color: AppColors.slate400, fontSize: 11),
                  ),
                  if (model.lastError != null && model.lastError!.isNotEmpty)
                    Text(
                      model.lastError!,
                      style: const TextStyle(
                          color: AppColors.rose500, fontSize: 11),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            model.isActive ? null : () => _activateModel(model),
                        child: const Text('Activate'),
                      ),
                      TextButton(
                        onPressed: () => _deleteModel(model),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.rose500)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String leftLabel,
    required VoidCallback leftAction,
    required String rightLabel,
    required VoidCallback rightAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: leftAction,
            child: Text(leftLabel, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: rightAction,
            child: Text(rightLabel, textAlign: TextAlign.center),
          ),
        ),
      ],
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
