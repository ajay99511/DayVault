import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_tokens.dart';
import 'glass_widgets.dart';

/// Uppercase, letter-spaced section header used to label groups of content
/// (e.g. "COGNITIVE METRICS", "DATA MANAGEMENT").
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        color: context.tokens.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

/// Circular, glass-tinted icon button with a built-in ≥48dp tap target and a
/// semantic label for screen readers.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String label;
  final Color? color;
  final double iconSize;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.color,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onPressed,
          radius: 28,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.surfaceGlassFill,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.glassBorder),
              ),
              child: Icon(icon, color: color ?? tokens.textPrimary, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary call-to-action with the brand accent gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color>? gradientColors;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.gradientColors,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: gradientColors ?? tokens.accentGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined, tinted glass button used for secondary actions (Edit / Delete).
class GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labeled, token-styled text field used inside glass sheets/dialogs.
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: tokens.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(color: tokens.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.outfit(color: tokens.textDisabled, fontSize: 14),
            filled: true,
            fillColor: tokens.surfaceGlassFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tokens.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tokens.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tokens.accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Rounded-top modal sheet shell with the app's frosted surface and a grab
/// handle. Wrap sheet content with this for a consistent look.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final double? height;

  const AppBottomSheet({super.key, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: tokens.surfaceBase.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: tokens.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40),
        ],
      ),
      child: child,
    );
  }
}

/// A glass stat tile: icon, value, label. Used by the Profile metrics grid and
/// available to any feature that wants a compact KPI card.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double valueFontSize;
  final int valueMaxLines;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.valueFontSize = 24,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: valueMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: valueFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textTertiary,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
