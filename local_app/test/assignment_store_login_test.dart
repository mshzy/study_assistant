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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'login marks session authenticated even when first assignment sync fails',
    () async {
      final store = AssignmentStore(
        sessionStore: _MemorySessionStore(),
        notificationService: _NoopNotificationService(),
        widgetSnapshotService: _NoopWidgetSnapshotService(),
        chaoxingClient: _LoginOnlyChaoxingClient(),
      );
      addTearDown(store.dispose);

      await store.loginChaoxing(
        account: 'student',
        password: 'password',
        agreementAccepted: true,
      );

      expect(store.isAuthenticated, isTrue);
      expect(store.account, 'student');
      expect(store.error, contains('同步'));
    },
  );

  test(
    'Shuni Zuiling login marks session authenticated even when first sync fails',
    () async {
      final sessionStore = _MemorySessionStore();
      final store = AssignmentStore(
        sessionStore: sessionStore,
        notificationService: _NoopNotificationService(),
        widgetSnapshotService: _NoopWidgetSnapshotService(),
        shuniZuilingClient: _LoginOnlyShuniZuilingClient(),
      );
      addTearDown(store.dispose);

      await store.loginShuniZuiling(
        schoolUserLocalId: '20260001',
        password: 'password',
        schoolCode: 'school',
        agreementAccepted: true,
      );

      expect(store.isAuthenticated, isTrue);
      expect(store.shuniZuilingAccount, '20260001');
      expect(store.error, contains('同步'));
      expect(await sessionStore.readShuniZuilingSchoolCode(), 'school');
    },
  );

  test('loads Shuni Zuiling schools for platform login dropdown', () async {
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      shuniZuilingClient: _SchoolListShuniZuilingClient(),
    );
    addTearDown(store.dispose);

    await store.loadShuniZuilingSchools();

    expect(store.shuniZuilingSchools.map((school) => school.name), [
      '郑州轻工业大学',
    ]);
  });

  test('restoreSession authenticates when only Shuni Zuiling is saved',
      () async {
    final store = AssignmentStore(
      sessionStore: _MemorySessionStore(
        shuniAccount: '20260001',
        shuniSchoolCode: 'school',
      ),
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
    );
    addTearDown(store.dispose);

    await store.restoreSession();

    expect(store.isAuthenticated, isTrue);
    expect(store.shuniZuilingAccount, '20260001');
    expect(store.account, contains('数你最灵'));
  });
}

class _LoginOnlyChaoxingClient extends ChaoxingLocalClient {
  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async {
    return const ChaoxingLoginResult(success: true);
  }

  @override
  Future<List<Assignment>> fetchAssignments() async {
    throw StateError('同步失败');
  }
}

class _LoginOnlyShuniZuilingClient extends ShuniZuilingLocalClient {
  @override
  Future<ShuniZuilingLoginResult> login({
    required String schoolUserLocalId,
    required String password,
    required String schoolCode,
  }) async {
    return const ShuniZuilingLoginResult(success: true, token: 'token');
  }

  @override
  Future<List<Assignment>> fetchAssignments({
    required String studentId,
    List<int> courseIds = const [],
  }) async {
    throw StateError('同步失败');
  }
}

class _SchoolListShuniZuilingClient extends ShuniZuilingLocalClient {
  @override
  Future<List<ShuniZuilingSchool>> fetchSchools() async {
    return const [
      ShuniZuilingSchool(code: 'zzuli', name: '郑州轻工业大学'),
    ];
  }
}

class _MemorySessionStore extends SecureSessionStore {
  _MemorySessionStore({
    this.shuniAccount,
    this.shuniSchoolCode,
  });

  String? account;
  String? password;
  String? shuniAccount;
  String? shuniPassword;
  String? shuniSchoolCode;

  @override
  Future<void> saveChaoxingAccount({
    required String account,
    required String password,
  }) async {
    this.account = account;
    this.password = password;
  }

  @override
  Future<String?> readChaoxingAccount() async => account;

  @override
  Future<String?> readChaoxingPassword() async => password;

  @override
  Future<void> saveShuniZuilingAccount({
    required String schoolUserLocalId,
    required String password,
    required String schoolCode,
  }) async {
    shuniAccount = schoolUserLocalId;
    shuniPassword = password;
    shuniSchoolCode = schoolCode;
  }

  @override
  Future<String?> readShuniZuilingAccount() async => shuniAccount;

  @override
  Future<String?> readShuniZuilingPassword() async => shuniPassword;

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
