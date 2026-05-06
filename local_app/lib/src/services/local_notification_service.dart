import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/assignment.dart';
import 'reminder_rule_store.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static String formatDeadlineRemainingText(int offsetMinutes) {
    final safeMinutes = offsetMinutes < 0 ? 0 : offsetMinutes;
    final days = safeMinutes ~/ 1440;
    final hours = (safeMinutes % 1440) ~/ 60;
    final minutes = safeMinutes % 60;
    final parts = <String>[
      if (days > 0) '$days 天',
      if (hours > 0) '$hours 小时',
      if (minutes > 0 || (days == 0 && hours == 0)) '$minutes 分钟',
    ];
    return '还剩 ${parts.join(' ')}截止';
  }

  Future<void> initializeSafely() async {
    try {
      await initialize();
    } catch (_) {
      // Notification support must not block the main app from opening.
    }
  }

  Future<void> initialize() async {
    timezone_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    const android = AndroidInitializationSettings('@drawable/app_icon');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'assignment_deadlines',
            '作业截止提醒',
            description: '学习通作业截止前提醒',
            importance: Importance.high,
          ),
        );
    await _requestNotificationPermission();
    await _requestExactAlarmPermission();
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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _requestExactAlarmPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
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

    await _zonedSchedule(
      assignment,
      offsetMinutes,
      notifyAt,
      AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _zonedSchedule(
    Assignment assignment,
    int offsetMinutes,
    DateTime notifyAt,
    AndroidScheduleMode scheduleMode,
  ) async {
    try {
      await _plugin.zonedSchedule(
        Object.hash(assignment.id, offsetMinutes),
        '作业即将截止',
        '${assignment.courseName} · ${assignment.title}，${formatDeadlineRemainingText(offsetMinutes)}',
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'assignment_deadlines',
            '作业截止提醒',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            ticker: '作业即将截止',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'studyassistant://assignments/${assignment.id}',
      );
    } catch (_) {
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        await _zonedSchedule(
          assignment,
          offsetMinutes,
          notifyAt,
          AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}
