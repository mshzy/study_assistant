import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/assignment.dart';
import 'reminder_rule_store.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initializeSafely() async {
    try {
      await initialize();
    } catch (_) {
      // Notification support must not block the main app from opening.
    }
  }

  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@drawable/app_icon');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'assignment_deadlines',
            '作业截止提醒',
            description: '学习通作业截止前提醒',
            importance: Importance.high,
          ),
        );
    await _requestNotificationPermission();
  }

  Future<void> rescheduleAssignments(
    List<Assignment> assignments, {
    List<int>? offsetsMinutes,
  }) async {
    try {
      await _requestNotificationPermission();
      await _plugin.cancelAll();
      final offsets = ReminderRuleStore.normalizeOffsets(offsetsMinutes);
      for (final assignment in assignments.where((item) => !item.isCompleted)) {
        for (final offset in offsets) {
          await _scheduleReminder(assignment, offset);
        }
      }
    } catch (_) {
      // Notification scheduling can fail on some Android ROMs or when the
      // plugin cannot read old scheduled alarms. The app should still open.
    }
  }

  Future<void> _requestNotificationPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _scheduleReminder(
    Assignment assignment,
    int offsetMinutes,
  ) async {
    final notifyAt = assignment.deadlineAt.subtract(
      Duration(minutes: offsetMinutes),
    );
    final remaining = notifyAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return;
    }

    await _plugin.zonedSchedule(
      Object.hash(assignment.id, offsetMinutes),
      '作业即将截止',
      '${assignment.courseName} · ${assignment.title}，${_offsetLabel(offsetMinutes)}截止',
      tz.TZDateTime.from(notifyAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'assignment_deadlines',
          '作业截止提醒',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'studyassistant://assignments/${assignment.id}',
    );
  }

  String _offsetLabel(int offsetMinutes) {
    if (offsetMinutes % 1440 == 0) {
      return '提前 ${offsetMinutes ~/ 1440} 天';
    }
    if (offsetMinutes % 60 == 0) {
      return '提前 ${offsetMinutes ~/ 60} 小时';
    }
    return '提前 $offsetMinutes 分钟';
  }
}
