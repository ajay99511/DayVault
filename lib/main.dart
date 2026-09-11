import 'dart:async';
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
import 'screens/vision_board_screen.dart';
import 'config/constants.dart';
import 'widgets/glass_widgets.dart';
import 'providers/auth_provider.dart';
import 'services/storage_service.dart';
import 'services/platform/platform_init_stub.dart'
    if (dart.library.ffi) 'services/platform/platform_init_native.dart'
    if (dart.library.js_interop) 'services/platform/platform_init_web.dart';
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

  final bootstrap = await runBootstrap();

  runApp(ProviderScope(child: MemoryPalaceApp(initial: bootstrap)));
}

/// Outcome of the one-time platform bootstrap: storage and security init.
class BootstrapResult {
  final PlatformInitOutcome? outcome;
  final String? error;
  const BootstrapResult({this.outcome, this.error});

  bool get isFatal =>
      error != null || outcome?.result == InitResult.fatalError;

  String get message => error ?? outcome?.errorMessage ?? 'Unknown error';
}

/// Bring up platform storage and the security service.
///
/// Extracted from [main] so the error screen's Retry can re-run *just this*
/// rather than calling `main()` again — which re-registered the global error
/// handlers and started a second app root on top of the first.
Future<BootstrapResult> runBootstrap() async {
  try {
    final outcome = await platformInit();
    await SecurityService().initialize();
    return BootstrapResult(outcome: outcome);
  } catch (e, st) {
    debugPrint('Critical init failed: $e\n$st');
    return BootstrapResult(error: e.toString());
  }
}

class MemoryPalaceApp extends ConsumerStatefulWidget {
  final BootstrapResult initial;

  const MemoryPalaceApp({super.key, required this.initial});

  @override
  ConsumerState<MemoryPalaceApp> createState() => _MemoryPalaceAppState();
}

