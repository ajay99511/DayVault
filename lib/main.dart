import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/lock_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/identity_screen.dart';
import 'screens/profile_screen.dart';
import 'config/constants.dart';
import 'widgets/glass_widgets.dart';
import 'services/storage_service.dart';
import 'services/objectbox_service.dart';
import 'services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  String? initError;
  try {
    await ObjectBoxService.init();
    await SecurityService().initialize();
  } catch (e, st) {
    debugPrint('Critical init failed: $e\n$st');
    initError = e.toString();
  }

  runApp(ProviderScope(child: MemoryPalaceApp(initError: initError)));
}

class MemoryPalaceApp extends StatelessWidget {
  final String? initError;

  const MemoryPalaceApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Palace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.slate950,
        textTheme:
            GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: initError != null
          ? _ErrorScreen(error: initError!)
          : const RootOrchestrator(),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Initialization Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RootOrchestrator extends ConsumerStatefulWidget {
  const RootOrchestrator({super.key});

  @override
  ConsumerState<RootOrchestrator> createState() => _RootOrchestratorState();
}

class _RootOrchestratorState extends ConsumerState<RootOrchestrator> {
  bool isAuthenticated = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final settings = ref.read(storageServiceProvider).getSettings();
    setState(() {
      isAuthenticated = !settings.securityEnabled; // If disabled, auto-auth
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: AppColors.slate950);

    if (!isAuthenticated) {
      return LockScreen(onUnlock: () => setState(() => isAuthenticated = true));
    }

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _bgCtrl;

  final List<Widget> _screens = [
    const JournalScreen(),
    const CalendarScreen(),
    const IdentityScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // For glass navbar
      body: Stack(
        children: [
          // Ambient Background Orbs
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (ctx, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -50 + (_bgCtrl.value * 20),
                    left: -50,
                    child: AnimatedOrb(
                      width: 400,
                      height: 400,
                      color: AppColors.indigo500.withValues(alpha: 0.15),
                    ),
                  ),
                  Positioned(
                    bottom: -100 - (_bgCtrl.value * 30),
                    right: -50,
                    child: AnimatedOrb(
                      width: 300,
                      height: 300,
                      color: AppColors.fuchsia500.withValues(alpha: 0.1),
                    ),
                  ),
                  Positioned(
                    top: 300,
                    left: 200 + (_bgCtrl.value * 50),
                    child: AnimatedOrb(
                      width: 250,
                      height: 250,
                      color: AppColors.emerald500.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              );
            },
          ),

          // View Switcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(_idx), child: _screens[_idx]),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        child: GlassContainer(
          borderRadius: 32,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(0, Icons.menu_book, "Journal"),
              _navItem(1, Icons.calendar_month, "Recall"),
              _navItem(2, Icons.person_outline, "Identity"),
              _navItem(3, Icons.account_circle_outlined, "System"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final isActive = _idx == i;
    return GestureDetector(
      onTap: () => setState(() => _idx = i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.indigo500 : AppColors.slate400,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              color: isActive ? AppColors.indigo500 : Colors.transparent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
