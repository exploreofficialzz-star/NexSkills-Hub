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

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Init services
  await HiveService.init();
  await AdService.initialize();
  await NotificationService.init();

  // Check if onboarded
  final progress = HiveService.getProgress();
  final isOnboarded = progress.activeCategory.isNotEmpty &&
      progress.lastActiveDate != null ||
      progress.totalXP > 0 ||
      progress.totalLessonsCompleted > 0;

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
