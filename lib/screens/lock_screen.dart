import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../config/constants.dart';
import '../services/security_service.dart';
import 'pin_setup_screen.dart';
import 'forgot_pin_screen.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final _securityService = SecurityService();
  final _auth = LocalAuthentication();
  
  String pin = '';
  bool isError = false;
  String? errorMessage;
  int? remainingAttempts;
  int? remainingLockoutSeconds;
  bool isLoading = true;
  bool isPinSet = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -10, end: 10).chain(
      CurveTween(curve: Curves.easeInOut),
    ).animate(_shakeController);
    _initializeSecurity();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _initializeSecurity() async {
    await _securityService.initialize();
    final pinIsSet = await _securityService.isPinSet();
    if (mounted) {
      setState(() {
        isPinSet = pinIsSet;
        isLoading = false;
      });
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        _showError('Biometric authentication not available');
        return;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to access Memory Palace',
      );

      if (didAuthenticate) {
        await _securityService.initialize(); // Reset attempts on biometric success
        HapticFeedback.heavyImpact();
        widget.onUnlock();
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
      _showError('Biometric authentication failed');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        isError = true;
        errorMessage = message;
      });
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            pin = '';
            isError = false;
            errorMessage = null;
          });
        }
      });
    }
  }

  Future<void> handleTap(String val) async {
    if (isLoading) return;
    
    if (pin.length < 6) {
      setState(() {
        pin += val;
        isError = false;
        errorMessage = null;
      });
      HapticFeedback.lightImpact();

      if (pin.length >= 4) {
        // Auto-verify when 4+ digits entered
        await _verifyPin();
      }
    }
  }

  Future<void> _verifyPin() async {
    if (pin.length < 4) return;

    final result = await _securityService.verifyPin(pin);

    if (result.success) {
      HapticFeedback.heavyImpact();
      widget.onUnlock();
    } else {
      setState(() {
        isError = true;
        errorMessage = result.error;
        remainingAttempts = result.remainingAttempts;
        remainingLockoutSeconds = result.remainingLockoutSeconds;
      });
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
      
      if (result.success == false && result.remainingLockoutSeconds == null) {
        // Clear PIN after short delay if not locked out
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              pin = '';
              isError = false;
              errorMessage = null;
            });
          }
        });
      }
    }
  }

  Future<void> _handleBackspace() async {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
        isError = false;
        errorMessage = null;
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.slate950,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.indigo500,
          ),
        ),
      );
    }

    // If PIN is not set, show setup screen
    if (!isPinSet) {
      return PinSetupScreen(
        onSetupComplete: () {
          setState(() {
            isPinSet = true;
          });
          widget.onUnlock();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: Stack(
        children: [
          // Glow Background
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.indigo500.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo500.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.slate900.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isError
                          ? AppColors.rose500.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    isError ? Icons.error_outline : Icons.lock_outline,
                    color: isError ? AppColors.rose500 : AppColors.indigo500,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "MEMORY PALACE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPinSet ? "IDENTITY ENCRYPTED" : "SET YOUR SECURE PIN",
                  style: TextStyle(
                    color: isError ? AppColors.rose500 : AppColors.slate400,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 48),

                // Error Message
                if (errorMessage != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.rose500.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.rose500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      6,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: index < pin.length ? 16 : 12,
                        height: index < pin.length ? 16 : 12,
                        decoration: BoxDecoration(
                          color: index < pin.length
                              ? (isError
                                  ? AppColors.rose500
                                  : AppColors.indigo500)
                              : AppColors.slate800,
                          shape: BoxShape.circle,
                          boxShadow: index < pin.length
                              ? [
                                  BoxShadow(
                                    color: (isError
                                            ? AppColors.rose500
                                            : AppColors.indigo500)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Remaining attempts
                if (remainingAttempts != null && !isError)
                  Text(
                    '$remainingAttempts attempts remaining',
                    style: const TextStyle(
                      color: AppColors.slate400,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
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
                      ...List.generate(9, (i) => _buildKey('${i + 1}')),
                      _buildKey('BIO', icon: Icons.fingerprint),
                      _buildKey('0'),
                      _buildKey('DEL', icon: Icons.backspace_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Forgot PIN button
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPinScreen(
                          onPinReset: () {
                            Navigator.pop(context);
                            setState(() {
                              pin = '';
                              isError = false;
                              errorMessage = null;
                            });
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: AppColors.amber500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Security status
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield,
                      size: 12,
                      color: AppColors.emerald500,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "PBKDF2 ENCRYPTED",
                      style: TextStyle(
                        color: AppColors.emerald500,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "BIOMETRIC AUTHENTICATION",
                  style: TextStyle(
                    color: AppColors.slate800,
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String val, {IconData? icon}) {
    final isAction = icon != null;
    
    return GestureDetector(
      onTap: () {
        if (isAction) {
          if (icon == Icons.fingerprint) {
            _authenticateBiometric();
          } else if (icon == Icons.backspace_outlined) {
            _handleBackspace();
          }
        } else {
          handleTap(val);
        }
      },
      onLongPress: isAction && icon == Icons.backspace_outlined
          ? () async {
              // Long press to clear all
              while (pin.isNotEmpty) {
                await _handleBackspace();
                await Future.delayed(const Duration(milliseconds: 100));
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAction
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
}
