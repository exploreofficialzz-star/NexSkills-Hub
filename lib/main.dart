import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/hive_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/unity_ads_service.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Init after first frame — splash renders first, then services load.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
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
      UnityAdsService.instance.init(), // second ad network — mediated with AdMob
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
        transitionDuration: const Duration(milliseconds: 400),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Match whatever the rest of the app uses — no hardcoded colour.
    final bg     = Theme.of(context).scaffoldBackgroundColor;
    final fg     = isDark ? Colors.white        : Colors.black87;
    final muted  = isDark ? Colors.white38      : Colors.black38;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon — clipped so PNG corner artefacts are invisible ──
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: const AppIconWidget(size: 112),
            ),
            const SizedBox(height: 24),
            // ── App name ──────────────────────────────────────────────
            Text(
              'NexSkills Hub',
              style: TextStyle(
                color: fg,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your tech learning companion',
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 48),
            // ── Three-dot bouncing loader ─────────────────────────────
            const _DotsLoader(),
            const SizedBox(height: 20),
            // ── Brand attribution ─────────────────────────────────────
            Text(
              'by chAs',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Three-dot bouncing loader ────────────────────────────────────────────────
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();
  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 1/3 of the cycle
            final phase = ((_ctrl.value - i / 3.0) % 1.0 + 1.0) % 1.0;
            // Bounce only in the first half of each dot's phase window
            final bounce = phase < 0.4
                ? -(phase < 0.2
                    ? (phase / 0.2)
                    : (0.4 - phase) / 0.2) *
                    10.0
                : 0.0;
            return Transform.translate(
              offset: Offset(0, bounce),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
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
