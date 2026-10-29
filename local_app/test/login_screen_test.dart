import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('add platform flow shows a back button', (tester) async {
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

    expect(find.byTooltip('返回'), findsOneWidget);
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

  testWidgets('failed add-platform login stays on the form', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    final store = AssignmentStore(
      sessionStore: _ExistingShuniSessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      chaoxingClient: _FailingChaoxingClient(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => LoginScreen(
            store: store,
            addPlatformMode: true,
          ),
        ),
        GoRoute(
          path: '/assignments',
          builder: (_, __) => const Scaffold(body: Text('作业页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField).at(0), 'student');
    await tester.enterText(find.byType(TextField).at(1), 'bad-password');
    await tester.pump();
    await tester.tap(find.text('登录学习通'));
    await tester.pumpAndSettle();

    expect(store.error, contains('登录失败'));
    expect(find.textContaining('登录失败'), findsOneWidget);
    expect(find.text('添加平台账号'), findsOneWidget);
    expect(find.text('作业页'), findsNothing);
  });

  testWidgets('successful login to an already bound platform returns home',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    final store = AssignmentStore(
      sessionStore: _ExistingChaoxingSessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      chaoxingClient: _SuccessfulChaoxingClient(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => LoginScreen(store: store, addPlatformMode: true),
        ),
        GoRoute(
          path: '/assignments',
          builder: (_, __) => const Scaffold(body: Text('作业页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField).at(0), 'student');
    await tester.enterText(find.byType(TextField).at(1), 'new-password');
    await tester.pump();
    await tester.tap(find.text('登录学习通'));
    await tester.pumpAndSettle();

    expect(find.text('作业页'), findsOneWidget);
  });
}

class _MemorySessionStore extends SecureSessionStore {}

class _ExistingShuniSessionStore extends SecureSessionStore {
  @override
  Future<String?> readChaoxingAccount() async => null;

  @override
  Future<String?> readChaoxingDisplayName() async => null;

  @override
  Future<String?> readChaoxingAvatarUrl() async => null;

  @override
  Future<String?> readShuniZuilingAccount() async => 'existing-student';

  @override
  Future<String?> readShuniZuilingSchoolCode() async => 'existing-school';
}

class _ExistingChaoxingSessionStore extends SecureSessionStore {
  @override
  Future<String?> readChaoxingAccount() async => 'student';

  @override
  Future<String?> readChaoxingDisplayName() async => '学生';

  @override
  Future<String?> readChaoxingAvatarUrl() async => 'https://example.com/a.png';

  @override
  Future<String?> readShuniZuilingAccount() async => null;

  @override
  Future<String?> readShuniZuilingSchoolCode() async => null;

  @override
  Future<void> saveChaoxingAccount({
    required String account,
    required String password,
    String? displayName,
    String? avatarUrl,
  }) async {}
}

class _SuccessfulChaoxingClient extends ChaoxingLocalClient {
  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async =>
      const ChaoxingLoginResult(
        success: true,
        displayName: '学生',
        avatarUrl: 'https://example.com/a.png',
      );

  @override
  Future<List<Assignment>> fetchAssignments() async => [];
}

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
