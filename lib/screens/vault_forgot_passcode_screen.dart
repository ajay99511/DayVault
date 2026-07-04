import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../services/vault_security_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/pin_widgets.dart';

/// Forgot-vault-passcode recovery: answer the 3 stored recovery questions
/// (2 of 3 must be correct), then set a new passcode. Only the credential is
/// reset — vaulted entries are never touched.
///
/// Pops with `true` after a successful reset.
class VaultForgotPasscodeScreen extends ConsumerStatefulWidget {
  const VaultForgotPasscodeScreen({super.key});

  @override
  ConsumerState<VaultForgotPasscodeScreen> createState() =>
      _VaultForgotPasscodeScreenState();
}

class _VaultForgotPasscodeScreenState
    extends ConsumerState<VaultForgotPasscodeScreen> {
  // 0: answer questions, 1: new passcode, 2: confirm passcode
  int _currentStep = 0;

  List<String> _questions = [];
  final List<TextEditingController> _answerControllers =
      List.generate(3, (_) => TextEditingController());

  String _newPin = '';
  String _confirmPin = '';

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final questions =
        await ref.read(vaultSecurityServiceProvider).getSecurityQuestions();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _isLoading = false;
      if (questions.length != 3) {
        _errorMessage =
            'Recovery questions are not configured for this vault.';
      }
    });
  }

  Future<void> _verifyAnswers() async {
    for (final controller in _answerControllers) {
      if (controller.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please answer all questions');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final answers = _answerControllers.map((c) => c.text.trim()).toList();
    final result = await ref
        .read(vaultSecurityServiceProvider)
        .verifySecurityQuestions(answers);

    if (!mounted) return;
    if (result.success) {
      setState(() {
        _isSubmitting = false;
        _currentStep = 1;
      });
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.error ?? 'Verification failed';
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleDigit(String digit) async {
    HapticFeedback.lightImpact();
    if (_currentStep == 1) {
      if (_newPin.length >= SecurityConstants.pinLength) return;
      setState(() => _newPin += digit);
      if (_newPin.length >= SecurityConstants.pinLength) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      if (_confirmPin.length >= SecurityConstants.pinLength) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length >= SecurityConstants.pinLength) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        if (_newPin == _confirmPin) {
          await _resetPasscode();
        } else {
          setState(() {
            _errorMessage = 'Passcodes do not match. Please try again.';
            _newPin = '';
            _confirmPin = '';
            _currentStep = 1;
          });
        }
      }
    }
  }

  void _handleBackspace() {
    if (_currentStep == 1 && _newPin.isNotEmpty) {
      setState(() => _newPin = _newPin.substring(0, _newPin.length - 1));
    } else if (_currentStep == 2 && _confirmPin.isNotEmpty) {
      setState(
          () => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _resetPasscode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final answers = _answerControllers.map((c) => c.text.trim()).toList();
    final result = await ref
        .read(vaultSecurityServiceProvider)
        .resetPasscodeViaSecurityQuestions(answers, _newPin);

    if (!mounted) return;
    if (result.success) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.error ?? 'Passcode reset failed';
        _newPin = '';
        _confirmPin = '';
        _currentStep = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoading || _isSubmitting
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.fuchsia500),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ResponsiveCenter(
                  maxWidth: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.amber500.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.amber500.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: AppColors.amber500,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'RESET VAULT PASSCODE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _currentStep == 0
                              ? 'Answer at least 2 of 3 recovery questions'
                              : _currentStep == 1
                                  ? 'Enter your new vault passcode'
                                  : 'Confirm your new vault passcode',
                          style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.rose500.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.rose500.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.rose500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (_currentStep == 0) _buildAnswersEntry(),
                      if (_currentStep == 1 || _currentStep == 2)
                        _buildPasscodeEntry(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAnswersEntry() {
    if (_questions.length != 3) return const SizedBox.shrink();
    return Column(
      children: [
        ...List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
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
                Text(
                  'Q${index + 1}: ${_questions[index]}',
                  style: const TextStyle(
                    color: AppColors.slate300,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerControllers[index],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Your answer',
                    hintStyle: const TextStyle(color: AppColors.slate600),
                    filled: true,
                    fillColor: AppColors.slate800.withValues(alpha: 0.5),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _verifyAnswers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fuchsia500,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'VERIFY ANSWERS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasscodeEntry() {
    final currentPin = _currentStep == 2 ? _confirmPin : _newPin;
    return Column(
      children: [
        PinDots(
          length: SecurityConstants.pinLength,
          filled: currentPin.length,
        ),
        const SizedBox(height: 40),
        Center(
          child: PinKeypad(
            onDigit: _handleDigit,
            onBackspace: _handleBackspace,
          ),
        ),
      ],
    );
  }
}
