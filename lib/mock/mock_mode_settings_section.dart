import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../config/feature_flags.dart';
import '../providers/mock_mode_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_components.dart';
import '../widgets/glass_widgets.dart';

/// The Profile screen's demo-mode controls.
///
/// Lives in `lib/mock/` rather than inside `profile_screen.dart` so the entire
/// demo feature — fixtures, backend, wiring and UI — is one directory that can
/// be reviewed, or deleted, as a unit. The Profile screen contributes a single
/// line.
///
/// Renders nothing when the toggle has been compiled out with
/// `--dart-define=DAYVAULT_MOCK_DATA_TOGGLE=false`.
class MockModeSettingsSection extends ConsumerStatefulWidget {
  /// Called after the backend has actually swapped, so the host screen can
  /// re-read anything it holds in local state (the username, for instance,
  /// comes from settings and differs between real and demo data).
  final VoidCallback? onModeChanged;

  const MockModeSettingsSection({super.key, this.onModeChanged});

  @override
  ConsumerState<MockModeSettingsSection> createState() =>
      _MockModeSettingsSectionState();
}

class _MockModeSettingsSectionState
    extends ConsumerState<MockModeSettingsSection> {
  /// Guards against a second tap while the fixtures are being parsed.
  bool _busy = false;

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(mockModeProvider.notifier).setEnabled(enabled);
      widget.onModeChanged?.call();
      _toast(
        enabled
            ? 'Demo data on. Your real entries are untouched.'
            : 'Demo data off. Showing your own entries again.',
        AppColors.emerald500,
      );
    } catch (e) {
      // Only reachable when the fixtures fail to load, which means they are
      // broken or unregistered — a developer problem, so say so plainly
      // instead of showing a generic failure.
      _toast('Demo data could not be loaded: $e', AppColors.rose500);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    ref.read(mockModeProvider.notifier).resetData();
    widget.onModeChanged?.call();
    _toast('Demo data restored to its original state.', AppColors.emerald500);
  }

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.mockDataToggleVisible) return const SizedBox.shrink();

    final enabled = ref.watch(mockModeProvider);
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const SectionLabel('DEMO MODE'),
        const SizedBox(height: 16),
        GlassContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: enabled,
                onChanged: _busy ? null : _setEnabled,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amber500.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.amber500,
                          ),
                        )
                      : const Icon(Icons.science_outlined,
                          color: AppColors.amber500, size: 24),
                ),
                title: Text(
                  'Show demo data',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  enabled
                      ? 'Serving sample entries from memory. Your own data is '
                          'hidden and cannot be changed while this is on.'
                      : 'Fill the app with sample entries, rankings and a '
                          'vision board to explore or demo it.',
                  style: TextStyle(color: tokens.textTertiary, fontSize: 11),
                ),
              ),
              if (enabled) ...[
                Divider(color: tokens.divider),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.indigo500.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restart_alt,
                        color: AppColors.indigo500, size: 20),
                  ),
                  title: Text(
                    'Reset demo data',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Undo everything added, edited or deleted in this session',
                    style: TextStyle(color: tokens.textTertiary, fontSize: 11),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: tokens.textTertiary),
                  onTap: _reset,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
