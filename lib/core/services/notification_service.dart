import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// NotificationService — redesigned to be a proper reminder system.
///
/// What changed vs v1:
///   - Content notifications no longer fire immediately at app startup.
///   - Each channel with new content gets ONE scheduled notification per day,
///     staggered 3 minutes apart, targeting 2 PM (or earliest future slot).
///   - A per-category cooldown prevents re-notifying for the same category
///     within 24 hours.
///   - Daily learning reminder and streak warning are unchanged.
///
/// Channels:
///   nexskills_learning  — daily reminders / streak alerts (high importance)
///   nexskills_content   — new video alerts (default, no wake, non-intrusive)
///   nexskills_badges    — achievement unlocks (high importance)

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // ─── Channel IDs ──────────────────────────────────────────────
  static const _learningChannelId = 'nexskills_learning';
  static const _contentChannelId  = 'nexskills_content';
  static const _streakChannelId   = 'nexskills_streak';
  static const _badgeChannelId    = 'nexskills_badges';

  // ─── Notification IDs ─────────────────────────────────────────
  static const _dailyReminderId  = 1;
  static const _streakWarningId  = 2;
  // Content alerts: 200-299 (one slot per channel, max 100 channels)
  static const _contentBaseId    = 200;
  static const _badgeBaseId      = 300;

  // ─── Hive settings box (shared with HiveService) ─────────────
  static const _settingsBox = 'settings';
  static Box get _settings => Hive.box(_settingsBox);

  // ─── Init ─────────────────────────────────────────────────────
  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
    );

    await _createChannels();
  }

  static Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _learningChannelId, 'Daily Learning',
      description: 'Daily lesson reminders to keep your streak alive',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _contentChannelId, 'New Content',
      description: 'New videos and articles from your learning paths',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _streakChannelId, 'Streak Alerts',
      description: 'Warning when your learning streak is at risk',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _badgeChannelId, 'Achievements',
      description: 'Badge and milestone notifications',
      importance: Importance.high,
      playSound: true,
    ));
  }

  static void _onTap(NotificationResponse response) {
    // Payload-based deep-link handled at HomeScreen via global key / stream
  }

  // ─── Permissions ──────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // ─── Daily reminder ───────────────────────────────────────────
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    int streakDays = 0,
    String? activeCategory,
  }) async {
    await _plugin.cancel(_dailyReminderId);

    final catLabel = activeCategory != null
        ? _categoryLabel(activeCategory)
        : 'Tech';

    final body = streakDays > 0
        ? '🔥 $streakDays day streak! Keep it going — your $catLabel lesson is ready.'
        : '📚 Your daily $catLabel lesson is waiting. Stay on track!';

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Time to learn something new 🚀',
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _learningChannelId, 'Daily Learning',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'today',
    );
  }

  // ─── Streak warning ───────────────────────────────────────────
  static Future<void> scheduleStreakWarning(int streakDays) async {
    if (streakDays == 0) return;
    await _plugin.cancel(_streakWarningId);

    final body =
        '⚡ You have a $streakDays-day streak — don\'t let it break tonight!\n'
        'Tap to complete today\'s lesson in 10 minutes.';

    await _plugin.zonedSchedule(
      _streakWarningId,
      '⚠️ Streak at risk!',
      body,
      _nextInstanceOfTime(20, 0), // 8 PM
      NotificationDetails(
        android: AndroidNotificationDetails(
          _streakChannelId, 'Streak Alerts',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFFFF6B35),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'today',
    );
  }

  // ─── New content — staggered channel alerts ───────────────────
  ///
  /// Called from RssService after a fetch.  Instead of showing immediately
  /// (which spams the user at app open), we:
  ///
  ///   1. Filter to genuinely new YouTube items.
  ///   2. Group by channel (sourceName).
  ///   3. Schedule ONE notification per channel, at 2 PM today (or tomorrow
  ///      if 2 PM has passed), staggered 3 minutes apart.
  ///   4. Rate-limit with a 24h per-channel cooldown stored in Hive settings.
  ///
  /// This means the user's phone rings ONCE per channel per day in the
  /// afternoon — never at the moment they open the app.
  static Future<void> scheduleChannelAlerts({
    required List<NewVideoInfo> newVideos,
  }) async {
    if (newVideos.isEmpty) return;

    // Base fire time: next 14:00 (2 PM)
    var baseTime = _nextInstanceOfTime(14, 0);

    int slot = 0;
    final today = _todayKey();

    for (final video in newVideos) {
      // Per-channel 24h cooldown
      final cooldownKey = 'notif_ch_${video.channelName.toLowerCase().replaceAll(' ', '_')}';
      final lastSent = _settings.get(cooldownKey, defaultValue: '') as String;
      if (lastSent == today) continue; // Already notified for this channel today

      final notifId = _contentBaseId + (video.channelName.hashCode.abs() % 100);
      final fireAt = baseTime.add(Duration(minutes: slot * 3));
      slot++;

      final title = '🎬 New from ${video.channelName}';
      final body  = '"${_truncate(video.videoTitle, 80)}" — tap to watch.';

      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _contentChannelId, 'New Content',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(body),
            color: const Color(0xFF00D4AA),
            onlyAlertOnce: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: false, presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'explore',
      );

      await _settings.put(cooldownKey, today);

      // Cap at 4 channel notifications per day across all categories
      if (slot >= 4) break;
    }
  }

  // ─── Badge / Achievement ──────────────────────────────────────
  static Future<void> showBadgeNotification(String badgeName) async {
    final body = 'You just earned the \'$badgeName\' badge. Keep going! 🚀';
    await _plugin.show(
      _badgeBaseId + badgeName.hashCode.abs() % 100,
      '🏆 Badge Unlocked!',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _badgeChannelId, 'Achievements',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFFFFD700),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: 'progress',
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────
  static Future<void> cancelAll() async => _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  static String _categoryLabel(String cat) => switch (cat) {
        'ai'            => 'AI',
        'cybersecurity' => 'Cybersecurity',
        'nocode'        => 'No-Code',
        'data'          => 'Data Science',
        'cloud'         => 'Cloud & DevOps',
        _               => cat,
      };
}

/// Lightweight DTO used only to pass new-video info to
/// [NotificationService.scheduleChannelAlerts].
class NewVideoInfo {
  final String channelName;
  final String videoTitle;
  final String category;
  const NewVideoInfo({
    required this.channelName,
    required this.videoTitle,
    required this.category,
  });
}
