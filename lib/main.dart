import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/hive_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';
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

  // Init all services in parallel where possible
  await HiveService.init();
  await Future.wait([
    AdService.initialize(),
    ConnectivityService.instance.init(),
  ]);
  try { await NotificationService.init(); } catch (_) {}

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

  // ── App lifecycle → app-open ad + connectivity re-check ──────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AdLifecycleObserver.onPause();
    } else if (state == AppLifecycleState.resumed) {
      AdLifecycleObserver.onResume();
      // Re-check connectivity on resume (catches airplane mode toggled in background)
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
      ThemeMode.dark   => Brightness.dark,
      ThemeMode.light  => Brightness.light,
      ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:            Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:  Colors.transparent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'NexSkills Hub',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      // NetworkAwareWrapper sits inside MaterialApp so it has
      // access to Theme.of(context) for the correct color palette
      home: NetworkAwareWrapper(
        child: widget.isOnboarded
            ? HomeScreen(onThemeModeChanged: setThemeMode)
            : const OnboardingScreen(),
      ),
    );
  }
}
