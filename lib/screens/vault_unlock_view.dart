import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../services/vault_security_service.dart';
import '../theme/motion.dart';
import '../widgets/pin_widgets.dart';
import 'vault_forgot_passcode_screen.dart';

/// Passcode gate embedded inside the Privacy Vault screen (not a route) so
/// the unlocked state never outlives the vault route.
class VaultUnlockView extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const VaultUnlockView({super.key, required this.onUnlocked});

  @override
  ConsumerState<VaultUnlockView> createState() => _VaultUnlockViewState();
}

class _VaultUnlockViewState extends ConsumerState<VaultUnlockView>
    with SingleTickerProviderStateMixin {
  String pin = '';
  bool isError = false;
  String? errorMessage;
  int? remainingAttempts;
  int? remainingLockoutSeconds;
  bool isVerifying = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -10, end: 10)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleDigit(String val) async {
    if (isVerifying) return;
    if (pin.length >= SecurityConstants.pinLength) return;
    setState(() {
      pin += val;
      isError = false;
      errorMessage = null;
    });
    HapticFeedback.lightImpact();
    if (pin.length >= SecurityConstants.pinLength) {
      await _verify();
    }
  }

  Future<void> _verify() async {
    final reduceMotion = Motion.reduceMotion(context);
    setState(() => isVerifying = true);

    final result =
        await ref.read(vaultSecurityServiceProvider).verifyPasscode(pin);
    if (!mounted) return;

    if (result.success) {
      HapticFeedback.heavyImpact();
      // The parent swaps this view out for the vault content.
      widget.onUnlocked();
      return;
    }

    setState(() {
      isVerifying = false;
      isError = true;
      errorMessage = result.error;
      remainingAttempts = result.remainingAttempts;
      remainingLockoutSeconds = result.remainingLockoutSeconds;
    });
    HapticFeedback.mediumImpact();
    if (!reduceMotion) _shakeController.forward(from: 0);

    if (result.remainingLockoutSeconds == null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            pin = '';
            isError = false;
            errorMessage = null;
          });
        }
      });
    } else {
      setState(() => pin = '');
    }
  }

  void _handleBackspace() {
    if (pin.isEmpty) return;
    setState(() {
      pin = pin.substring(0, pin.length - 1);
      isError = false;
      errorMessage = null;
    });
    HapticFeedback.lightImpact();
  }

  void _openForgotFlow() async {
    final reset = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VaultForgotPasscodeScreen()),
    );
    if (reset == true && mounted) {
      setState(() {
        pin = '';
        isError = false;
        errorMessage = null;
        remainingAttempts = null;
        remainingLockoutSeconds = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                isError ? Icons.error_outline : Icons.shield_moon_outlined,
                color: isError ? AppColors.rose500 : AppColors.fuchsia500,
                size: 40,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'PRIVACY VAULT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ENTER VAULT PASSCODE',
              style: TextStyle(
                color: isError ? AppColors.rose500 : AppColors.slate400,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            if (errorMessage != null)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: PinDots(
                length: SecurityConstants.pinLength,
                filled: pin.length,
                isError: isError,
              ),
            ),
            const SizedBox(height: 16),
            if (isVerifying)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.fuchsia500,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'UNLOCKING…',
                    style: TextStyle(
                      color: AppColors.slate400,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            if (remainingAttempts != null && !isError && !isVerifying)
              Text(
                '$remainingAttempts attempts remaining',
                style: const TextStyle(
                  color: AppColors.slate400,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            const SizedBox(height: 40),
            PinKeypad(
              onDigit: _handleDigit,
              onBackspace: _handleBackspace,
              enabled: !isVerifying,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _openForgotFlow,
              child: const Text(
                'Forgot passcode?',
                style: TextStyle(
                  color: AppColors.amber500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
