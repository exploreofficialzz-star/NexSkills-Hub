import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// NotificationService — Production-ready notification system.
///
/// Channels:
///   nexskills_learning  — daily reminders, lesson prompts (high importance)
///   nexskills_content   — new content drops (default importance, non-intrusive)
///   nexskills_streak    — streak warnings (max importance, urgent)
///   nexskills_badges    — achievement unlocks (high importance)
///
/// New content notifications:
///   Called from RssService.fetchAll() after a successful fetch.
///   If new items were found since last fetch, fires immediately.
///   Batched per category so user sees one notification per category max.

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const _learningChannelId = 'nexskills_learning';
  static const _contentChannelId  = 'nexskills_content';
  static const _streakChannelId   = 'nexskills_streak';
  static const _badgeChannelId    = 'nexskills_badges';

  // Notification IDs
  static const _dailyReminderId   = 1;
  static const _streakWarningId   = 2;
  static const _newContentBaseId  = 100; // 100-104 per category
  static const _badgeBaseId       = 200;

  // Category → notification ID offset
  static const _categoryIds = {
    'ai': 0, 'cybersecurity': 1, 'nocode': 2, 'data': 3, 'cloud': 4,
  };

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

    // Learning reminders — high importance (chimes)
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _learningChannelId,
      'Daily Learning',
      description: 'Daily lesson reminders to keep your streak alive',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    // New content — default (no wake, just appears in shade)
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _contentChannelId,
      'New Content',
      description: 'New lessons and articles from your learning tracks',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    ));

    // Streak warnings — max (this is urgent)
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _streakChannelId,
      'Streak Alerts',
      description: 'Warning when your learning streak is at risk',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    // Badges — high
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _badgeChannelId,
      'Achievements',
      description: 'Badge and milestone notifications',
      importance: Importance.high,
      playSound: true,
    ));
  }

  static void _onTap(NotificationResponse response) {
    // Deep-link navigation handled at app level via payload
    final payload = response.payload;
    if (payload != null) {
      // e.g. 'explore', 'today', 'progress'
      // HomeScreen can listen to a GlobalKey or stream for this
    }
  }

  // ─── Permissions ──────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // ─── Daily reminder ───────────────────────────────────────────
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    int streakDays = 0,
  }) async {
    await _plugin.cancel(_dailyReminderId);

    final body = streakDays > 0
        ? '🔥 $streakDays day streak! Keep it alive — today\'s lesson is waiting.'
        : '📚 Time to level up! Your daily lesson is ready on NexSkills Hub.';

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Ready to learn today? 🚀',
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _learningChannelId,
          'Daily Learning',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'today',
    );
  }

  // ─── Streak warning (8 PM if no lesson done today) ───────────
  static Future<void> scheduleStreakWarning(int streakDays) async {
    if (streakDays == 0) return;
    await _plugin.cancel(_streakWarningId);

    final body =
        '⚡ You have a $streakDays day streak — don\'t let it break tonight!\nTap to complete today\'s lesson in 10 minutes.';

    await _plugin.zonedSchedule(
      _streakWarningId,
      '⚠️ Streak at risk!',
      body,
      _nextInstanceOfTime(20, 0),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _streakChannelId,
          'Streak Alerts',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFFFF6B35),
          fullScreenIntent: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
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

  // ─── New content notification ─────────────────────────────────
  /// Called from RssService after fetch. Shows one notification per
  /// category that has new content. Non-intrusive (no sound/vibration).
  static Future<void> showNewContentNotification(
    String category,
    int count,
  ) async {
    if (count <= 0) return;

    final offset = _categoryIds[category] ?? 0;
    final notifId = _newContentBaseId + offset;

    final catLabel = _categoryLabel(category);
    final title = '📡 $count new $catLabel ${count == 1 ? 'lesson' : 'lessons'}!';
    const body = 'Fresh content is ready in your Explore tab. Tap to learn now.';

    await _plugin.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _contentChannelId,
          'New Content',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          styleInformation: const BigTextStyleInformation(body),
          color: const Color(0xFF00D4AA),
          onlyAlertOnce: true, // Don't re-alert if notification already visible
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'explore',
    );
  }

  /// Show a batch notification when multiple categories have new content.
  static Future<void> showBatchContentNotification(
      Map<String, int> newCounts) async {
    if (newCounts.isEmpty) return;

    final total = newCounts.values.fold(0, (a, b) => a + b);
    final categories = newCounts.keys.map(_categoryLabel).join(', ');

    await _plugin.show(
      _newContentBaseId,
      '🎉 $total new lessons across $categories!',
      'Tap to explore the latest tech content — updated today.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _contentChannelId,
          'New Content',
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
          styleInformation: const BigTextStyleInformation(
              'Tap to explore the latest tech content — updated today.'),
          color: const Color(0xFF6C63FF),
          onlyAlertOnce: true,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
      payload: 'explore',
    );
  }

  // ─── Badge / Achievement ─────────────────────────────────────
  static Future<void> showBadgeNotification(String badgeName) async {
    final body = 'You just earned the \'$badgeName\' badge. Keep going! 🚀';
    await _plugin.show(
      _badgeBaseId + badgeName.hashCode.abs() % 100,
      '🏆 Badge Unlocked!',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _badgeChannelId,
          'Achievements',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFFFFD700),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: 'progress',
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────
  static Future<void> cancelAll() async => _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _categoryLabel(String cat) => switch (cat) {
        'ai'           => 'AI',
        'cybersecurity'=> 'Cybersecurity',
        'nocode'       => 'No-Code',
        'data'         => 'Data',
        'cloud'        => 'Cloud',
        _              => cat,
      };
}
