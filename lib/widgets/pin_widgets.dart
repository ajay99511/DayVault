import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Shared always-dark PIN entry widgets used by the Privacy Vault screens.
/// Visuals mirror the app lock screen (lock_screen.dart) so all credential
/// surfaces look identical; the app-lock screens keep their own copies for
/// now to avoid destabilizing them.

/// Row of PIN progress dots with fill/glow styling.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool isError;

  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < filled;
        final fillColor = isError ? AppColors.rose500 : AppColors.indigo500;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isFilled ? 16 : 12,
          height: isFilled ? 16 : 12,
          decoration: BoxDecoration(
            color: isFilled ? fillColor : AppColors.slate800,
            shape: BoxShape.circle,
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: fillColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}

/// Numeric keypad (1-9, 0, backspace) with an optional extra key in the
/// bottom-left slot. Digits report via [onDigit].
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  /// Optional widget for the bottom-left slot (e.g. a biometric key); an
  /// empty spacer is used when null.
  final Widget? extraKey;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.extraKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          ...List.generate(9, (i) => _digitKey('${i + 1}')),
          extraKey ?? const SizedBox(width: 70, height: 70),
          _digitKey('0'),
          _key(
            semanticLabel: 'Delete last digit',
            onTap: onBackspace,
            child: const Icon(Icons.backspace_outlined,
                color: AppColors.indigo500, size: 28),
            isAction: true,
          ),
        ],
      ),
    );
  }

  Widget _digitKey(String val) {
    return _key(
      semanticLabel: val,
      onTap: () => onDigit(val),
      child: Text(
        val,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _key({
    required String semanticLabel,
    required VoidCallback onTap,
    required Widget child,
    bool isAction = false,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
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
          child: child,
        ),
      ),
    );
  }
}
