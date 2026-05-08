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

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await HiveService.init();
  await AdService.initialize();

  try {
    await NotificationService.init();
  } catch (_) {}

  final progress = HiveService.getProgress();

  // Fixed: original had operator precedence bug:
  //   activeCategory.isNotEmpty && lastActiveDate != null || totalXP > 0 ...
  // was parsed as:
  //   (activeCategory.isNotEmpty && lastActiveDate != null) || totalXP > 0 ...
  // A fresh user who just completed onboarding has activeCategory set but
  // lastActiveDate == null → first clause false → always went to onboarding.
  // Fix: parenthesise the OR clauses and check activeCategory alone.
  final isOnboarded = progress.activeCategory.isNotEmpty &&
      (progress.lastActiveDate != null ||
          progress.totalXP > 0 ||
          progress.totalLessonsCompleted > 0 ||
          progress.dailyGoalMinutes != 20); // non-default goal means user chose one

  runApp(NexSkillsApp(isOnboarded: isOnboarded));
}

class NexSkillsApp extends StatelessWidget {
  final bool isOnboarded;
  const NexSkillsApp({super.key, required this.isOnboarded});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexSkills Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: isOnboarded ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