class _MemoryPalaceAppState extends ConsumerState<MemoryPalaceApp> {
  late BootstrapResult _bootstrap = widget.initial;
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final result = await runBootstrap();
    if (!mounted) return;
    setState(() {
      _bootstrap = result;
      _retrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Memory Palace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: _bootstrap.isFatal
          ? _ErrorScreen(
              error: _bootstrap.message,
              onRetry: _retry,
              isRetrying: _retrying,
            )
          : RootOrchestrator(
              // Keying on the attempt lets a successful retry rebuild the
              // orchestrator from scratch instead of reusing stale state.
              key: ValueKey(_bootstrap),
              initOutcome: _bootstrap.outcome,
            ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  final bool isRetrying;

  const _ErrorScreen({
    required this.error,
    required this.onRetry,
    this.isRetrying = false,
  });

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
                // Re-runs the bootstrap only. Calling main() here (as this
                // previously did) re-registered the global error handlers and
                // mounted a second app root over the first.
                onPressed: isRetrying ? null : onRetry,
                child: Text(isRetrying ? 'Retrying…' : 'Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RootOrchestrator extends ConsumerStatefulWidget {
  final PlatformInitOutcome? initOutcome;
  const RootOrchestrator({super.key, this.initOutcome});

  @override
  ConsumerState<RootOrchestrator> createState() => _RootOrchestratorState();
}

class _RootOrchestratorState extends ConsumerState<RootOrchestrator> {
  bool isLoading = true;
  bool _securityEnabled = false;

  /// Set when the post-consent database rescue failed. The original database
  /// is still in place in that case, so this is reported rather than swallowed.
  String? _initFailure;

  /// Guards the one-shot legacy-entry migration; see [_migrateLegacyEntries].
  bool _legacyMigrationStarted = false;

  // Auto-lock policy (deliberate):
  //
  // The vault unlocks ONCE per process and stays unlocked for the entire
  // lifetime of that process — there is intentionally NO inactivity/background
  // timeout. The session lives in [authStateProvider], which is in-memory
  // (keepAlive) and therefore survives backgrounding, minimizing, tab-switching
  // and window focus changes identically on mobile, desktop and web.
  //
  // The PIN is required again only on a cold start: a real process restart —
  // the user fully closing the app (or the OS killing a backgrounded app to
  // reclaim memory) and relaunching it. Flutter does not restore in-memory
  // state across a process kill unless RestorationMixin/restorationScopeId is
  // used (this app uses neither), so the process boundary is the single,
  // reliable relock trigger. We do not key off AppLifecycleState here because
  // its semantics differ per platform (e.g. desktop emits paused/hidden on a
  // routine minimize), which previously caused spurious re-prompts.
  @override
  void initState() {
    super.initState();

    // Check for migration requirement
    if (widget.initOutcome?.result == InitResult.migrationRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMigrationDialog());
    }

    _checkSecurity();
  }

  Future<void> _showMigrationDialog() async {
    // Nothing has been moved at this point — the database is still exactly
    // where it was, and declining here leaves it that way. The wording must
    // reflect that: the previous version claimed the data "has been safely
    // backed up" while the move had in fact already happened before the user
    // was asked, with no code anywhere that could undo it.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Can't open your journal"),
        content: Text(
          'Your journal database could not be opened after several attempts.\n\n'
          'You can move it aside and start with an empty journal. Your existing '
          'data will not be deleted — it will be kept at:\n\n'
          '${widget.initOutcome!.backupPath}\n\n'
          'If you would rather not touch it yet, choose "Keep and close" and '
          'the app will exit without changing anything.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP AND CLOSE'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('MOVE ASIDE AND CONTINUE'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      // Declining is a first-class outcome, not a failure: the journal stays
      // untouched so it can be recovered by a later build or by support.
      SystemNavigator.pop();
      return;
    }

    try {
      await platformReinitializeAfterConsent(widget.initOutcome!.backupPath!);
      _checkSecurity();
    } catch (e, st) {
      debugPrint('Rescue failed, database left in place: $e\n$st');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _initFailure = 'Could not move the existing database aside. '
            'Your data has not been changed.\n\n$e';
      });
    }
  }

  /// Convert any legacy-encrypted journal rows to plain text, once per launch.
  ///
  /// Runs after the vault is open, because decrypting a version-1 row needs the
  /// PIN-derived key. It is safe to run with no key — rows that cannot be read
  /// are left untouched — and safe to run repeatedly, so a failure here costs
  /// nothing but a retry next launch and must never block startup.
  Future<void> _migrateLegacyEntries() async {
    if (_legacyMigrationStarted) return;
    _legacyMigrationStarted = true;
    try {
      await ref.read(storageServiceProvider).migrateLegacyEncryptedEntries();
    } catch (e, st) {
      debugPrint('Legacy entry migration skipped: $e\n$st');
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

    final failure = _initFailure;
    if (failure != null) {
      return _ErrorScreen(
        error: failure,
        onRetry: () async {
          setState(() {
            _initFailure = null;
            isLoading = true;
          });
          await _checkSecurity();
        },
      );
    }

    // The provider tracks whether the user has unlocked via the lock screen.
    // When security is disabled there is nothing to unlock, so we bypass it
    // entirely (no provider mutation needed during init).
    final unlocked = ref.watch(authStateProvider);
    if (_securityEnabled && !unlocked) {
      return LockScreen(
        onUnlock: () => ref.read(authStateProvider.notifier).authenticate(),
      );
    }

    // Past the gate, so the decryption key (if any) is available. Fire and
    // forget: this must not delay the first frame, and it is idempotent.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_migrateLegacyEntries()));

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

  // The orbs are identical on every frame — only their offsets animate — so
  // they are built once rather than reconstructed 60 times a second. Held as
  // fields rather than `const` because the tints use Color.withValues, which
  // is not a const expression; baking the alpha into a hex literal would
  // quantise it to 8 bits and shift the colour slightly.
  late final Widget _orbIndigo = AnimatedOrb(
    width: 400,
    height: 400,
    color: AppColors.indigo500.withValues(alpha: 0.15),
  );
  late final Widget _orbFuchsia = AnimatedOrb(
    width: 300,
    height: 300,
    color: AppColors.fuchsia500.withValues(alpha: 0.1),
  );
  late final Widget _orbEmerald = AnimatedOrb(
    width: 250,
    height: 250,
    color: AppColors.emerald500.withValues(alpha: 0.05),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = const [
      JournalScreen(),
      CalendarScreen(),
      IdentityScreen(),
      VisionBoardScreen(),
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
          // Ambient background orbs.
          //
          // RepaintBoundary keeps this always-running animation in its own
          // composited layer. Without it the orb layer shares a layer with the
          // IndexedStack holding every screen, so the whole app repainted on
          // each of the 60 frames per second this controller drives.
          //
          // The orbs themselves never change — only their offsets do — so they
          // are built once and passed in as `child`, rather than reconstructed
          // on every tick. GlassContainer already applies this same treatment
          // to its BackdropFilter.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (ctx, child) {
                final progress = _bgCtrl.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -50 + (progress * 20),
                      left: -50,
                      child: _orbIndigo,
                    ),
                    Positioned(
                      bottom: -100 - (progress * 30),
                      right: -50,
                      child: _orbFuchsia,
                    ),
                    Positioned(
                      top: 300,
                      left: 200 + (progress * 50),
                      child: _orbEmerald,
                    ),
                  ],
                );
              },
            ),
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
                  _navItem(context, 3, Icons.auto_awesome, "Vision"),
                  _navItem(context, 4, Icons.account_circle_outlined, "System"),
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
