import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserSettings settings = UserSettings();
  int totalMemories = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = StorageService().getSettings();
    final j = await StorageService().getJournal();
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
    StorageService().saveSettings(newSettings);
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
                    child: const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "The Architect",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Level 4 Observer",
                        style: TextStyle(
                          color: AppColors.indigo500,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
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
                            children: const [
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
