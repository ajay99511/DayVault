import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../services/security_service.dart';

class ForgotPinScreen extends StatefulWidget {
  final VoidCallback onPinReset;
  
  const ForgotPinScreen({super.key, required this.onPinReset});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _securityService = SecurityService();
  
  // Reset method: 0 = security questions, 1 = biometric
  int _resetMethod = 0;
  bool _isLoading = true;
  bool _biometricAvailable = false;
  
  // Security questions
  List<String> _questions = [];
  List<TextEditingController> _answerControllers = [];
  
  // New PIN entry after verification
  String _newPin = '';
  String _confirmPin = '';
  int _pinStep = 0; // 0 = answer questions/biometric, 1 = enter new PIN, 2 = confirm PIN
  
  String? _errorMessage;
  int? _correctAnswers;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final bioAvailable = await _securityService.isBiometricAvailable();
    final questions = await _securityService.getSecurityQuestions();
    
    setState(() {
      _biometricAvailable = bioAvailable;
      _questions = questions;
      _isLoading = false;
      _answerControllers = List.generate(questions.length, (_) => TextEditingController());
      
      // If no security questions set, default to biometric
      if (questions.isEmpty && bioAvailable) {
        _resetMethod = 1;
      }
    });
  }

  Future<void> _verifyAnswers() async {
    if (_answerControllers.any((c) => c.text.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Please answer all questions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final answers = _answerControllers.map((c) => c.text.trim()).toList();
    final result = await _securityService.verifySecurityQuestions(answers);

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      setState(() {
        _pinStep = 1;
        _errorMessage = null;
      });
      HapticFeedback.heavyImpact();
    } else {
      setState(() {
        _errorMessage = result.error;
        _correctAnswers = result.correctCount;
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _resetViaBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pinStep = 1;
    });
  }

  Future<void> _handlePinEntry(String digit) async {
    if (_newPin.length < 6) {
      setState(() {
        _newPin += digit;
      });
      HapticFeedback.lightImpact();

      if (_newPin.length >= 4) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _pinStep = 2);
      }
    }
  }

  Future<void> _handleConfirmPinEntry(String digit) async {
    if (_confirmPin.length < 6) {
      setState(() {
        _confirmPin += digit;
      });
      HapticFeedback.lightImpact();

      if (_confirmPin.length >= 4) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _completeReset();
      }
    }
  }

  Future<void> _completeReset() async {
    if (_newPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _newPin = '';
        _confirmPin = '';
        _pinStep = 1;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      PinVerificationResult result;
      
      if (_resetMethod == 0) {
        // Security questions verification already done, just reset PIN
        final answers = _answerControllers.map((c) => c.text.trim()).toList();
        result = await _securityService.resetPinViaSecurityQuestions(answers, _newPin);
      } else {
        // Biometric reset
        result = await _securityService.resetPinViaBiometric(_newPin);
      }

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        HapticFeedback.heavyImpact();
        widget.onPinReset();
      } else {
        setState(() {
          _errorMessage = result.error ?? 'PIN reset failed';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Reset failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleBackspace() async {
    if (_pinStep == 1 && _newPin.isNotEmpty) {
      setState(() => _newPin = _newPin.substring(0, _newPin.length - 1));
    } else if (_pinStep == 2 && _confirmPin.isNotEmpty) {
      setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.slate950,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.indigo500),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.indigo500),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Header
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
                        child: Icon(
                          _pinStep == 0
                              ? Icons.help_outline
                              : Icons.lock_reset,
                          color: AppColors.amber500,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'RESET YOUR PIN',
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
                        _pinStep == 0
                            ? 'Verify your identity'
                            : _pinStep == 1
                                ? 'Enter new PIN'
                                : 'Confirm new PIN',
                        style: const TextStyle(
                          color: AppColors.slate400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Error message
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
                        child: Column(
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.rose500,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_correctAnswers != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '$_correctAnswers/3 answers correct',
                                  style: const TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Step 0: Choose reset method and verify
                    if (_pinStep == 0) _buildResetMethodSelection(),

                    // Step 1 & 2: PIN entry
                    if (_pinStep == 1 || _pinStep == 2) _buildPinEntry(),

                    const SizedBox(height: 40),

                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildResetMethodSelection() {
    // If both methods available, show selection
    if (_questions.isNotEmpty && _biometricAvailable) {
      return Column(
        children: [
          // Security Questions Option
          GestureDetector(
            onTap: () => setState(() => _resetMethod = 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _resetMethod == 0
                    ? AppColors.indigo500.withValues(alpha: 0.2)
                    : AppColors.slate900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _resetMethod == 0
                      ? AppColors.indigo500
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: _resetMethod == 0
                        ? AppColors.indigo500
                        : AppColors.slate400,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Questions',
                          style: TextStyle(
                            color: _resetMethod == 0
                                ? Colors.white
                                : AppColors.slate300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Answer your security questions',
                          style: TextStyle(
                            color: _resetMethod == 0
                                ? AppColors.slate300
                                : AppColors.slate500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _resetMethod == 0
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _resetMethod == 0
                        ? AppColors.indigo500
                        : AppColors.slate600,
                  ),
                ],
              ),
            ),
          ),

          // Biometric Option
          GestureDetector(
            onTap: () => setState(() => _resetMethod = 1),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _resetMethod == 1
                    ? AppColors.indigo500.withValues(alpha: 0.2)
                    : AppColors.slate900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _resetMethod == 1
                      ? AppColors.indigo500
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fingerprint,
                    color: _resetMethod == 1
                        ? AppColors.indigo500
                        : AppColors.slate400,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fingerprint',
                          style: TextStyle(
                            color: _resetMethod == 1
                                ? Colors.white
                                : AppColors.slate300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use biometric authentication',
                          style: TextStyle(
                            color: _resetMethod == 1
                                ? AppColors.slate300
                                : AppColors.slate500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _resetMethod == 1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _resetMethod == 1
                        ? AppColors.indigo500
                        : AppColors.slate600,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Show security questions if selected
          if (_resetMethod == 0) _buildQuestionsForm(),
        ],
      );
    }

    // Only security questions available
    if (_questions.isNotEmpty) {
      return _buildQuestionsForm();
    }

    // Only biometric available
    if (_biometricAvailable) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate900.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.fingerprint,
                  color: AppColors.indigo500,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'Fingerprint Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You will authenticate with your fingerprint to reset your PIN',
                  style: TextStyle(
                    color: AppColors.slate400,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Neither available
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.rose500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.rose500.withValues(alpha: 0.3),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.warning,
            color: AppColors.rose500,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No Recovery Methods Available',
            style: TextStyle(
              color: AppColors.rose500,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please set up security questions or biometrics in your device settings to enable PIN recovery.',
            style: TextStyle(
              color: AppColors.slate400,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsForm() {
    return Column(
      children: List.generate(_questions.length, (index) {
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
    );
  }

  Widget _buildPinEntry() {
    final isConfirm = _pinStep == 2;
    final currentPin = isConfirm ? _confirmPin : _newPin;

    return Column(
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: index < currentPin.length ? 16 : 12,
              height: index < currentPin.length ? 16 : 12,
              decoration: BoxDecoration(
                color: index < currentPin.length
                    ? AppColors.amber500
                    : AppColors.slate800,
                shape: BoxShape.circle,
                boxShadow: index < currentPin.length
                    ? [
                        BoxShadow(
                          color: AppColors.amber500.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 40),

        // Keypad
        SizedBox(
          width: 280,
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              ...List.generate(9, (i) => _buildKey('${i + 1}', isConfirm)),
              const SizedBox(width: 70),
              _buildKey('0', isConfirm),
              _buildKey('DEL', isConfirm, icon: Icons.backspace_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String val, bool isConfirm, {IconData? icon}) {
    return GestureDetector(
      onTap: () {
        if (icon == Icons.backspace_outlined) {
          _handleBackspace();
        } else {
          if (isConfirm) {
            _handleConfirmPinEntry(val);
          } else {
            _handlePinEntry(val);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: icon != null
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, color: AppColors.amber500, size: 28)
            : Text(
                val,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_pinStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  if (_pinStep == 2) {
                    _pinStep = 1;
                    _confirmPin = '';
                  } else if (_pinStep == 1) {
                    _pinStep = 0;
                    _newPin = '';
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
        if (_pinStep > 0) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_pinStep == 0) {
                if (_resetMethod == 0) {
                  _verifyAnswers();
                } else {
                  _resetViaBiometric();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pinStep == 0
                  ? AppColors.amber500
                  : AppColors.indigo500,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _resetMethod == 1 && _pinStep == 0
                  ? 'AUTHENTICATE'
                  : _pinStep == 0
                      ? 'VERIFY'
                      : 'CONTINUE',
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
