import 'package:hive/hive.dart';

part 'user_progress.g.dart';

@HiveType(typeId: 1)
class UserProgress extends HiveObject {
  @HiveField(0)
  String activeCategory;

  @HiveField(1)
  String activeLevel; // beginner | intermediate | advanced

  @HiveField(2)
  Map<String, List<int>> completedSteps; // pathId -> [stepOrders]

  @HiveField(3)
  int streakDays;

  @HiveField(4)
  DateTime? lastActiveDate;

  @HiveField(5)
  int totalXP;

  @HiveField(6)
  List<String> earnedBadges;

  @HiveField(7)
  int dailyGoalMinutes;

  @HiveField(8)
  bool isPremium;

  @HiveField(9)
  DateTime? premiumExpiry;

  @HiveField(10)
  int totalLessonsCompleted;

  @HiveField(11)
  DateTime? lastInterstitialShown;

  UserProgress({
    this.activeCategory = 'ai',
    this.activeLevel = 'beginner',
    Map<String, List<int>>? completedSteps,
    this.streakDays = 0,
    this.lastActiveDate,
    this.totalXP = 0,
    List<String>? earnedBadges,
    this.dailyGoalMinutes = 20,
    this.isPremium = false,
    this.premiumExpiry,
    this.totalLessonsCompleted = 0,
    this.lastInterstitialShown,
  })  : completedSteps = completedSteps ?? {},
        earnedBadges = earnedBadges ?? [];

  bool isStepCompleted(String pathId, int stepOrder) {
    return completedSteps[pathId]?.contains(stepOrder) ?? false;
  }

  int completedCount(String pathId) {
    return completedSteps[pathId]?.length ?? 0;
  }

  bool get canShowInterstitial {
    if (isPremium) return false;
    if (lastInterstitialShown == null) return true;
    final diff = DateTime.now().difference(lastInterstitialShown!);
    return diff.inSeconds >= 180;
  }
}
