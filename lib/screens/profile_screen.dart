import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:system_info2/system_info2.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
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

  // System Tracking
  final Battery _battery = Battery();
  Timer? _timer;
  int _batteryLevel = 100;
  String _batteryState = 'Unknown';
  String _osName = 'Loading...';
  String _deviceName = 'Loading...';
  double _freeRamGB = 0;
  double _totalRamGB = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _initSystemInfo();
    _startMetricsTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initSystemInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = androidInfo.model;
        _osName = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.utsname.machine;
        _osName = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceName = windowsInfo.productName;
        _osName = 'Windows';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _deviceName = macInfo.model;
        _osName = 'macOS ${macInfo.osRelease}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceName = linuxInfo.prettyName;
        _osName = 'Linux';
      } else {
        _deviceName = 'Unknown Device';
        _osName = Platform.operatingSystem;
      }
    } catch (e) {
      _deviceName = 'Access Denied';
      _osName = 'Unknown OS';
    }

    if (mounted) setState(() {});
  }

  void _startMetricsTimer() {
    _updateMetrics();
    _timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _updateMetrics());
  }

  Future<void> _updateMetrics() async {
    if (!mounted) return;
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
          _batteryState = state.name.toUpperCase();

          try {
            // Using system_info2 for memory stats (in bytes)
            _totalRamGB =
                SysInfo.getTotalPhysicalMemory() / (1024 * 1024 * 1024);
            _freeRamGB = SysInfo.getFreePhysicalMemory() / (1024 * 1024 * 1024);
          } catch (e) {
            // Fallbacks in case system_info2 fails on the target platform
            _totalRamGB = 0;
            _freeRamGB = 0;
          }
        });
      }
    } catch (e) {
      // Ignore battery errors on unsupported devices (e.g. some emulators/desktops)
    }
  }

  Future<void> _load() async {
    final s = ref.read(storageServiceProvider).getSettings();
    final j = await ref.read(storageServiceProvider).getJournal();
    setState(() {
      settings = s;
      totalMemories = j.length;
    });
  }

  void _toggleSecurity() {
    final newSettings = UserSettings(
      securityEnabled: !settings.securityEnabled,
      username: settings.username,
      theme: settings.theme,
    );
    ref.read(storageServiceProvider).saveSettings(newSettings);
    setState(() => settings = newSettings);
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
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.slate800,
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.slate900,
                      child: Icon(
                        Platform.isAndroid || Platform.isIOS
                            ? Icons.phone_android
                            : Icons.computer,
                        color: AppColors.indigo500,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _deviceName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "OS: $_osName",
                          style: const TextStyle(
                            color: AppColors.fuchsia500,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
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
                  "12",
                  Icons.local_fire_department,
                  AppColors.emerald500,
                ),
                const SizedBox(width: 12),
                _statCard(
                  "Clarity",
                  "87%",
                  Icons.psychology,
                  AppColors.fuchsia500,
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Diagnostics Grid
            const Text(
              "REAL-TIME DIAGNOSTICS",
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
                  "Battery",
                  "$_batteryLevel%",
                  _batteryState == 'CHARGING'
                      ? Icons.battery_charging_full
                      : Icons.battery_full,
                  _batteryLevel <= 20
                      ? AppColors.rose500
                      : AppColors.emerald500,
                ),
                const SizedBox(width: 12),
                _statCard(
                  "RAM Status",
                  _totalRamGB > 0
                      ? "${(_totalRamGB - _freeRamGB).toStringAsFixed(1)} / ${_totalRamGB.toStringAsFixed(1)} GB"
                      : "N/A",
                  Icons.memory,
                  AppColors.amber500,
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Neural Encryption",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Require biometrics on launch",
                                style: TextStyle(
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
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 12,
                            color: AppColors.indigo500,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "PASSKEY ACTIVE",
                            style: TextStyle(
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
                  // PIN & Security Management
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.fuchsia500.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.security,
                        color: AppColors.fuchsia500,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'PIN & Security',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Manage PIN, security questions & biometrics',
                      style: TextStyle(color: AppColors.slate400, fontSize: 11),
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
      title: Text(
        title,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.slate400, fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.slate400),
      onTap: () async {
        final backupService = ref.read(backupServiceProvider);

        // Show loading
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
          Navigator.pop(context); // Close loading

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.success
                    ? (result.message ?? 'Backup exported successfully')
                    : (result.error ?? 'Export failed'),
              ),
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
        child: const Icon(Icons.folder, color: AppColors.fuchsia500, size: 20),
      ),
      title: const Text(
        'Manage Backups',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'View and restore previous backups',
        style: TextStyle(color: AppColors.slate400, fontSize: 11),
      ),
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
                      fontWeight: FontWeight.bold,
                    ),
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
                          Text(
                            'No backups found',
                            style: TextStyle(color: AppColors.slate400),
                          ),
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
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${backup.formattedDate} • ${backup.formattedSize}',
                                      style: const TextStyle(
                                        color: AppColors.slate400,
                                        fontSize: 10,
                                      ),
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
                                          style:
                                              TextStyle(color: Colors.white)),
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

  Widget _statCard(String label, String value, IconData icon, Color color) {
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
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.slate400,
                fontSize: 8,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
