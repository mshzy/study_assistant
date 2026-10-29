import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/src/local/chaoxing_local_client.dart';
import 'package:study_assistant_mobile/src/local/local_assignment_repository.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/models/widget_snapshot.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/reminder_rule_store.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  test('logout clears reminder side effects and restores default offsets',
      () async {
    SharedPreferences.setMockInitialValues({
      'auto_sync_interval_minutes': 0,
      'reminder_offsets_minutes': ['60', '15'],
    });
    final repository = LocalAssignmentRepository();
    await repository.mergeAndSave([_assignment('cx:activity:old')]);
    final notifications = _RecordingNotificationService();
    final widget = _RecordingWidgetSnapshotService();
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: notifications,
      widgetSnapshotService: widget,
      repository: repository,
    );
    addTearDown(store.dispose);
    await store.restoreSession();
    notifications.reset();
    widget.reset();

    await store.logout();

    expect(notifications.calls, 1);
    expect(notifications.lastAssignmentIds, isEmpty);
    expect(
      notifications.lastOffsets,
      ReminderRuleStore.defaultOffsetsMinutes,
    );
    expect(
      store.reminderOffsetsMinutes,
      ReminderRuleStore.defaultOffsetsMinutes,
    );
    expect(widget.emptyWrites, 1);
    expect(widget.lastAssignmentIds, isEmpty);
  });

  test('logout invalidates a sync whose fetch completes later', () async {
    SharedPreferences.setMockInitialValues({
      'auto_sync_interval_minutes': 0,
    });
    final repository = LocalAssignmentRepository();
    final client = _DelayedChaoxingClient();
    final notifications = _RecordingNotificationService();
    final widget = _RecordingWidgetSnapshotService();
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: notifications,
      widgetSnapshotService: widget,
      repository: repository,
      chaoxingClient: client,
    );
    addTearDown(store.dispose);
    await store.restoreSession();
    notifications.reset();
    widget.reset();

    final syncFuture = store.syncAssignments();
    await client.fetchStarted.future;
    await store.logout();
    client.fetchResult.complete([_assignment('cx:activity:late')]);
    await syncFuture;

    expect(store.assignments, isEmpty);
    expect(await repository.loadAssignments(), isEmpty);
    expect(notifications.lastAssignmentIds, isEmpty);
    expect(widget.lastAssignmentIds, isEmpty);
  });

  test('logout invalidates a session refresh whose login completes later',
      () async {
    SharedPreferences.setMockInitialValues({
      'auto_sync_interval_minutes': 0,
    });
    final repository = LocalAssignmentRepository();
    final sessionStore = _MutableSessionStore();
    final client = _DelayedRefreshChaoxingClient();
    final notifications = _RecordingNotificationService();
    final widget = _RecordingWidgetSnapshotService();
    final store = AssignmentStore(
      sessionStore: sessionStore,
      notificationService: notifications,
      widgetSnapshotService: widget,
      repository: repository,
      chaoxingClient: client,
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    final syncFuture = store.syncAssignments();
    await client.loginStarted.future;
    await store.logout();
    client.loginResult.complete(
      const ChaoxingLoginResult(
        success: true,
        displayName: '迟到用户',
        avatarUrl: 'https://example.com/late.png',
      ),
    );
    await syncFuture;

    expect(sessionStore.account, isNull);
    expect(sessionStore.password, isNull);
    expect(store.account, isNull);
    expect(store.isAuthenticated, isFalse);
    expect(await repository.loadAssignments(), isEmpty);
  });
}

Assignment _assignment(String id) {
  return Assignment(
    id: id,
    courseName: '大学英语',
    title: '章节作业',
    deadlineAt: DateTime.now().add(const Duration(days: 1)),
    requirementsText: '完成后提交',
    status: 'pending',
    lastSyncedAt: DateTime.now(),
  );
}

class _DelayedChaoxingClient extends ChaoxingLocalClient {
  final fetchStarted = Completer<void>();
  final fetchResult = Completer<List<Assignment>>();

  @override
  Future<List<Assignment>> fetchAssignments() {
    fetchStarted.complete();
    return fetchResult.future;
  }
}

class _DelayedRefreshChaoxingClient extends ChaoxingLocalClient {
  final loginStarted = Completer<void>();
  final loginResult = Completer<ChaoxingLoginResult>();
  var fetchCount = 0;

  @override
  Future<List<Assignment>> fetchAssignments() async {
    fetchCount += 1;
    if (fetchCount == 1) {
      throw StateError('session expired');
    }
    return [];
  }

  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) {
    loginStarted.complete();
    return loginResult.future;
  }
}

class _MemorySessionStore extends SecureSessionStore {
  @override
  Future<String?> readChaoxingAccount() async => 'student';

  @override
  Future<String?> readChaoxingPassword() async => 'password';

  @override
  Future<String?> readChaoxingDisplayName() async => '学生';

  @override
  Future<String?> readChaoxingAvatarUrl() async => 'https://example.com/a.png';

  @override
  Future<String?> readShuniZuilingAccount() async => null;

  @override
  Future<String?> readShuniZuilingPassword() async => null;

  @override
  Future<String?> readShuniZuilingSchoolCode() async => null;

  @override
  Future<void> clear() async {}
}

class _MutableSessionStore extends SecureSessionStore {
  String? account = 'student';
  String? password = 'password';
  String? displayName = '学生';
  String? avatarUrl = 'https://example.com/a.png';

  @override
  Future<String?> readChaoxingAccount() async => account;

  @override
  Future<String?> readChaoxingPassword() async => password;

  @override
  Future<String?> readChaoxingDisplayName() async => displayName;

  @override
  Future<String?> readChaoxingAvatarUrl() async => avatarUrl;

  @override
  Future<String?> readShuniZuilingAccount() async => null;

  @override
  Future<String?> readShuniZuilingPassword() async => null;

  @override
  Future<String?> readShuniZuilingSchoolCode() async => null;

  @override
  Future<void> saveChaoxingAccount({
    required String account,
    required String password,
    String? displayName,
    String? avatarUrl,
  }) async {
    this.account = account;
    this.password = password;
    this.displayName = displayName;
    this.avatarUrl = avatarUrl;
  }

  @override
  Future<void> clear() async {
    account = null;
    password = null;
    displayName = null;
    avatarUrl = null;
  }
}

class _RecordingNotificationService extends LocalNotificationService {
  int calls = 0;
  List<String>? lastAssignmentIds;
  List<int>? lastOffsets;

  void reset() {
    calls = 0;
    lastAssignmentIds = null;
    lastOffsets = null;
  }

  @override
  Future<void> rescheduleAssignments(
    List<Assignment> assignments, {
    List<int>? offsetsMinutes,
  }) async {
    calls += 1;
    lastAssignmentIds = assignments.map((item) => item.id).toList();
    lastOffsets = List.of(offsetsMinutes ?? const []);
  }
}

class _RecordingWidgetSnapshotService extends WidgetSnapshotService {
  int emptyWrites = 0;
  List<String>? lastAssignmentIds;

  void reset() {
    emptyWrites = 0;
    lastAssignmentIds = null;
  }

  void _record(Iterable<String> assignmentIds) {
    lastAssignmentIds = assignmentIds.toList();
    if (lastAssignmentIds!.isEmpty) {
      emptyWrites += 1;
    }
  }

  @override
  Future<void> saveAssignments(List<Assignment> assignments) async {
    _record(assignments.map((item) => item.id));
  }

  @override
  Future<void> saveSnapshot(List<WidgetSnapshotItem> items) async {
    _record(items.map((item) => item.assignmentId));
  }
}
