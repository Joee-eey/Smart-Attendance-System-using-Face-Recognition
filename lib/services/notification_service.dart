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
  }

  static Future<void> checkPermissions() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  static Future<void> scheduleAttendanceReminder({
    required int classId,
    required String className,
    required DateTime scheduledTime,
  }) async {
    log("SERVICE: Scheduling $className for ${scheduledTime.toLocal()}");
    
    await _notificationsPlugin.zonedSchedule(
      classId,
      'Take Attendance! 🔔',
      'Your class "$className" has started.',
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
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
      0, 
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> scheduleTestNotification() async {
    await _notificationsPlugin.show(
      999,
      'Instant Check 🔔',
      'If you see this, your Samsung is allowing notifications!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_reminders_channel',
          'Attendance Alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> cancelAll() async => await _notificationsPlugin.cancelAll();
}