import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../services/storage_service.dart';
import '../services/security_service.dart';
import '../services/backup_service.dart';
import 'pin_setup_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../models/stats.dart';
import '../providers/stats_provider.dart';
import '../config/constants.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../providers/theme_provider.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/app_components.dart';
import 'pin_management_screen.dart';
import 'privacy_vault_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserSettings settings = const UserSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads user settings only. Journaling statistics are sourced from
  /// [statsProvider]; this method intentionally no longer fetches the journal
  /// or computes the streak (that work now lives in [StatsNotifier]).
  Future<void> _load() async {
    final s = ref.read(storageServiceProvider).getSettings();
    if (mounted) {
      setState(() => settings = s);
    }
  }

  Future<void> _showUsernameEditDialog() async {
    final controller = TextEditingController(text: settings.username);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text('Edit Display Name',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Display name',
            labelStyle: TextStyle(color: AppColors.slate400),
            hintText: 'Journaler',
            hintStyle: TextStyle(color: AppColors.slate600),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.slate400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.indigo500),
            child:
                const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();

    // Null means the dialog was dismissed/cancelled — leave settings untouched.
    if (newName == null || newName == settings.username) return;

    final updated = settings.copyWith(username: newName);
    await ref.read(storageServiceProvider).saveSettings(updated);
    if (mounted) {
      setState(() => settings = updated);
    }
  }

  void _toggleSecurity() async {
    final securityService = SecurityService();
    final status = await securityService.getVaultStatus(settings.securityEnabled);

    if (status.needsSetup) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            onSetupComplete: () {
              Navigator.pop(context);
              _load();
            },
          ),
        ),
      );
    } else if (status.canReactivate) {
      _showReactivationVerification();
    } else {
      _showDisableSecurityVerification();
    }
  }

  Future<void> _showReactivationVerification() async {
    final securityService = SecurityService();

    if (settings.biometricsEnabled) {
      try {
        final didAuthenticate = await LocalAuthentication().authenticate(
          localizedReason: 'Authenticate to reactivate security',
        );
        if (didAuthenticate) {
          _enableSecurityAction();
          return;
        }
      } catch (e) {
        debugPrint('Biometric error: $e');
      }
    }

    if (!mounted) return;
    final pinController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: const Text('Activate Security',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your PIN to re-enable security features.',
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Text(error!,
                    style: const TextStyle(
                        color: AppColors.rose500, fontSize: 12)),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: SecurityConstants.pinLength,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  labelStyle: TextStyle(color: AppColors.slate400),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL',
                  style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              onPressed: () async {
                final result =
                    await securityService.verifyPin(pinController.text);
                if (result.success) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _enableSecurityAction();
                } else {
                  setDialogState(
                      () => error = result.error ?? 'Incorrect PIN');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo500),
              child: const Text('ACTIVATE',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableSecurityAction() async {
    final storage = ref.read(storageServiceProvider);
    final newSettings = settings.copyWith(securityEnabled: true);
    await storage.saveSettings(newSettings);
    if (mounted) {
      setState(() => settings = newSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security reactivated'),
          backgroundColor: AppColors.indigo500,
        ),
      );
    }
  }

  void _showDisableSecurityVerification() async {
    final securityService = SecurityService();

    if (settings.biometricsEnabled) {
      try {
        final didAuthenticate = await LocalAuthentication().authenticate(
          localizedReason: 'Authenticate to disable security',
        );
        if (didAuthenticate) {
          _disableSecurityAction();
          return;
        }
      } catch (e) {
        debugPrint('Biometric error: $e');
      }
    }

    if (!mounted) return;
    final pinController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate900,
          title: const Text('Verify PIN',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your PIN to disable security features.',
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Text(error!,
                    style: const TextStyle(
                        color: AppColors.rose500, fontSize: 12)),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: SecurityConstants.pinLength,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  labelStyle: TextStyle(color: AppColors.slate400),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL',
                  style: TextStyle(color: AppColors.slate400)),
            ),
            ElevatedButton(
              onPressed: () async {
                final result =
                    await securityService.verifyPin(pinController.text);
                if (result.success) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _disableSecurityAction();
                } else {
                  setDialogState(
                      () => error = result.error ?? 'Incorrect PIN');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo500),
              child: const Text('VERIFY',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disableSecurityAction() async {
    final storage = ref.read(storageServiceProvider);
    final newSettings = settings.copyWith(
      securityEnabled: false,
      biometricsEnabled: false,
    );
    await storage.saveSettings(newSettings);
    if (mounted) {
      setState(() => settings = newSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security disabled'),
          backgroundColor: AppColors.slate800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsProvider);
    final themeMode = ref.watch(themeModeProvider);

    // A journal mutation anywhere (this screen's restore, or the Journal/
    // Calendar/Viewer surfaces) bumps the shared revision. Profile is kept
    // alive in the IndexedStack, so without this the cached stats would stay
    // stale for the whole session — invalidate them so the metrics recompute.
    ref.listen(journalRevisionProvider, (_, __) => ref.invalidate(statsProvider));

    // Non-blocking notification on stats failure (Req 1.7). Using ref.listen
    // (not a build-time side effect) ensures the SnackBar fires only on the
    // transition into an error state, not on every rebuild.
    ref.listen<AsyncValue<JournalStats>>(statsProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load your insights'),
              backgroundColor: AppColors.rose500,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });

    final headerSubtitle = statsAsync.maybeWhen(
      data: (s) => '${s.totalEntries} entries · ${s.streak} day streak',
      orElse: () => 'Your journaling insights',
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 40,
          bottom: 120,
        ),
        child: ResponsiveCenter(
          horizontalPadding: 24,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            GlassContainer(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.indigo500,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (settings.username.isNotEmpty)
                          ? settings.username[0].toUpperCase()
                          : 'J',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.username.isNotEmpty
                              ? settings.username
                              : 'Journaler',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.tokens.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          headerSubtitle,
                          style: TextStyle(
                            color: context.tokens.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.slate400, size: 20),
                    tooltip: 'Edit display name',
                    onPressed: _showUsernameEditDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats Grid
            const SectionLabel("COGNITIVE METRICS"),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) => _statsGrid(stats),
              loading: () => _shimmerGrid(),
              // On error, fall back to zero/empty-state cards (Req 1.7); the
              // SnackBar above surfaces the failure non-blockingly.
              error: (_, __) => _statsGrid(JournalStats.empty),
            ),
            // Journaling-consistency chart — only once there are entries to plot.
            ...statsAsync.maybeWhen(
              data: (stats) => stats.totalEntries == 0
                  ? const <Widget>[]
                  : [
                      const SizedBox(height: 16),
                      _ConsistencyChart(
                          weeks: stats.entriesPerWeek,
                          color: AppColors.indigo500),
                    ],
              orElse: () => const <Widget>[],
            ),
            const SizedBox(height: 40),

            // Settings
            const SectionLabel("SYSTEM CONFIGURATION"),
            const SizedBox(height: 16),

            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Security Toggle
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: settings.securityEnabled
                                ? AppColors.indigo500.withValues(alpha: 0.2)
                                : AppColors.slate800,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            settings.securityEnabled
                                ? Icons.verified_user
                                : Icons.security,
                            color: settings.securityEnabled
                                ? AppColors.indigo500
                                : AppColors.slate400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "App Lock",
                                style: TextStyle(
                                  color: context.tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                settings.biometricsEnabled
                                    ? "Biometric unlock enrolled"
                                    : "Require a PIN on launch",
                                style: TextStyle(
                                  color: context.tokens.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: settings.securityEnabled,
                          onChanged: (_) => _toggleSecurity(),
                          activeThumbColor: AppColors.indigo500,
                        ),
                      ],
                    ),
                  ),
                  if (settings.securityEnabled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.indigo500.withValues(alpha: 0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.lock,
                              size: 12, color: AppColors.indigo500),
                          const SizedBox(width: 8),
                          Text(
                            settings.biometricsEnabled
                                ? "BIOMETRICS + PIN ACTIVE"
                                : "PIN LOCK ACTIVE",
                            style: const TextStyle(
                              color: AppColors.indigo500,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Appearance
            const SectionLabel("APPEARANCE"),
            const SizedBox(height: 16),
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined,
                          color: context.tokens.accent, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Theme',
                        style: TextStyle(
                          color: context.tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode, size: 18),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (sel) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(sel.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Data Management
            const SectionLabel("DATA MANAGEMENT"),
            const SizedBox(height: 16),

            GlassContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.fuchsia500.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security,
                          color: AppColors.fuchsia500, size: 24),
                    ),
                    title: Text(
                      'PIN & Security',
                      style: TextStyle(
                          color: context.tokens.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Manage PIN, security questions & biometrics',
                      style: TextStyle(
                          color: context.tokens.textTertiary, fontSize: 11),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: context.tokens.textTertiary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PinManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.tokens.divider),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.indigo500.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_moon_outlined,
                          color: AppColors.indigo500, size: 24),
                    ),
                    title: Text(
                      'Privacy Vault',
                      style: TextStyle(
                          color: context.tokens.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Hidden stories & events behind a separate passcode',
                      style: TextStyle(
                          color: context.tokens.textTertiary, fontSize: 11),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: context.tokens.textTertiary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyVaultScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: context.tokens.divider),
                  _backupTile(
                    context,
                    ref,
                    title: 'Export Backup',
                    subtitle: 'Save all your memories securely',
                    icon: Icons.backup,
                    iconColor: AppColors.emerald500,
                    encrypted: true,
                  ),
                  Divider(color: context.tokens.divider),
                  _backupTile(
                    context,
                    ref,
                    title: 'Export Unencrypted',
                    subtitle: 'Readable JSON format (not recommended)',
                    icon: Icons.file_download,
                    iconColor: AppColors.amber500,
                    encrypted: false,
                  ),
                  Divider(color: context.tokens.divider),
                  _manageBackupsTile(context, ref),
                  Divider(color: context.tokens.divider),
                  _importBackupTile(context, ref),
                  Divider(color: context.tokens.divider),
                  _manageTagsTile(context, ref),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _backupTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool encrypted,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              color: context.tokens.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: context.tokens.textTertiary, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: context.tokens.textTertiary),
      onTap: () async {
        final backupService = ref.read(backupServiceProvider);
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: GlassContainer(
              child: CircularProgressIndicator(color: AppColors.indigo500),
            ),
          ),
        );
        final result = await backupService.exportToFile(encrypted: encrypted);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.success
                  ? (result.message ?? 'Backup exported successfully')
                  : (result.error ?? 'Export failed')),
              backgroundColor:
                  result.success ? AppColors.emerald500 : AppColors.rose500,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _manageBackupsTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.fuchsia500.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.folder,
            color: AppColors.fuchsia500, size: 20),
      ),
      title: Text('Manage Backups',
          style: TextStyle(
              color: context.tokens.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text('View and restore previous backups',
          style: TextStyle(color: context.tokens.textTertiary, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: context.tokens.textTertiary),
      onTap: () => _showBackupsDialog(context, ref),
    );
  }

  Widget _importBackupTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.emerald500.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.file_upload,
            color: AppColors.emerald500, size: 20),
      ),
      title: Text('Import Backup File',
          style: TextStyle(
              color: context.tokens.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text('Restore from a backup saved on this device',
          style: TextStyle(color: context.tokens.textTertiary, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: context.tokens.textTertiary),
      onTap: () => _importBackupFromFile(context, ref),
    );
  }

  /// Pick a backup file (.json or .encrypted) from anywhere on the device and
  /// merge it in — complements "Manage Backups", which only lists files the app
  /// itself created. Encryption is inferred from the file extension.
  Future<void> _importBackupFromFile(
      BuildContext context, WidgetRef ref) async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'encrypted'],
      );
    } catch (e) {
      debugPrint('Backup file pick failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the file picker'),
            backgroundColor: AppColors.rose500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final path = picked?.files.single.path;
    if (path == null) return; // cancelled
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text('Import Backup?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Entries and rankings from this file will be merged into your '
          'journal. Existing items with the same id are overwritten.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('IMPORT',
                style: TextStyle(color: AppColors.indigo500)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: GlassContainer(
          child: CircularProgressIndicator(color: AppColors.indigo500),
        ),
      ),
    );

    final backupService = ref.read(backupServiceProvider);
    final isEncrypted = path.toLowerCase().endsWith('.encrypted');
    final result =
        await backupService.importBackupFile(path, isEncrypted: isEncrypted);

    // Make the merged data visible everywhere (journal/calendar/identity/stats).
    if (result.success) {
      ref.read(journalRevisionProvider.notifier).bump();
    }

    if (!context.mounted) return;
    Navigator.pop(context); // close the loading dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? (result.message ?? 'Import complete')
            : (result.error ?? 'Import failed')),
        backgroundColor:
            result.success ? AppColors.emerald500 : AppColors.rose500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _manageTagsTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.indigo500.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.label_outline,
            color: AppColors.indigo500, size: 20),
      ),
      title: Text('Manage Tags',
          style: TextStyle(
              color: context.tokens.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text('Rename, merge or delete tags across all entries',
          style: TextStyle(color: context.tokens.textTertiary, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, color: context.tokens.textTertiary),
      onTap: () => _showTagsDialog(context, ref),
    );
  }

  /// Bottom sheet listing every tag with its usage count and rename/delete
  /// actions. Renaming to an existing tag merges them. Each change bumps the
  /// shared journal revision so the journal/calendar/stats refresh.
  void _showTagsDialog(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    var counts = await storage.getTagCounts();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> refresh() async {
            counts = await storage.getTagCounts();
            if (ctx.mounted) setSheetState(() {});
          }

          final tags = counts.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: AppColors.slate900.withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Manage Tags',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tags.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.label_off_outlined,
                                  size: 48, color: AppColors.slate400),
                              SizedBox(height: 16),
                              Text('No tags yet',
                                  style: TextStyle(color: AppColors.slate400)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: tags.length,
                          itemBuilder: (c, i) {
                            final tag = tags[i];
                            final count = counts[tag] ?? 0;
                            return GlassContainer(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.label,
                                      color: AppColors.indigo500, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(tag,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Text('$count',
                                      style: const TextStyle(
                                          color: AppColors.slate400,
                                          fontSize: 12)),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.indigo500, size: 20),
                                    tooltip: 'Rename or merge',
                                    onPressed: () => _renameTagFlow(
                                        context, ref, tag, refresh),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.rose500, size: 20),
                                    tooltip: 'Delete tag',
                                    onPressed: () => _deleteTagFlow(
                                        context, ref, tag, refresh),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _renameTagFlow(BuildContext context, WidgetRef ref, String tag,
      Future<void> Function() refresh) async {
    final controller = TextEditingController(text: tag);
    final newName = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title:
            const Text('Rename tag', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'New name',
            labelStyle: TextStyle(color: AppColors.slate400),
            helperText: 'Renaming to an existing tag merges them',
            helperStyle: TextStyle(color: AppColors.slate600, fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.slate400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, controller.text.trim()),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.indigo500),
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName.toLowerCase() == tag.toLowerCase()) {
      return;
    }
    await ref.read(storageServiceProvider).renameTag(tag, newName);
    ref.read(journalRevisionProvider.notifier).bump();
    await refresh();
  }

  Future<void> _deleteTagFlow(BuildContext context, WidgetRef ref, String tag,
      Future<void> Function() refresh) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text('Delete tag?', style: TextStyle(color: Colors.white)),
        content: Text('"$tag" will be removed from all entries.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child:
                const Text('DELETE', style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(storageServiceProvider).deleteTag(tag);
    ref.read(journalRevisionProvider.notifier).bump();
    await refresh();
  }

  void _showBackupsDialog(BuildContext context, WidgetRef ref) async {
    final backupService = ref.read(backupServiceProvider);
    final backups = await backupService.listBackups();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.slate900.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manage Backups',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: backups.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open,
                              size: 48, color: AppColors.slate400),
                          SizedBox(height: 16),
                          Text('No backups found',
                              style: TextStyle(color: AppColors.slate400)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: backups.length,
                      itemBuilder: (ctx, i) {
                        final backup = backups[i];
                        return GlassContainer(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                backup.isEncrypted
                                    ? Icons.lock
                                    : Icons.description,
                                color: backup.isEncrypted
                                    ? AppColors.emerald500
                                    : AppColors.amber500,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      backup.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${backup.formattedDate} • ${backup.formattedSize}',
                                      style: const TextStyle(
                                          color: AppColors.slate400,
                                          fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore,
                                    color: AppColors.indigo500),
                                tooltip: 'Restore',
                                onPressed: () =>
                                    _restoreBackup(context, ctx, ref, backup),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.rose500),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialog) => AlertDialog(
                                      backgroundColor: AppColors.slate900,
                                      title: const Text('Delete Backup?',
                                          style: TextStyle(color: Colors.white)),
                                      content: const Text(
                                          'This action cannot be undone.',
                                          style:
                                              TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, false),
                                          child: const Text('CANCEL',
                                              style: TextStyle(
                                                  color: AppColors.slate400)),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, true),
                                          child: const Text('DELETE',
                                              style: TextStyle(
                                                  color: AppColors.rose500)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await backupService
                                        .deleteBackup(backup.path);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      _showBackupsDialog(context, ref);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Restore (merge) a backup file into the journal after confirmation.
  Future<void> _restoreBackup(
    BuildContext screenContext,
    BuildContext sheetContext,
    WidgetRef ref,
    BackupFileInfo backup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: screenContext,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.slate900,
        title: const Text('Restore Backup?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Entries and rankings from this backup will be merged into your '
          'journal. Existing items with the same id are overwritten.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('RESTORE',
                style: TextStyle(color: AppColors.indigo500)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final backupService = ref.read(backupServiceProvider);
    final result = await backupService.importBackupFile(
      backup.path,
      isEncrypted: backup.isEncrypted,
    );

    // Imported entries/rankings are now in storage — notify every journal-backed
    // screen (and trigger the stats invalidation listener above) so the restore
    // is visible without relaunching.
    if (result.success) {
      ref.read(journalRevisionProvider.notifier).bump();
    }

    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (!screenContext.mounted) return;
    ScaffoldMessenger.of(screenContext).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? (result.message ?? 'Restore complete')
            : (result.error ?? 'Restore failed')),
        backgroundColor:
            result.success ? AppColors.emerald500 : AppColors.rose500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Capitalize the first letter of a mood name (e.g. "happy" -> "Happy").
  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Renders the six journaling stat cards (Req 1.1) in three rows of two,
  /// applying the empty/zero-state formatting rules from Req 1.3.
  Widget _statsGrid(JournalStats stats) {
    final mood = stats.mostFrequentMood;
    final moodValue = mood == null
        ? '—'
        : '${moodIcons[mood] ?? ''} ${_capitalize(mood.name)}';
    final topTags = stats.topTags.isEmpty
        ? 'No tags yet'
        : stats.topTags.join(', ');

    return Column(
      children: [
        Row(
          children: [
            _statCard('Streak', '${stats.streak}',
                Icons.local_fire_department, AppColors.amber500),
            const SizedBox(width: 12),
            _statCard('Entries', '${stats.totalEntries}', Icons.storage,
                AppColors.indigo500),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('Mood', moodValue,
                Icons.sentiment_satisfied_alt, AppColors.fuchsia500,
                valueFontSize: 16),
            const SizedBox(width: 12),
            _statCard('Words', '${stats.totalWordCount}',
                Icons.text_fields, AppColors.emerald500),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('Days Old', '${stats.journalAgeInDays}',
                Icons.calendar_today, AppColors.rose500),
            const SizedBox(width: 12),
            _statCard('Top Tags', topTags, Icons.label_outline,
                AppColors.slate300,
                valueFontSize: 14, valueMaxLines: 2),
          ],
        ),
      ],
    );
  }

  /// Pulsing placeholder grid shown while [statsProvider] resolves.
  Widget _shimmerGrid() {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _ShimmerCard(),
              SizedBox(width: 12),
              _ShimmerCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    double valueFontSize = 24,
    int valueMaxLines = 1,
  }) {
    return StatCard(
      label: label,
      value: value,
      icon: icon,
      color: color,
      valueFontSize: valueFontSize,
      valueMaxLines: valueMaxLines,
    );
  }
}

/// A single shimmer placeholder card used during stats loading.
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const card = GlassContainer(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: SizedBox(
        height: 56,
        child: Center(
          child: Icon(Icons.hourglass_empty,
              color: AppColors.slate600, size: 20),
        ),
      ),
    );
    // Skip the pulsing animation when the user prefers reduced motion.
    if (Motion.reduceMotion(context)) {
      if (_controller.isAnimating) _controller.stop();
      return const Expanded(child: Opacity(opacity: 0.55, child: card));
    }
    return Expanded(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.75).animate(_controller),
        child: card,
      ),
    );
  }
}

/// A compact bar chart of entries-per-week over the last 12 weeks — a measure of
/// journaling consistency. Bars are bottom-aligned; the current week is drawn in
/// the full accent colour, earlier weeks dimmed.
class _ConsistencyChart extends StatelessWidget {
  final List<int> weeks;
  final Color color;
  const _ConsistencyChart({required this.weeks, required this.color});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final maxCount = weeks.fold<int>(0, (m, v) => v > m ? v : m);
    final total = weeks.fold<int>(0, (s, v) => s + v);

    return Semantics(
      label: 'Journaling consistency: $total entries over the last 12 weeks',
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('Journaling consistency',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Last 12 weeks',
                    style:
                        TextStyle(color: tokens.textTertiary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < weeks.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        // Min stub of 4px so an empty week is still visible.
                        height: 4 +
                            (maxCount == 0 ? 0.0 : weeks[i] / maxCount) * 52,
                        decoration: BoxDecoration(
                          color: i == weeks.length - 1
                              ? color
                              : color.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$total ${total == 1 ? 'entry' : 'entries'} in the last 12 weeks',
              style: TextStyle(color: tokens.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
