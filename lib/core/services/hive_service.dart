import 'package:hive_flutter/hive_flutter.dart';
import '../models/resource_model.dart';
import '../models/user_progress.dart';

class HiveService {
  static const _resourceBox = 'resources';
  static const _progressBox = 'progress';
  static const _seenIdsBox = 'seenIds';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ResourceModelAdapter());
    Hive.registerAdapter(UserProgressAdapter());
    await Hive.openBox<ResourceModel>(_resourceBox);
    await Hive.openBox<UserProgress>(_progressBox);
    await Hive.openBox<String>(_seenIdsBox);
  }

  // ─── Resources ───────────────────────────────────────────────
  static Box<ResourceModel> get _resources => Hive.box<ResourceModel>(_resourceBox);

  static List<ResourceModel> getResourcesByCategory(String category) {
    return _resources.values
        .where((r) => r.category == category)
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  static List<ResourceModel> getBookmarks() {
    return _resources.values.where((r) => r.isBookmarked).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  static Future<void> saveResources(List<ResourceModel> items) async {
    final seenBox = Hive.box<String>(_seenIdsBox);
    for (final item in items) {
      if (!seenBox.containsKey(item.id)) {
        await _resources.put(item.id, item);
        await seenBox.put(item.id, item.id);
      }
    }
  }

  static Future<void> toggleBookmark(String id) async {
    final item = _resources.get(id);
    if (item != null) {
      item.isBookmarked = !item.isBookmarked;
      await item.save();
    }
  }

  static Future<void> markRead(String id) async {
    final item = _resources.get(id);
    if (item != null) {
      item.isRead = true;
      await item.save();
    }
  }

  // ─── User Progress ───────────────────────────────────────────
  static Box<UserProgress> get _progress => Hive.box<UserProgress>(_progressBox);

  static UserProgress getProgress() {
    return _progress.get('main') ?? UserProgress();
  }

  static Future<void> saveProgress(UserProgress progress) async {
    await _progress.put('main', progress);
  }

  static Future<UserProgress> completeStep(
      String pathId, int stepOrder, int xpReward) async {
    final p = getProgress();
    final steps = p.completedSteps[pathId] ?? [];
    if (!steps.contains(stepOrder)) {
      steps.add(stepOrder);
      p.completedSteps[pathId] = steps;
      p.totalXP += xpReward;
      p.totalLessonsCompleted += 1;
      await _updateStreak(p);
      await saveProgress(p);
      await _checkBadges(p);
    }
    return p;
  }

  static Future<void> _updateStreak(UserProgress p) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (p.lastActiveDate == null) {
      p.streakDays = 1;
      p.lastActiveDate = today;
    } else {
      final last = DateTime(
        p.lastActiveDate!.year,
        p.lastActiveDate!.month,
        p.lastActiveDate!.day,
      );
      final diff = today.difference(last).inDays;
      if (diff == 1) {
        p.streakDays += 1;
        p.lastActiveDate = today;
      } else if (diff > 1) {
        p.streakDays = 1;
        p.lastActiveDate = today;
      }
    }
  }

  static Future<void> _checkBadges(UserProgress p) async {
    final badges = p.earnedBadges;
    if (!badges.contains('first_step') && p.totalLessonsCompleted >= 1) {
      badges.add('first_step');
    }
    if (!badges.contains('streak_3') && p.streakDays >= 3) {
      badges.add('streak_3');
    }
    if (!badges.contains('streak_7') && p.streakDays >= 7) {
      badges.add('streak_7');
    }
    if (!badges.contains('streak_30') && p.streakDays >= 30) {
      badges.add('streak_30');
    }
    if (!badges.contains('xp_100') && p.totalXP >= 100) {
      badges.add('xp_100');
    }
    if (!badges.contains('xp_500') && p.totalXP >= 500) {
      badges.add('xp_500');
    }
    if (!badges.contains('lessons_10') && p.totalLessonsCompleted >= 10) {
      badges.add('lessons_10');
    }
    p.earnedBadges = badges;
  }

  static Future<void> recordInterstitialShown() async {
    final p = getProgress();
    p.lastInterstitialShown = DateTime.now();
    await saveProgress(p);
  }

  static Future<void> setPremium(bool value, {DateTime? expiry}) async {
    final p = getProgress();
    p.isPremium = value;
    p.premiumExpiry = expiry;
    await saveProgress(p);
  }
}
