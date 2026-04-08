import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../config/security_questions.dart';
import '../services/security_service.dart';

class PinSetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;
  
  const PinSetupScreen({super.key, required this.onSetupComplete});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _securityService = SecurityService();
  
  // Setup steps
  int _currentStep = 0; // 0: Select questions, 1: Set PIN, 2: Confirm PIN, 3: Answer questions
  
  // Questions selection
  List<String> _availableQuestions = [];
  List<String> _selectedQuestions = [];
  
  // PIN entry
  String _pin = '';
  String _confirmPin = '';
  
  // Security questions answers
  List<TextEditingController> _answerControllers = [];
  
  bool _isLoading = false;
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
    setState(() {
      _availableQuestions = SecurityQuestions.getRandomQuestions(count: 8);
    });
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

  Future<void> _proceedToPinSetup() async {
    if (_selectedQuestions.length != 3) {
      setState(() {
        _errorMessage = 'Please select exactly 3 security questions';
      });
      return;
    }

    setState(() {
      _currentStep = 1;
      _errorMessage = null;
      _answerControllers = List.generate(3, (_) => TextEditingController());
    });
  }

  Future<void> _handlePinEntry(String digit) async {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
      });
      HapticFeedback.lightImpact();

      if (_pin.length >= 4) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_currentStep == 1) {
          setState(() => _currentStep = 2);
        }
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
        if (_pin == _confirmPin) {
          setState(() => _currentStep = 3);
        } else {
          setState(() {
            _errorMessage = 'PINs do not match. Please try again.';
            _pin = '';
            _confirmPin = '';
            _currentStep = 1;
          });
        }
      }
    }
  }

  Future<void> _handleBackspace() async {
    if (_currentStep == 1 && _pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    } else if (_currentStep == 2 && _confirmPin.isNotEmpty) {
      setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _completeSetup() async {
    // Validate answers
    for (int i = 0; i < _answerControllers.length; i++) {
      if (_answerControllers[i].text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please provide answers to all security questions';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Set PIN
      final pinSet = await _securityService.setPin(_pin);
      if (!pinSet) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to set PIN. PIN may already exist.';
        });
        return;
      }

      // Set security questions
      final answers = _answerControllers.map((c) => c.text.trim()).toList();
      final questionsSet = await _securityService.setSecurityQuestions(
        _selectedQuestions,
        answers,
      );

      if (!questionsSet) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to save security questions';
        });
        return;
      }

      // Enable security
      setState(() {
        _isLoading = false;
      });

      widget.onSetupComplete();
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
                          color: AppColors.indigo500.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.indigo500.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.security,
                          color: AppColors.indigo500,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'SET UP SECURITY',
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
                            ? 'Select 3 security questions'
                            : _currentStep == 1
                                ? 'Enter your secure PIN'
                                : _currentStep == 2
                                    ? 'Confirm your PIN'
                                    : 'Answer your security questions',
                        style: TextStyle(
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
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.rose500,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Step 0: Select questions
                    if (_currentStep == 0) _buildQuestionsSelection(),

                    // Step 1 & 2: PIN entry
                    if (_currentStep == 1 || _currentStep == 2)
                      _buildPinEntry(),

                    // Step 3: Answer questions
                    if (_currentStep == 3) _buildAnswersEntry(),

                    const SizedBox(height: 40),

                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
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
                    ? AppColors.indigo500.withValues(alpha: 0.2)
                    : AppColors.slate900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.indigo500
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.indigo500 : AppColors.slate600,
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

  Widget _buildPinEntry() {
    final isConfirm = _currentStep == 2;
    final currentPin = isConfirm ? _confirmPin : _pin;

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
                    ? AppColors.indigo500
                    : AppColors.slate800,
                shape: BoxShape.circle,
                boxShadow: index < currentPin.length
                    ? [
                        BoxShadow(
                          color: AppColors.indigo500.withValues(alpha: 0.5),
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
              const SizedBox(width: 70), // Empty space
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
            ? Icon(icon, color: AppColors.indigo500, size: 28)
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
                  hintStyle: TextStyle(color: AppColors.slate600),
                  filled: true,
                  fillColor: AppColors.slate800.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
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
                side: BorderSide(color: AppColors.slate600),
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
                _proceedToPinSetup();
              } else if (_currentStep == 3) {
                _completeSetup();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigo500,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _currentStep == 0 ? 'NEXT' : 'COMPLETE SETUP',
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
