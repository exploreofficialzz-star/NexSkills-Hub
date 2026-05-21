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

  bool isStepCompleted(String pathId, int stepOrder) =>
      completedSteps[pathId]?.contains(stepOrder) ?? false;

  int completedCount(String pathId) =>
      completedSteps[pathId]?.length ?? 0;

  /// Policy-compliant interstitial gate.
  /// 90s cooldown (AdMob policy minimum is 60s; 90s gives a safety margin).
  /// Premium users never see ads.
  bool get canShowInterstitial {
    if (isPremium) return false;
    if (lastInterstitialShown == null) return true;
    final elapsed = DateTime.now().difference(lastInterstitialShown!).inSeconds;
    return elapsed >= 90; // matches AdConstants.interstitialCooldownSeconds
  }
}
