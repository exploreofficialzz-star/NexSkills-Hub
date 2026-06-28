import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/hive_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'shared/theme.dart';
import 'shared/network_aware_wrapper.dart';
import 'shared/widgets/app_icon_widget.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Only Hive before runApp — everything else runs inside SplashScreen
  // so the first Flutter frame (the splash) paints instantly.
  await HiveService.init();

  runApp(const NexSkillsApp());
}

class NexSkillsApp extends StatefulWidget {
  const NexSkillsApp({super.key});

  @override
  State<NexSkillsApp> createState() => _NexSkillsAppState();
}

class _NexSkillsAppState extends State<NexSkillsApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = HiveService.getThemeMode() ?? ThemeMode.system;
    _applyOverlay(_themeMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AdLifecycleObserver.onPause();
    } else if (state == AppLifecycleState.resumed) {
      AdLifecycleObserver.onResume();
      ConnectivityService.instance.check();
    }
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    HiveService.saveThemeMode(mode);
    _applyOverlay(mode);
  }

  void _applyOverlay(ThemeMode mode) {
    final brightness = switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexSkills Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) {
        return _GlobalErrorBoundary(child: child ?? const SizedBox.shrink());
      },
      home: NetworkAwareWrapper(
        child: SplashScreen(onThemeModeChanged: setThemeMode),
      ),
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────
// Shows the app icon immediately (first Flutter frame).
// Runs remaining async init in the background, then fades into home/onboarding.
class SplashScreen extends StatefulWidget {
  final void Function(ThemeMode)? onThemeModeChanged;
  const SplashScreen({super.key, this.onThemeModeChanged});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Init runs after first frame so splash paints before any blocking work.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Run heavy init concurrently with a minimum display time
    // so the splash is never just a flash.
    await Future.wait([
      _runServices(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;
    _navigate();
  }

  Future<void> _runServices() async {
    await Future.wait([
      AdService.initializeSdkOnly(),
      ConnectivityService.instance.init(),
    ]);
    try {
      await NotificationService.init();
    } catch (_) {}
  }

  void _navigate() {
    final isOnboarded = HiveService.hasCompletedOnboarding();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: isOnboarded
              ? HomeScreen(onThemeModeChanged: widget.onThemeModeChanged)
              : OnboardingScreen(onThemeModeChanged: widget.onThemeModeChanged),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Always dark navy — matches launch_background.xml exactly,
      // so there is zero colour flash between the native and Flutter splash.
      backgroundColor: const Color(0xFF020C26),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon
              const AppIconWidget(size: 110),
              const SizedBox(height: 22),
              // App name
              const Text(
                'NexSkills Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your tech learning companion',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 52),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Global error boundary ────────────────────────────────────────────────────
class _GlobalErrorBoundary extends StatefulWidget {
  final Widget child;
  const _GlobalErrorBoundary({required this.child});

  @override
  State<_GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<_GlobalErrorBoundary> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (mounted) setState(() => _error = details.exception);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Material(
        color: const Color(0xFF080808),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('😕', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 20),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please restart the app. If this keeps happening, '
                  'contact support.',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text(
                    'Try again',
                    style: TextStyle(color: Color(0xFF6C63FF), fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
