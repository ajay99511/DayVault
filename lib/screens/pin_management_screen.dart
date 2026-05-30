import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../config/constants.dart';
import '../models/types.dart';
import '../services/security_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import '../config/security_questions.dart';

class PinManagementScreen extends ConsumerStatefulWidget {
  const PinManagementScreen({super.key});

  @override
  ConsumerState<PinManagementScreen> createState() => _PinManagementScreenState();
}

class _PinManagementScreenState extends ConsumerState<PinManagementScreen> {
  final _securityService = SecurityService();
  
  bool _isLoading = true;
  bool _pinIsSet = false;
  bool _securityQuestionsSet = false;
  bool _biometricAvailable = false;
  String _biometricStatus = '';
  late UserSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    final pinSet = await _securityService.isPinSet();
    final questionsSet = await _securityService.areSecurityQuestionsSet();
    final bioAvailable = await _securityService.isBiometricAvailable();
    final bioStatus = await _securityService.getBiometricStatus();
    _settings = ref.read(storageServiceProvider).getSettings();

    if (mounted) {
      setState(() {
        _pinIsSet = pinSet;
        _securityQuestionsSet = questionsSet;
        _biometricAvailable = bioAvailable;
        _biometricStatus = bioStatus;
        _isLoading = false;
      });
    }
  }

  void _toggleBiometrics(bool value) async {
    if (value) {
      try {
        final didAuthenticate = await LocalAuthentication().authenticate(
          localizedReason: 'Authenticate to enable biometric login',
        );
        if (!didAuthenticate) return;
      } catch (e) {
        debugPrint('Biometric error: $e');
        return;
      }
    }

    final newSettings = _settings.copyWith(biometricsEnabled: value);
    await ref.read(storageServiceProvider).saveSettings(newSettings);
    setState(() {
      _settings = newSettings;
    });
  }

  Future<void> _showUpdateQuestionsDialog() async {
    final available = SecurityQuestions.getRandomQuestions(count: 8);
    final selected = <String>[];
    final answerControllers = List.generate(3, (_) => TextEditingController());
    String? error;
    int step = 0; // 0 = select, 1 = answer

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: Text(
            step == 0 ? 'Select Recovery Questions' : 'Provide Answers',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: AppColors.rose500, fontSize: 12)),
                  ),
                if (step == 0)
                  ...available.map((q) {
                    final isSelected = selected.contains(q);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(q, style: TextStyle(color: isSelected ? Colors.white : AppColors.slate400, fontSize: 13)),
                      leading: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? AppColors.indigo500 : AppColors.slate600),
                      onTap: () => setDialogState(() {
                        if (isSelected) selected.remove(q);
                        else if (selected.length < 3) selected.add(q);
                      }),
                    );
                  })
                else
                  ...List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: answerControllers[i],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: selected[i], 
                        labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 12),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: AppColors.slate400))),
            ElevatedButton(
              onPressed: () async {
                if (step == 0) {
                  if (selected.length != 3) {
                    setDialogState(() => error = 'Select exactly 3 questions');
                    return;
                  }
                  setDialogState(() { step = 1; error = null; });
                } else {
                  final answers = answerControllers.map((c) => c.text.trim()).toList();
                  if (answers.any((a) => a.isEmpty)) {
                    setDialogState(() => error = 'All answers required');
                    return;
                  }
                  final success = await _securityService.setSecurityQuestions(selected, answers);
                  if (success) {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security questions updated'), backgroundColor: AppColors.emerald500));
                      _loadSecurityStatus();
                    }
                  } else {
                    setDialogState(() => error = 'Failed to update questions');
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.indigo500),
              child: Text(step == 0 ? 'NEXT' : 'UPDATE', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDisableSecurityDialog() async {
    final pinController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: const Text('Delete Security Data?', style: TextStyle(color: AppColors.rose500)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This action will permanently delete your PIN, salts, and recovery questions. '
                'Security will be completely disabled. This is irreversible.',
                style: TextStyle(color: AppColors.slate400, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (error != null) Text(error!, style: const TextStyle(color: AppColors.rose500, fontSize: 12)),
              TextField(
                controller: pinController, 
                obscureText: true, 
                keyboardType: TextInputType.number, 
                maxLength: SecurityConstants.pinLength,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Verify Current PIN', labelStyle: TextStyle(color: AppColors.slate400)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: AppColors.slate400))),
            ElevatedButton(
              onPressed: () async {
                final result = await _securityService.removePin(pinController.text);
                if (result.success) {
                  final storage = ref.read(storageServiceProvider);
                  await storage.saveSettings(_settings.copyWith(securityEnabled: false, biometricsEnabled: false));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) Navigator.pop(context); // Go back to profile
                } else {
                  setDialogState(() => error = result.error ?? 'Verification failed');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500),
              child: const Text('DELETE EVERYTHING', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePinDialog() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: const Text('Change PIN', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: AppColors.rose500, fontSize: 12)),
                  ),
                TextField(controller: oldPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: SecurityConstants.pinLength, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Current PIN', labelStyle: TextStyle(color: AppColors.slate400))),
                const SizedBox(height: 8),
                TextField(controller: newPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: SecurityConstants.pinLength, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'New PIN', labelStyle: TextStyle(color: AppColors.slate400))),
                const SizedBox(height: 8),
                TextField(controller: confirmPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: SecurityConstants.pinLength, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Confirm New PIN', labelStyle: TextStyle(color: AppColors.slate400))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: AppColors.slate400))),
        ElevatedButton(
          onPressed: () async {
            if (newPinController.text.length < SecurityConstants.pinLength) {
              setDialogState(() => error = 'New PIN too short');
              return;
            }
            if (newPinController.text != confirmPinController.text) {
              setDialogState(() => error = 'New PINs do not match');
              return;
            }
            final result = await _securityService.changePin(oldPinController.text, newPinController.text);
            if (result.success) {
              Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN changed successfully'), backgroundColor: AppColors.emerald500));
            } else {
              setDialogState(() => error = result.error ?? 'Failed to change PIN');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.indigo500),
          child: const Text('CHANGE', style: TextStyle(color: Colors.white)),
        ),
      ],
        ),
      ),
    );
  }

  Future<void> _showResetPinViaQuestionsDialog() async {
    if (!_securityQuestionsSet) return;
    final questions = await _securityService.getSecurityQuestions();
    final answerControllers = List.generate(questions.length, (_) => TextEditingController());
    final newPinController = TextEditingController();
    String? error;
    int step = 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: Text(step == 0 ? 'Identity Recovery' : 'Set New PIN', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) Text(error!, style: const TextStyle(color: AppColors.rose500, fontSize: 12)),
              if (step == 0)
                ...List.generate(questions.length, (i) => TextField(
                  controller: answerControllers[i], 
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: questions[i], labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 12)),
                ))
              else
                TextField(
                  controller: newPinController, 
                  obscureText: true, 
                  keyboardType: TextInputType.number, 
                  maxLength: SecurityConstants.pinLength, 
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'New PIN', labelStyle: TextStyle(color: AppColors.slate400)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: AppColors.slate400))),
            ElevatedButton(
              onPressed: () async {
                if (step == 0) {
                  final result = await _securityService.verifySecurityQuestions(answerControllers.map((c) => c.text).toList());
                  if (result.success) setDialogState(() => step = 1);
                  else setDialogState(() => error = result.error ?? 'Verification failed');
                } else {
                  if (newPinController.text.length < SecurityConstants.pinLength) {
                    setDialogState(() => error = 'PIN too short');
                    return;
                  }
                  final result = await _securityService.resetPinViaSecurityQuestions(answerControllers.map((c) => c.text).toList(), newPinController.text);
                  if (result.success) {
                    Navigator.pop(ctx);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN reset successfully'), backgroundColor: AppColors.emerald500));
                    _loadSecurityStatus();
                  } else setDialogState(() => error = result.error ?? 'Failed to reset');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.indigo500),
              child: Text(step == 0 ? 'VERIFY' : 'RESET', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: AppColors.slate950, body: Center(child: CircularProgressIndicator(color: AppColors.indigo500)));

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('PIN & Security', style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            GlassContainer(
              child: Column(
                children: [
                  _statusRow('Vault Status', _pinIsSet ? 'ENCRYPTED' : 'UNSECURED', _pinIsSet ? Icons.verified_user : Icons.security, _pinIsSet ? AppColors.emerald500 : AppColors.amber500),
                  const Divider(color: AppColors.slate800),
                  _statusRow('Recovery', _securityQuestionsSet ? 'CONFIGURED' : 'NOT SET', Icons.help_outline, _securityQuestionsSet ? AppColors.emerald500 : AppColors.amber500),
                  const Divider(color: AppColors.slate800),
                  _statusRow('Biometrics', _biometricAvailable ? 'AVAILABLE' : 'NOT SUPPORTED', Icons.fingerprint, _biometricAvailable ? AppColors.emerald500 : AppColors.slate600),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text('SECURITY ACTIONS', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),

            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (_pinIsSet && _biometricAvailable)
                    SwitchListTile(
                      value: _settings.biometricsEnabled,
                      onChanged: _toggleBiometrics,
                      secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.emerald500.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.fingerprint, color: AppColors.emerald500, size: 20)),
                      title: const Text('Biometric Unlock', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Use fingerprint for faster access', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                      activeColor: AppColors.indigo500,
                    ),
                  if (_pinIsSet && _biometricAvailable) Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),

                  _actionTile(Icons.lock_reset, AppColors.indigo500, 'Change PIN', 'Update your ${SecurityConstants.pinLength}-digit passkey', _showChangePinDialog),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  _actionTile(Icons.help_outline, AppColors.fuchsia500, 'Update Recovery Questions', 'Modify recovery methods', _showUpdateQuestionsDialog),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  _actionTile(Icons.history, AppColors.amber500, 'Recovery Reset', 'Reset PIN via security questions', _showResetPinViaQuestionsDialog),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  _actionTile(Icons.delete_forever_outlined, AppColors.rose500, 'Delete All Security Data', 'Permanently wipe PIN and salts (DANGEROUS)', _showDisableSecurityDialog, isDestructive: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, Color color, String title, String subtitle, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(color: isDestructive ? AppColors.rose500 : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.slate400, size: 18),
      onTap: onTap,
    );
  }

  Widget _statusRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 10)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
