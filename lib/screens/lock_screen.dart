import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String pin = '';
  bool isError = false;

  void handleTap(String val) {
    if (pin.length < 4) {
      setState(() {
        pin += val;
        isError = false;
      });
      HapticFeedback.lightImpact();

      if (pin.length == 4) {
        if (pin == '1234') {
          HapticFeedback.heavyImpact();
          widget.onUnlock();
        } else {
          HapticFeedback.mediumImpact();
          setState(() => isError = true);
          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() => pin = '');
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.slate900.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.indigo500,
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
              const Text(
                "IDENTITY ENCRYPTED",
                style: TextStyle(
                  color: AppColors.slate400,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: pin.length > index
                          ? (isError ? AppColors.rose500 : AppColors.indigo500)
                          : AppColors.slate800,
                      shape: BoxShape.circle,
                      boxShadow: pin.length > index
                          ? [
                              BoxShadow(
                                color:
                                    (isError
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
              const SizedBox(height: 60),

              // Keypad
              SizedBox(
                width: 280,
                child: Wrap(
                  spacing: 30,
                  runSpacing: 30,
                  alignment: WrapAlignment.center,
                  children: [
                    ...List.generate(9, (i) => _buildKey('${i + 1}')),
                    const SizedBox(
                      width: 70,
                      height: 70,
                    ), // Spacer for biometric
                    _buildKey('0'),
                    _buildKey('BIO', icon: Icons.fingerprint),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                "BIOMETRICS ACTIVE",
                style: TextStyle(
                  color: AppColors.slate800,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String val, {IconData? icon}) {
    return GestureDetector(
      onTap: () => icon != null ? widget.onUnlock() : handleTap(val),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: icon != null
            ? Icon(icon, color: AppColors.indigo500, size: 32)
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
