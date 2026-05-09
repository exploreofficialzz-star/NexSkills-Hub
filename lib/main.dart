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
  // Reads the saved preference from Hive; falls back to system.
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    final saved = HiveService.getThemeMode();
    if (saved != null) {
      _themeMode = saved;
    }
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    HiveService.saveThemeMode(mode);
    // Update status bar icons to match new theme immediately
    _applySystemUiOverlay(mode);
  }

  void _applySystemUiOverlay(ThemeMode mode) {
    final brightness = switch (mode) {
      ThemeMode.dark   => Brightness.dark,
      ThemeMode.light  => Brightness.light,
      ThemeMode.system => WidgetsBinding
              .instance.platformDispatcher.platformBrightness,
    };
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                   'NexSkills Hub',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  _themeMode,
      home: widget.isOnboarded
          ? HomeScreen(onThemeModeChanged: setThemeMode)
          : OnboardingScreen(onThemeModeChanged: setThemeMode),
    );
  }
}
