import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/src/features/reminder_settings_screen.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  testWidgets('shows permission controls needed for reminders', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReminderSettingsScreen(store: store))),
    );

    expect(find.text('提醒权限'), findsOneWidget);
    expect(find.text('通知权限'), findsOneWidget);
    expect(find.text('精确闹钟'), findsOneWidget);
    expect(find.text('锁屏提醒'), findsOneWidget);
    expect(find.text('后台与自启动'), findsOneWidget);
  });

  testWidgets('adds and removes a custom reminder time', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReminderSettingsScreen(store: store)),
      ),
    );

    await tester.ensureVisible(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('提前 45 分钟'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    expect(find.text('提前 45 分钟'), findsNothing);
  });

  testWidgets('adds a custom reminder with hours and minutes', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReminderSettingsScreen(store: store))),
    );

    await tester.ensureVisible(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('提前 1 小时 30 分钟'), findsOneWidget);
  });
}

class _NoopNotificationService extends LocalNotificationService {
  @override
  Future<void> rescheduleAssignments(
    List<Assignment> assignments, {
    List<int>? offsetsMinutes,
  }) async {}
}

class _MemorySessionStore extends SecureSessionStore {
  @override
  Future<String?> readChaoxingAccount() async => 'student';
}

class _NoopWidgetSnapshotService extends WidgetSnapshotService {
  @override
  Future<void> saveAssignments(List<Assignment> assignments) async {}
}
