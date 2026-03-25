import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'attendance_reminders_channel', 
        'Attendance Alerts',
        description: 'Notifications for class attendance reminders',
        importance: Importance.max, 
        playSound: true,
        showBadge: true,
      ));
      
      await androidPlugin.requestNotificationsPermission();
    }

    // Required on some Android devices for exact alarms.
    await checkPermissions();
  }

  static Future<void> checkPermissions() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  // We use per-session (date-specific) notifications instead of repeating weekly,
  // because "10 minutes before class ends IF attendance not taken" must be cancellable
  // for only that specific session.
  static Future<void> scheduleAttendanceStart({
    required int notificationId,
    required String className,
    required DateTime scheduledTime,
  }) async {
    log("SERVICE: Scheduling START $className for ${scheduledTime.toLocal()}");

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Take Attendance!',
      'Your class "$className" has started. Take attendance now.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_reminders_channel',
          'Attendance Alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleAttendancePreEnd({
    required int notificationId,
    required String className,
    required DateTime scheduledTime,
  }) async {
    log("SERVICE: Scheduling PRE-END $className for ${scheduledTime.toLocal()}");

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Attendance Reminder',
      '10 minutes left for "$className". Attendance not taken yet.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_reminders_channel',
          'Attendance Alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'attendance_reminders_channel',
      'Attendance Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2000000000),
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static int buildSessionNotificationId({
    required int classId,
    required DateTime sessionDate,
    required int type, // 1 = start, 2 = preEnd
  }) {
    // Must be < 2,147,483,647 (Android int32).
    final mmdd = (sessionDate.month * 100) + sessionDate.day; // 101..1231
    final base = (classId % 10000) * 100000; // 0..999,900,000
    return base + (type * 10000) + (mmdd * 10);
  }

  static Future<void> cancel(int id) async => _notificationsPlugin.cancel(id);
  static Future<void> cancelAll() async => await _notificationsPlugin.cancelAll();
}