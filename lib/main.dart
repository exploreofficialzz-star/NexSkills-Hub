import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/hive_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'shared/theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await HiveService.init();
  await AdService.initialize();
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

class _NexSkillsAppState extends State<NexSkillsApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    // Restore saved preference; fall back to system
    _themeMode = HiveService.getThemeMode() ?? ThemeMode.system;
    _applyOverlay(_themeMode);
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    HiveService.saveThemeMode(mode);
    _applyOverlay(mode);
  }

  void _applyOverlay(ThemeMode mode) {
    final brightness = mode == ThemeMode.dark
        ? Brightness.dark
        : mode == ThemeMode.light
            ? Brightness.light
            : WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
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
      home: widget.isOnboarded
          // Theme switcher lives inside HomeScreen → ProgressScreen only.
          // OnboardingScreen uses system default — no switcher needed there.
          ? HomeScreen(onThemeModeChanged: setThemeMode)
          : const OnboardingScreen(),
    );
  }
}
