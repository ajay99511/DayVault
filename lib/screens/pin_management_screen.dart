import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/security_service.dart';
import '../widgets/glass_widgets.dart';

class PinManagementScreen extends StatefulWidget {
  const PinManagementScreen({super.key});

  @override
  State<PinManagementScreen> createState() => _PinManagementScreenState();
}

class _PinManagementScreenState extends State<PinManagementScreen> {
  final _securityService = SecurityService();
  
  bool _isLoading = true;
  bool _pinIsSet = false;
  bool _securityQuestionsSet = false;
  bool _biometricAvailable = false;
  String _biometricStatus = '';

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

    setState(() {
      _pinIsSet = pinSet;
      _securityQuestionsSet = questionsSet;
      _biometricAvailable = bioAvailable;
      _biometricStatus = bioStatus;
      _isLoading = false;
    });
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
          title: const Text(
            'Change PIN',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.rose500.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.rose500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                TextField(
                  controller: oldPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Current PIN',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: AppColors.slate400),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (oldPinController.text.length < 4) {
                  setDialogState(() {
                    error = 'Enter your current PIN';
                  });
                  return;
                }

                if (newPinController.text.length < 4) {
                  setDialogState(() {
                    error = 'New PIN must be at least 4 digits';
                  });
                  return;
                }

                if (newPinController.text != confirmPinController.text) {
                  setDialogState(() {
                    error = 'New PINs do not match';
                  });
                  return;
                }

                setDialogState(() {
                  error = null;
                });

                final result = await _securityService.changePin(
                  oldPinController.text,
                  newPinController.text,
                );

                setDialogState(() {
                  if (result.success) {
                    Navigator.pop(ctx);
                  } else {
                    error = result.error ?? 'Failed to change PIN';
                  }
                });

                if (result.success && ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('PIN changed successfully'),
                      backgroundColor: AppColors.emerald500,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo500,
              ),
              child: const Text(
                'CHANGE',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetPinViaQuestionsDialog() async {
    if (!_securityQuestionsSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security questions not set up'),
          backgroundColor: AppColors.amber500,
        ),
      );
      return;
    }

    final questions = await _securityService.getSecurityQuestions();
    if (!mounted) return;
    final answerControllers = List.generate(
      questions.length,
      (_) => TextEditingController(),
    );
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? error;
    int step = 0; // 0 = answer questions, 1 = enter new PIN

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: Text(
            step == 0 ? 'Answer Security Questions' : 'Set New PIN',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: step == 0
                  ? [
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.rose500.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.rose500.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: AppColors.rose500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ...List.generate(questions.length, (index) {
                        return Column(
                          children: [
                            Text(
                              'Q${index + 1}: ${questions[index]}',
                              style: const TextStyle(
                                color: AppColors.slate300,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: answerControllers[index],
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Your answer',
                                hintStyle: TextStyle(color: AppColors.slate600),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                    ]
                  : [
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.rose500.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.rose500.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: AppColors.rose500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      TextField(
                        controller: newPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'New PIN',
                          labelStyle: TextStyle(color: AppColors.slate400),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Confirm New PIN',
                          labelStyle: TextStyle(color: AppColors.slate400),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: AppColors.slate400),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (step == 0) {
                  // Verify answers
                  final answers = answerControllers.map((c) => c.text.trim()).toList();
                  final result = await _securityService.verifySecurityQuestions(answers);

                  setDialogState(() {
                    if (result.success) {
                      step = 1;
                      error = null;
                    } else {
                      error = result.error ?? 'Verification failed';
                    }
                  });
                } else {
                  // Reset PIN
                  if (newPinController.text.length < 4) {
                    setDialogState(() {
                      error = 'PIN must be at least 4 digits';
                    });
                    return;
                  }

                  if (newPinController.text != confirmPinController.text) {
                    setDialogState(() {
                      error = 'PINs do not match';
                    });
                    return;
                  }

                  final answers = answerControllers.map((c) => c.text.trim()).toList();
                  final result = await _securityService.resetPinViaSecurityQuestions(
                    answers,
                    newPinController.text,
                  );

                  if (result.success) {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('PIN reset successfully'),
                          backgroundColor: AppColors.emerald500,
                        ),
                      );
                    }
                    await _loadSecurityStatus();
                  } else {
                    setDialogState(() {
                      error = result.error ?? 'Failed to reset PIN';
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo500,
              ),
              child: Text(
                step == 0 ? 'VERIFY' : 'RESET PIN',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPinViaBiometric() async {
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication not available'),
          backgroundColor: AppColors.amber500,
        ),
      );
      return;
    }

    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: const Text(
            'Reset PIN via Fingerprint',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.indigo500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.indigo500.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fingerprint, color: AppColors.indigo500, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will authenticate with your fingerprint to reset your PIN',
                          style: TextStyle(
                            color: AppColors.slate300,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.rose500.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.rose500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'New PIN',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                    labelStyle: TextStyle(color: AppColors.slate400),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: AppColors.slate400),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPinController.text.length < 4) {
                  setDialogState(() {
                    error = 'PIN must be at least 4 digits';
                  });
                  return;
                }

                if (newPinController.text != confirmPinController.text) {
                  setDialogState(() {
                    error = 'PINs do not match';
                  });
                  return;
                }

                setDialogState(() {
                  error = null;
                });

                final result = await _securityService.resetPinViaBiometric(
                  newPinController.text,
                );

                if (result.success) {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('PIN reset successfully'),
                        backgroundColor: AppColors.emerald500,
                      ),
                    );
                    await _loadSecurityStatus();
                  }
                } else {
                  setDialogState(() {
                    error = result.error ?? 'Failed to reset PIN';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo500,
              ),
              child: const Text(
                'AUTHENTICATE & RESET',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.slate950,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.indigo500),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PIN & Security',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Status
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _pinIsSet ? Icons.verified_user : Icons.security,
                        color: _pinIsSet ? AppColors.emerald500 : AppColors.amber500,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PIN Status',
                              style: TextStyle(
                                color: AppColors.slate400,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _pinIsSet ? 'ACTIVE' : 'NOT SET',
                              style: TextStyle(
                                color: _pinIsSet
                                    ? AppColors.emerald500
                                    : AppColors.amber500,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.slate800),
                  Row(
                    children: [
                      Icon(
                        _securityQuestionsSet
                            ? Icons.check_circle
                            : Icons.help_outline,
                        color: _securityQuestionsSet
                            ? AppColors.emerald500
                            : AppColors.amber500,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Security Questions',
                              style: TextStyle(
                                color: AppColors.slate400,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _securityQuestionsSet
                                  ? 'CONFIGURED'
                                  : 'NOT SET UP',
                              style: TextStyle(
                                color: _securityQuestionsSet
                                    ? AppColors.emerald500
                                    : AppColors.amber500,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.slate800),
                  Row(
                    children: [
                      Icon(
                        _biometricAvailable
                            ? Icons.fingerprint
                            : Icons.do_not_disturb_on,
                        color: _biometricAvailable
                            ? AppColors.emerald500
                            : AppColors.slate600,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Biometric Authentication',
                              style: TextStyle(
                                color: AppColors.slate400,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _biometricStatus,
                              style: TextStyle(
                                color: _biometricAvailable
                                    ? AppColors.emerald500
                                    : AppColors.slate600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            const Text(
              'SECURITY ACTIONS',
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Change PIN
                  if (_pinIsSet)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.indigo500.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset,
                          color: AppColors.indigo500,
                        ),
                      ),
                      title: const Text(
                        'Change PIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Update your secure PIN',
                        style: TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.slate400),
                      onTap: _showChangePinDialog,
                    ),
                  if (_pinIsSet)
                    Divider(color: Colors.white.withValues(alpha: 0.1)),

                  // Reset PIN via Security Questions
                  if (_pinIsSet)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amber500.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.help_outline,
                          color: AppColors.amber500,
                        ),
                      ),
                      title: const Text(
                        'Reset PIN via Security Questions',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Answer your security questions to reset',
                        style: TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.slate400),
                      onTap: _showResetPinViaQuestionsDialog,
                    ),
                  if (_pinIsSet)
                    Divider(color: Colors.white.withValues(alpha: 0.1)),

                  // Reset PIN via Biometric
                  if (_pinIsSet && _biometricAvailable)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.fuchsia500.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: AppColors.fuchsia500,
                        ),
                      ),
                      title: const Text(
                        'Reset PIN via Fingerprint',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Use biometric authentication to reset',
                        style: TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.slate400),
                      onTap: _resetPinViaBiometric,
                    ),
                  if (_pinIsSet && _biometricAvailable)
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.indigo500, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Security Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoItem('• PIN is encrypted using PBKDF2 with 100,000 iterations'),
                  _infoItem('• Security questions require 2/3 correct answers'),
                  _infoItem('• Account locks for 30 seconds after 5 failed attempts'),
                  _infoItem('• Biometric data never leaves your device'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.slate400,
          fontSize: 11,
        ),
      ),
    );
  }
}
