import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'nexskills_main';
  static const _channelName = 'NexSkills Hub';
  static const _channelDesc = 'Daily learning reminders and streak alerts';

  static const _dailyReminderId = 1;
  static const _streakWarningId = 2;
  static const _newContentId = 3;

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

    await _createChannel();
  }

  static Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _onTap(NotificationResponse response) {
    // Navigation handled at app level
  }

  static Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // ─── Schedule Daily Reminder ─────────────────────────────────
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    int streakDays = 0,
  }) async {
    await _plugin.cancel(_dailyReminderId);

    final String body = streakDays > 0
        ? "🔥 $streakDays day streak! Keep it alive — today's lesson is waiting."
        : "📚 Time to level up! Your daily lesson is ready on NexSkills Hub.";

    await _plugin.zonedSchedule(
      _dailyReminderId,
      "Ready to learn today? 🚀",
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
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
    );
  }

  // ─── Streak Warning (evening if not completed) ───────────────
  static Future<void> scheduleStreakWarning(int streakDays) async {
    if (streakDays == 0) return;
    await _plugin.cancel(_streakWarningId);

    await _plugin.zonedSchedule(
      _streakWarningId,
      "⚠️ Your streak is at risk!",
      "You have a $streakDays day streak — don't let it break! Complete today's lesson now.",
      _nextInstanceOfTime(20, 0), // 8 PM warning
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─── New Content Available ───────────────────────────────────
  static Future<void> showNewContentNotification(
      String category, int count) async {
    await _plugin.show(
      _newContentId,
      "🔥 $count new lessons added!",
      "Fresh $category content is ready in your Explore tab.",
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ─── Badge / Achievement ─────────────────────────────────────
  static Future<void> showBadgeNotification(String badgeName) async {
    await _plugin.show(
      100,
      "🏆 Badge Unlocked!",
      "You just earned the '$badgeName' badge. Keep going!",
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> cancelAll() async => await _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
