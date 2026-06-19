import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/src/local/chaoxing_local_client.dart';
import 'package:study_assistant_mobile/src/local/shuni_zuiling_local_client.dart';
import 'package:study_assistant_mobile/src/features/login_screen.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  testWidgets('login screen switches between Chaoxing and Shuni Zuiling forms',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: _EmptySchoolListShuniZuilingClient(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));

    expect(find.text('学习通'), findsOneWidget);
    expect(find.text('数你最灵'), findsOneWidget);
    expect(find.text('学校代码'), findsNothing);

    await tester.tap(find.text('数你最灵'));
    await tester.pump();

    expect(find.text('学校'), findsOneWidget);
    expect(find.text('学号'), findsOneWidget);
  });

  testWidgets('login screen can render as add platform flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: _EmptySchoolListShuniZuilingClient(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(store: store, addPlatformMode: true)),
    );

    expect(find.text('添加平台账号'), findsOneWidget);
    expect(find.text('学习通'), findsOneWidget);
    expect(find.text('数你最灵'), findsOneWidget);
  });

  testWidgets('Shuni Zuiling form uses school dropdown from store',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: _SchoolListShuniZuilingClient(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.tap(find.text('数你最灵'));
    await tester.pumpAndSettle();

    expect(find.text('郑州轻工业大学'), findsOneWidget);
    expect(find.text('学校代码'), findsNothing);
  });

  testWidgets('school dropdown can be filtered by keyword', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: _SchoolListShuniZuilingClient(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.tap(find.text('数你最灵'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('school-keyword')), '测试');
    await tester.pump();

    expect(find.text('测试大学'), findsOneWidget);
    expect(find.text('郑州轻工业大学'), findsNothing);
  });

  testWidgets('school dropdown value follows keyword filtered result',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: _SchoolListShuniZuilingClient(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.tap(find.text('数你最灵'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('school-keyword')), '测试');
    await tester.pumpAndSettle();

    final field = tester.widget<DropdownButtonFormField<ShuniZuilingSchool>>(
      find.byType(DropdownButtonFormField<ShuniZuilingSchool>),
    );
    expect(field.initialValue?.code, 'test');
    expect(tester.takeException(), isNull);
  });

  testWidgets('school dropdown updates when async school loading completes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = _DelayedSchoolListShuniZuilingClient();
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: client,
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.tap(find.text('数你最灵'));
    await tester.pump();

    expect(find.text('郑州轻工业大学'), findsNothing);

    client.completeSchools();
    await tester.pump();

    expect(find.text('郑州轻工业大学'), findsOneWidget);
  });

  testWidgets('login failure is shown without additional typing',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      chaoxingClient: _FailingChaoxingClient(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.enterText(find.byType(TextField).at(0), 'student');
    await tester.enterText(find.byType(TextField).at(1), 'bad-password');
    await tester.pump();
    await tester.tap(find.text('登录学习通'));
    await tester.pumpAndSettle();

    expect(find.textContaining('登录失败'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}

class _MemorySessionStore extends SecureSessionStore {}

class _SchoolListShuniZuilingClient extends ShuniZuilingLocalClient {
  @override
  Future<List<ShuniZuilingSchool>> fetchSchools() async {
    return const [
      ShuniZuilingSchool(code: 'zzuli', name: '郑州轻工业大学'),
      ShuniZuilingSchool(code: 'test', name: '测试大学'),
    ];
  }
}

class _EmptySchoolListShuniZuilingClient extends ShuniZuilingLocalClient {
  @override
  Future<List<ShuniZuilingSchool>> fetchSchools() async => const [];
}

class _DelayedSchoolListShuniZuilingClient extends ShuniZuilingLocalClient {
  final _completer = Completer<List<ShuniZuilingSchool>>();

  @override
  Future<List<ShuniZuilingSchool>> fetchSchools() => _completer.future;

  void completeSchools() {
    _completer.complete(const [
      ShuniZuilingSchool(code: 'zzuli', name: '郑州轻工业大学'),
    ]);
  }
}

class _FailingChaoxingClient extends ChaoxingLocalClient {
  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async {
    return const ChaoxingLoginResult(success: false, message: '登录失败');
  }
}

class _NoopNotificationService extends LocalNotificationService {
  @override
  Future<void> rescheduleAssignments(
    List<Assignment> assignments, {
    List<int>? offsetsMinutes,
  }) async {}
}

class _NoopWidgetSnapshotService extends WidgetSnapshotService {
  @override
  Future<void> saveAssignments(List<Assignment> assignments) async {}
}
