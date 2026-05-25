import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/src/local/chaoxing_local_client.dart';
import 'package:study_assistant_mobile/src/local/shuni_zuiling_local_client.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  test('syncAssignments merges Chaoxing and Shuni Zuiling homework', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(
        account: 'student',
        password: 'password',
        shuniAccount: '20260001',
        shuniSchoolCode: 'school',
      ),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      chaoxingClient: _FakeChaoxingClient([
        _assignment(id: 'cx:activity:1', title: '学习通作业'),
      ]),
      shuniZuilingClient: _FakeShuniZuilingClient([
        _assignment(id: 'snzl:987', title: '数你最灵作业'),
      ]),
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    await store.syncAssignments();

    expect(store.error, isNull);
    expect(store.assignments.map((item) => item.id), [
      'cx:activity:1',
      'snzl:987',
    ]);
  });
}

Assignment _assignment({required String id, required String title}) {
  return Assignment(
    id: id,
    courseName: '高等数学',
    title: title,
    deadlineAt: DateTime(2026, 5, 28, 22),
    requirementsText: '完成后提交',
    status: 'pending',
    lastSyncedAt: DateTime(2026, 5, 25, 12),
  );
}

class _FakeChaoxingClient extends ChaoxingLocalClient {
  _FakeChaoxingClient(this.assignments);

  final List<Assignment> assignments;

  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async {
    return const ChaoxingLoginResult(success: true);
  }

  @override
  Future<List<Assignment>> fetchAssignments() async => assignments;
}

class _FakeShuniZuilingClient extends ShuniZuilingLocalClient {
  _FakeShuniZuilingClient(this.assignments);

  final List<Assignment> assignments;

  @override
  Future<List<Assignment>> fetchAssignments({
    required String studentId,
    List<int> courseIds = const [],
  }) async =>
      assignments;
}

class _MemorySessionStore extends SecureSessionStore {
  _MemorySessionStore({
    this.account,
    this.password,
    this.shuniAccount,
    this.shuniSchoolCode,
  });

  final String? account;
  final String? password;
  final String? shuniAccount;
  final String? shuniSchoolCode;

  @override
  Future<String?> readChaoxingAccount() async => account;

  @override
  Future<String?> readChaoxingPassword() async => password;

  @override
  Future<String?> readShuniZuilingAccount() async => shuniAccount;

  @override
  Future<String?> readShuniZuilingPassword() async => null;

  @override
  Future<String?> readShuniZuilingSchoolCode() async => shuniSchoolCode;
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
