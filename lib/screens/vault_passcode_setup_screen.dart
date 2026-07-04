import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../config/security_questions.dart';
import '../services/vault_security_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/pin_widgets.dart';

/// First-time Privacy Vault passcode setup.
///
/// Steps: select 3 recovery questions → enter passcode → confirm passcode →
/// answer questions. No biometric step — the vault is passcode-only by
/// design (a second, independent credential from the app lock).
///
/// Pushed as a route; pops with `true` on success so callers (vault screen,
/// editor privacy toggle) can gate on completion.
class VaultPasscodeSetupScreen extends ConsumerStatefulWidget {
  const VaultPasscodeSetupScreen({super.key});

  @override
  ConsumerState<VaultPasscodeSetupScreen> createState() =>
      _VaultPasscodeSetupScreenState();
}

class _VaultPasscodeSetupScreenState
    extends ConsumerState<VaultPasscodeSetupScreen> {
  // 0: select questions, 1: enter passcode, 2: confirm, 3: answer questions
  int _currentStep = 0;

  List<String> _availableQuestions = [];
  final List<String> _selectedQuestions = [];

  String _pin = '';
  String _confirmPin = '';

  List<TextEditingController> _answerControllers = [];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _availableQuestions = SecurityQuestions.getRandomQuestions(count: 8);
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleQuestion(String question) {
    setState(() {
      if (_selectedQuestions.contains(question)) {
        _selectedQuestions.remove(question);
      } else if (_selectedQuestions.length < 3) {
        _selectedQuestions.add(question);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _proceedToPasscode() {
    if (_selectedQuestions.length != 3) {
      setState(
          () => _errorMessage = 'Please select exactly 3 recovery questions');
      return;
    }
    setState(() {
      _currentStep = 1;
      _errorMessage = null;
      _answerControllers = List.generate(3, (_) => TextEditingController());
    });
  }

  Future<void> _handleDigit(String digit) async {
    HapticFeedback.lightImpact();
    if (_currentStep == 1) {
      if (_pin.length >= SecurityConstants.pinLength) return;
      setState(() => _pin += digit);
      if (_pin.length >= SecurityConstants.pinLength) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      if (_confirmPin.length >= SecurityConstants.pinLength) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length >= SecurityConstants.pinLength) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        if (_pin == _confirmPin) {
          setState(() => _currentStep = 3);
        } else {
          setState(() {
            _errorMessage = 'Passcodes do not match. Please try again.';
            _pin = '';
            _confirmPin = '';
            _currentStep = 1;
          });
        }
      }
    }
  }

  void _handleBackspace() {
    if (_currentStep == 1 && _pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else if (_currentStep == 2 && _confirmPin.isNotEmpty) {
      setState(
          () => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _completeSetup() async {
    for (final controller in _answerControllers) {
      if (controller.text.trim().isEmpty) {
        setState(() =>
            _errorMessage = 'Please provide answers to all recovery questions');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vault = ref.read(vaultSecurityServiceProvider);

      final passcodeSet = await vault.setPasscode(_pin);
      if (!passcodeSet) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to set passcode. A vault passcode may already exist.';
        });
        return;
      }

      final answers = _answerControllers.map((c) => c.text.trim()).toList();
      final questionsSet =
          await vault.setSecurityQuestions(_selectedQuestions, answers);
      if (!questionsSet) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to save recovery questions';
        });
        return;
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Setup failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: SafeArea(
        child: _isLoading
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
                      const SizedBox(height: 40),
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.fuchsia500.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  AppColors.fuchsia500.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.shield_moon_outlined,
                            color: AppColors.fuchsia500,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'PRIVACY VAULT SETUP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _currentStep == 0
                              ? 'Select 3 recovery questions'
                              : _currentStep == 1
                                  ? 'Enter a vault passcode (different from your app PIN)'
                                  : _currentStep == 2
                                      ? 'Confirm your vault passcode'
                                      : 'Answer your recovery questions',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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
                      if (_currentStep == 0) _buildQuestionsSelection(),
                      if (_currentStep == 1 || _currentStep == 2)
                        _buildPasscodeEntry(),
                      if (_currentStep == 3) _buildAnswersEntry(),
                      const SizedBox(height: 40),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildQuestionsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected: ${_selectedQuestions.length}/3',
          style: TextStyle(
            color: _selectedQuestions.length == 3
                ? AppColors.emerald500
                : AppColors.slate400,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_availableQuestions.length, (index) {
          final question = _availableQuestions[index];
          final isSelected = _selectedQuestions.contains(question);
          return GestureDetector(
            onTap: () => _toggleQuestion(question),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.fuchsia500.withValues(alpha: 0.2)
                    : AppColors.slate900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.fuchsia500
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        isSelected ? AppColors.fuchsia500 : AppColors.slate600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.slate300,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPasscodeEntry() {
    final currentPin = _currentStep == 2 ? _confirmPin : _pin;
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

  Widget _buildAnswersEntry() {
    return Column(
      children: List.generate(3, (index) {
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
                'Q${index + 1}: ${_selectedQuestions[index]}',
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
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  if (_currentStep == 3) {
                    _currentStep = 2;
                  } else if (_currentStep == 2) {
                    _currentStep = 1;
                    _confirmPin = '';
                  } else if (_currentStep == 1) {
                    _currentStep = 0;
                    _pin = '';
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.slate600),
              ),
              child: const Text(
                'BACK',
                style: TextStyle(color: AppColors.slate400),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_currentStep == 0) {
                _proceedToPasscode();
              } else if (_currentStep == 3) {
                _completeSetup();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fuchsia500,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _currentStep == 3 ? 'COMPLETE SETUP' : 'NEXT',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
