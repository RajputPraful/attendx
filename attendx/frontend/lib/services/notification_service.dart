import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles local notifications:
///  - a morning reminder of the day's schedule
///  - low-attendance warning alerts
///
/// These are scheduled client-side based on data already fetched from the
/// AttendX API (today's class slots / dashboard summary), so no server push
/// infrastructure is required for the base app.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);
  }

  Future<void> showMorningReminder(String summary) async {
    await _plugin.show(
      1001,
      'Today\'s Schedule',
      summary,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminder',
          'Morning Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showLowAttendanceWarning(String subjectName, double percentage) async {
    await _plugin.show(
      2000 + subjectName.hashCode % 1000,
      'Low Attendance Warning',
      '$subjectName is at ${percentage.toStringAsFixed(1)}% — below the required threshold.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_warning',
          'Attendance Warnings',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedules a daily repeating reminder at the given hour/minute using
  /// zonedSchedule in a full implementation (requires timezone package setup);
  /// for brevity this app triggers the check on launch + via a periodic timer
  /// in main.dart. See docs/ARCHITECTURE.md for how to wire true OS-level
  /// daily scheduling with flutter_local_notifications + timezone.
  Future<void> scheduleDailyCheckPlaceholder() async {}
}
