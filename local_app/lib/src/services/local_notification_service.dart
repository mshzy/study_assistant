import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/assignment.dart';

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
    const android = AndroidInitializationSettings('@drawable/app_icon');
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(const InitializationSettings(android: android, iOS: ios));
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
  }

  Future<void> rescheduleAssignments(List<Assignment> assignments) async {
    await _plugin.cancelAll();
    for (final assignment in assignments.where((item) => !item.isCompleted)) {
      await _scheduleImmediatePreview(assignment);
    }
  }

  Future<void> _scheduleImmediatePreview(Assignment assignment) async {
    final remaining = assignment.deadlineAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return;
    }
    if (remaining.inHours > 24) {
      return;
    }

    await _plugin.show(
      assignment.id.hashCode,
      '作业即将截止',
      '${assignment.courseName} · ${assignment.title}',
      const NotificationDetails(
        android: AndroidNotificationDetails('assignment_deadlines', '作业截止提醒',
            importance: Importance.high),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'studyassistant://assignments/${assignment.id}',
    );
  }
}
