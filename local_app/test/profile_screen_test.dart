import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/src/features/profile_screen.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/services/app_update_service.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  testWidgets('profile exposes add platform account entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));

    expect(find.text('添加平台账号'), findsOneWidget);
  });

  testWidgets('profile uses Chaoxing student display name', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(displayName: '李雷'),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));

    expect(find.text('李雷'), findsOneWidget);
    expect(find.text('小明同学'), findsNothing);
  });

  testWidgets('profile checks app update and offers apk download',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final updateService = _FakeUpdateService(
      update: const AppUpdateInfo(
        versionName: '1.0.7',
        releaseUrl:
            'https://github.com/mshzy/study_assistant/releases/tag/v1.0.7',
        apkName: 'study-assistant-v1.0.7.apk',
        apkDownloadUrl:
            'https://github.com/mshzy/study_assistant/releases/download/v1.0.7/study-assistant-v1.0.7.apk',
        releaseNotes: '修复问题',
      ),
    );
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            store: store,
            updateService: updateService,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 1.0.7'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
  });
  testWidgets('profile settings contain reminder and sync entries',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(store: store)),
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('提醒设置'), findsOneWidget);
    expect(find.text('同步学习通'), findsOneWidget);
    expect(find.text('数据备份'), findsOneWidget);
    expect(find.text('帮助与反馈'), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);
  });
}

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService({this.update});

  final AppUpdateInfo? update;

  @override
  Future<AppUpdateInfo?> checkForUpdate({
    required String currentVersionName,
    required int currentVersionCode,
  }) async {
    return update;
  }
}

class _MemorySessionStore extends SecureSessionStore {
  _MemorySessionStore({this.displayName});

  final String? displayName;

  @override
  Future<String?> readChaoxingAccount() async => 'student';

  @override
  Future<String?> readChaoxingDisplayName() async => displayName;

  @override
  Future<String?> readShuniZuilingAccount() async => null;

  @override
  Future<String?> readShuniZuilingPassword() async => null;

  @override
  Future<String?> readShuniZuilingSchoolCode() async => null;
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
