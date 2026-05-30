import 'dart:ui';
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

  // Global error boundary - must be set before runApp()
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // default Flutter error rendering
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    // TODO: forward to crash reporting (e.g. Firebase Crashlytics) in release
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformError: $error\n$stack');
    // TODO: forward to crash reporting in release
    return true; // returning true prevents the default crash
  };

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  ObjectBoxInitOutcome? initOutcome;
  String? initError;
  try {
    initOutcome = await ObjectBoxService.init();
    await SecurityService().initialize();
  } catch (e, st) {
    debugPrint('Critical init failed: $e\n$st');
    initError = e.toString();
  }

  runApp(ProviderScope(
    child: MemoryPalaceApp(
      initOutcome: initOutcome,
      initError: initError,
    ),
  ));
}

class MemoryPalaceApp extends StatelessWidget {
  final ObjectBoxInitOutcome? initOutcome;
  final String? initError;

  const MemoryPalaceApp({super.key, this.initOutcome, this.initError});

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
      home: initError != null || (initOutcome != null && initOutcome!.result == InitResult.fatalError)
          ? _ErrorScreen(error: initError ?? initOutcome!.errorMessage!)
          : RootOrchestrator(initOutcome: initOutcome),
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
  final ObjectBoxInitOutcome? initOutcome;
  const RootOrchestrator({super.key, this.initOutcome});

  @override
  ConsumerState<RootOrchestrator> createState() => _RootOrchestratorState();
}

class _RootOrchestratorState extends ConsumerState<RootOrchestrator>
    with WidgetsBindingObserver {
  bool isAuthenticated = false;
  bool isLoading = true;
  DateTime? _backgroundedAt;
  static const _gracePeriod = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check for migration requirement
    if (widget.initOutcome?.result == InitResult.migrationRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMigrationDialog());
    }
    
    _checkSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null && DateTime.now().difference(bg) > _gracePeriod) {
        setState(() => isAuthenticated = false);
      }
    }
  }

  Future<void> _showMigrationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Database Security Upgrade'),
        content: Text(
          'A security upgrade is required for your database. '
          'Your existing data has been safely backed up to:\n\n'
          '${widget.initOutcome!.backupPath}\n\n'
          'The app will now start with a fresh database. Tap "OK" to proceed.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ObjectBoxService.reinitializeAfterConsent(widget.initOutcome!.backupPath!);
      _checkSecurity();
    } else {
      // If user cancels, they can't use the app
      SystemNavigator.pop();
    }
  }

  Future<void> _checkSecurity() async {
    // If migration failed or cancelled, we might not have a storage provider ready
    try {
      final settings = ref.read(storageServiceProvider).getSettings();
      setState(() {
        isAuthenticated = !settings.securityEnabled; // If disabled, auto-auth
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Security check failed: $e");
      setState(() => isLoading = false);
    }
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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      JournalScreen(),
      CalendarScreen(),
      IdentityScreen(),
      ProfileScreen(),
    ];
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

          // View Switcher - using IndexedStack to preserve state
          IndexedStack(
            index: _idx,
            children: _screens,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        child: GlassContainer(
          useBackdropFilter: true, // Only for nav bar
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
