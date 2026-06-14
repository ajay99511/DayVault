import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/storage_service.dart';
import '../services/security_service.dart';
import '../services/backup_service.dart';
import 'pin_setup_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';
import 'pin_management_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserSettings settings = const UserSettings();
  int totalMemories = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(storageServiceProvider).getSettings();
    final j = await ref.read(storageServiceProvider).getJournal();
    final computedStreak = StorageService.computeStreak(j);
    if (mounted) {
      setState(() {
        settings = s;
        totalMemories = j.length;
        _streak = computedStreak;
      });
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$totalMemories entries · $_streak day streak',
                          style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats Grid
            const Text(
              "COGNITIVE METRICS",
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statCard(
                  "Engrams",
                  "$totalMemories",
                  Icons.storage,
                  AppColors.indigo500,
                ),
                const SizedBox(width: 12),
                _statCard(
                  "Streak",
                  "$_streak",
                  Icons.local_fire_department,
                  AppColors.emerald500,
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Settings
            const Text(
              "SYSTEM CONFIGURATION",
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
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
                              const Text(
                                "Neural Encryption",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                settings.biometricsEnabled
                                    ? "Biometric Access Enrolled"
                                    : "Require security on launch",
                                style: const TextStyle(
                                  color: AppColors.slate400,
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
                                ? "BIOMETRICS + PASSKEY ACTIVE"
                                : "PASSKEY ACTIVE",
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

            // Data Management
            const Text(
              "DATA MANAGEMENT",
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
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
                    title: const Text(
                      'PIN & Security',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Manage PIN, security questions & biometrics',
                      style:
                          TextStyle(color: AppColors.slate400, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.slate400),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PinManagementScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  _backupTile(
                    context,
                    ref,
                    title: 'Export Backup',
                    subtitle: 'Save all your memories securely',
                    icon: Icons.backup,
                    iconColor: AppColors.emerald500,
                    encrypted: true,
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  _backupTile(
                    context,
                    ref,
                    title: 'Export Unencrypted',
                    subtitle: 'Readable JSON format (not recommended)',
                    icon: Icons.file_download,
                    iconColor: AppColors.amber500,
                    encrypted: false,
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  _manageBackupsTile(context, ref),
                ],
              ),
            ),
          ],
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
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.slate400),
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
      title: const Text('Manage Backups',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: const Text('View and restore previous backups',
          style: TextStyle(color: AppColors.slate400, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.slate400),
      onTap: () => _showBackupsDialog(context, ref),
    );
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

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: AppColors.slate400, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.slate400,
                  fontSize: 8,
                  letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
