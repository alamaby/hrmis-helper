import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);
    await Permission.notification.request();
  }

  static Future<void> showAttendanceWarning({
    required int lateMinutes,
    required int absenceDays,
  }) async {
    final parts = <String>[];

    if (lateMinutes > 0) {
      parts.add('Delay: $lateMinutes minute${lateMinutes == 1 ? '' : 's'}');
    }

    if (absenceDays > 0) {
      parts.add('Absence: $absenceDays day${absenceDays == 1 ? '' : 's'}');
    }

    if (parts.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'hrmis_attendance_alerts',
      'HRMIS Attendance Alerts',
      channelDescription: 'Alerts for HRMIS delay and absence information.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 1001,
      title: 'HRMIS attendance needs review',
      body: parts.join(' • '),
      notificationDetails: details,
    );
  }
}
