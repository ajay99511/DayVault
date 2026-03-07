import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:system_info2/system_info2.dart';
import '../services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';

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
