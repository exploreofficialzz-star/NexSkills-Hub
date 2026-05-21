import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/resource_model.dart';
import '../models/user_progress.dart';

class HiveService {
  static const _resourceBox      = 'resources';
  static const _progressBox      = 'progress';
  static const _seenIdsBox       = 'seenIds';
  static const _settingsBox      = 'settings';
  static const _consumedBox      = 'explore_consumed';  // ← NEW (Section 4.1)
  static const _healthLogBox     = 'content_health_log';// ← NEW (Section 3.3)
  static const _tapCounterBox    = 'ad_tap_counters';   // ← NEW (Section 3.1/3.2)
  static const _themeModeKey     = 'themeMode';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ResourceModelAdapter());
    Hive.registerAdapter(UserProgressAdapter());
    await Hive.openBox<ResourceModel>(_resourceBox);
    await Hive.openBox<UserProgress>(_progressBox);
    await Hive.openBox<String>(_seenIdsBox);
    await Hive.openBox(_settingsBox);
    // New boxes
    await Hive.openBox<String>(_consumedBox);
    await Hive.openBox<String>(_healthLogBox);
    await Hive.openBox<int>(_tapCounterBox);
  }

  // ─── Resources ───────────────────────────────────────────────
  static Box<ResourceModel> get _resources =>
      Hive.box<ResourceModel>(_resourceBox);

  /// Public access for RssService new-item notification count.
  static Box<ResourceModel> get resourceBox => _resources;

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
      // Always overwrite — ensures type, thumbnail (clearbit logos), and all
      // other fields stay current on every fetch. seenIds is still written for
      // notification-new-count tracking but no longer gates the resource update.
      await _resources.put(item.id, item);
      await seenBox.put(item.id, item.id);
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

  // ─── Explore consumed items (Section 4.1) ─────────────────────
  static Box<String> get _consumed => Hive.box<String>(_consumedBox);

  /// Mark a resource as consumed (watched/read).
  static Future<void> markConsumed(String id) async =>
      _consumed.put(id, DateTime.now().toIso8601String());

  /// Returns true if the resource has been consumed.
  static bool isConsumed(String id) => _consumed.containsKey(id);

  /// Returns all consumed item IDs.
  static Set<String> getAllConsumedIds() => _consumed.keys.cast<String>().toSet();

  /// Clear all consumed items (reset explore history).
  static Future<void> clearConsumedItems() => _consumed.clear();

  // ─── Ad tap counters (Section 3.1 / 3.2) ─────────────────────
  static Box<int> get _tapCounters => Hive.box<int>(_tapCounterBox);

  /// Increment and return the new tap count for [sectionKey].
  static Future<int> incrementTapCounter(String sectionKey) async {
    final current = _tapCounters.get(sectionKey, defaultValue: 0)!;
    final next = current + 1;
    await _tapCounters.put(sectionKey, next);
    return next;
  }

  // ─── User Progress ───────────────────────────────────────────
  static Box<UserProgress> get _progress =>
      Hive.box<UserProgress>(_progressBox);

  static UserProgress getProgress() =>
      _progress.get('main') ?? UserProgress();

  static Future<void> saveProgress(UserProgress progress) async =>
      _progress.put('main', progress);

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
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (p.lastActiveDate == null) {
      p.streakDays = 1;
      p.lastActiveDate = today;
    } else {
      final last = DateTime(p.lastActiveDate!.year, p.lastActiveDate!.month,
          p.lastActiveDate!.day);
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
    final b = p.earnedBadges;
    if (!b.contains('first_step') && p.totalLessonsCompleted >= 1)
      b.add('first_step');
    if (!b.contains('streak_3') && p.streakDays >= 3) b.add('streak_3');
    if (!b.contains('streak_7') && p.streakDays >= 7) b.add('streak_7');
    if (!b.contains('streak_30') && p.streakDays >= 30) b.add('streak_30');
    if (!b.contains('xp_100') && p.totalXP >= 100) b.add('xp_100');
    if (!b.contains('xp_500') && p.totalXP >= 500) b.add('xp_500');
    if (!b.contains('lessons_10') && p.totalLessonsCompleted >= 10)
      b.add('lessons_10');
    p.earnedBadges = b;
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

  // ─── Theme preference ────────────────────────────────────────
  static Box get _settings => Hive.box(_settingsBox);

  static ThemeMode? getThemeMode() {
    final index = _settings.get(_themeModeKey) as int?;
    if (index == null) return null;
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  static Future<void> saveThemeMode(ThemeMode mode) async =>
      _settings.put(_themeModeKey, mode.index);
}
