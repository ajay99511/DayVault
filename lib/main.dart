import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'theme/motion.dart';
import 'providers/theme_provider.dart';
import 'screens/lock_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/identity_screen.dart';
import 'screens/profile_screen.dart';
import 'config/constants.dart';
import 'widgets/glass_widgets.dart';
import 'providers/auth_provider.dart';
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

class MemoryPalaceApp extends ConsumerWidget {
  final ObjectBoxInitOutcome? initOutcome;
  final String? initError;

  const MemoryPalaceApp({super.key, this.initOutcome, this.initError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Memory Palace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
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
  bool isLoading = true;
  bool _securityEnabled = false;
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
        // Re-lock after the grace period — but only when security is actually
        // enabled, otherwise there is nothing to unlock and we'd wrongly force
        // the PIN-setup flow on a user who disabled security.
        if (_securityEnabled) {
          SecurityService().lockVault(); // clear the in-memory encryption key
          ref.read(authStateProvider.notifier).unauthenticate();
        }
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
      _securityEnabled = settings.securityEnabled;
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Security check failed: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: AppColors.slate950);

    // The provider tracks whether the user has unlocked via the lock screen.
    // When security is disabled there is nothing to unlock, so we bypass it
    // entirely (no provider mutation needed during init).
    final unlocked = ref.watch(authStateProvider);
    if (_securityEnabled && !unlocked) {
      return LockScreen(
        onUnlock: () => ref.read(authStateProvider.notifier).authenticate(),
      );
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _idx = 0;
  late AnimationController _bgCtrl;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor the OS "reduce motion" setting: freeze the ambient orbs (and react
    // if the user toggles the setting while the app is open).
    if (Motion.reduceMotion(context)) {
      if (_bgCtrl.isAnimating) _bgCtrl.stop();
    } else if (!_bgCtrl.isAnimating) {
      _bgCtrl.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the always-on ambient orb animation while the app is not visible —
    // there is nothing to render off-screen and it needlessly burns battery.
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_bgCtrl.isAnimating && !Motion.reduceMotion(context)) {
          _bgCtrl.repeat(reverse: true);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_bgCtrl.isAnimating) _bgCtrl.stop();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
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
      bottomNavigationBar: GlassNavBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

/// The frosted-glass bottom navigation pill.
///
/// Extracted as its own widget so its layout can be unit-tested (see
/// test/widget/glass_nav_bar_test.dart) — specifically that it hugs the bottom
/// of the screen and does not expand to full height.
class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // SafeArea keeps the pill clear of device insets (home indicator / gesture
    // bar / rounded corners) instead of relying on a hardcoded bottom offset,
    // so it sits correctly across phones, tablets and desktop.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        // Cap the nav width so it reads as a centered pill on tablets/desktops
        // instead of stretching the full window width.
        //
        // NOTE: heightFactor: 1.0 is essential. Scaffold measures the
        // bottomNavigationBar with a loose, FULL-height constraint; a plain
        // Center/Align (no heightFactor) would expand to that full height and
        // vertically center the pill — making the bar float in the middle of
        // the screen and overlay content. heightFactor pins the Align's height
        // to the child (the pill).
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassContainer(
              useBackdropFilter: true, // Only for nav bar
              borderRadius: 32,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(context, 0, Icons.menu_book, "Journal"),
                  _navItem(context, 1, Icons.calendar_month, "Recall"),
                  _navItem(context, 2, Icons.person_outline, "Identity"),
                  _navItem(context, 3, Icons.account_circle_outlined, "System"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int i, IconData icon, String label) {
    final isActive = currentIndex == i;
    final tokens = context.tokens;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        onTap: () => onTap(i),
        behavior: HitTestBehavior.opaque,
        // ConstrainedBox (not a Container with `alignment`) enforces the 48dp
        // minimum tap target. A Container WITH alignment expands to fill the
        // parent's bounded height, which previously ballooned the whole nav bar
        // to full-screen height. ConstrainedBox sizes to the child.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? tokens.accent : tokens.textTertiary,
                size: 28,
              ),
              const SizedBox(height: 4),
              // Label is shown only for the active tab by design; screen readers
              // still get every tab's name via the Semantics wrapper above.
              Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: isActive ? tokens.accent : Colors.transparent,
                  fontSize: 10,
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
