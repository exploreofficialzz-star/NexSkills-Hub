import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/hive_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/content_health_service.dart';
import 'shared/theme.dart';
import 'shared/network_aware_wrapper.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await HiveService.init();

  // Initialize AdMob SDK only — do NOT preload ads here (Section 5.1 / 1.6).
  // Ads are preloaded after the first frame renders, inside HomeScreen.
  await Future.wait([
    AdService.initializeSdkOnly(), // SDK init, no ad loading
    ConnectivityService.instance.init(),
  ]);
  try {
    await NotificationService.init();
  } catch (_) {}

  final progress = HiveService.getProgress();

  final isOnboarded = progress.activeCategory.isNotEmpty &&
      (progress.lastActiveDate != null ||
          progress.totalXP > 0 ||
          progress.totalLessonsCompleted > 0 ||
          progress.dailyGoalMinutes != 20);

  runApp(NexSkillsApp(isOnboarded: isOnboarded));
}

class NexSkillsApp extends StatefulWidget {
  final bool isOnboarded;
  const NexSkillsApp({super.key, required this.isOnboarded});

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
      // Global error boundary — catches Flutter rendering exceptions and
      // shows a user-friendly fallback instead of the red error box.
      builder: (context, child) {
        return _GlobalErrorBoundary(child: child ?? const SizedBox.shrink());
      },
      home: NetworkAwareWrapper(
        child: widget.isOnboarded
            ? HomeScreen(onThemeModeChanged: setThemeMode)
            : const OnboardingScreen(),
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
    // Catch uncaught Flutter errors globally
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
