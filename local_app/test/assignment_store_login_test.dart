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
      expect(store.profileDisplayName, '李雷');
      expect(store.profileAvatarUrl, 'https://photo.chaoxing.com/p/998877_160');
      expect(await store.sessionStore.readChaoxingDisplayName(), '李雷');
      expect(
        await store.sessionStore.readChaoxingAvatarUrl(),
        'https://photo.chaoxing.com/p/998877_160',
      );
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

  test('refreshing Chaoxing session saves recovered profile data', () async {
    final sessionStore = _MemorySessionStore()
      ..account = 'student'
      ..password = 'password';
    final store = AssignmentStore(
      sessionStore: sessionStore,
      notificationService: _NoopNotificationService(),
      widgetSnapshotService: _NoopWidgetSnapshotService(),
      chaoxingClient: _RefreshingChaoxingClient(),
    );
    addTearDown(store.dispose);
    await store.restoreSession();

    await store.syncAssignments();

    expect(store.profileDisplayName, '郜小展');
    expect(await sessionStore.readChaoxingDisplayName(), '郜小展');
    expect(
      await sessionStore.readChaoxingAvatarUrl(),
      'https://photo.chaoxing.com/p/402733611_160',
    );
  });
}

class _LoginOnlyChaoxingClient extends ChaoxingLocalClient {
  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async {
    return const ChaoxingLoginResult(
      success: true,
      displayName: '李雷',
      avatarUrl: 'https://photo.chaoxing.com/p/998877_160',
    );
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

class _RefreshingChaoxingClient extends ChaoxingLocalClient {
  @override
  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async {
    return const ChaoxingLoginResult(
      success: true,
      displayName: '郜小展',
      avatarUrl: 'https://photo.chaoxing.com/p/402733611_160',
    );
  }

  @override
  Future<List<Assignment>> fetchAssignments() async {
    return [
      Assignment(
        id: 'cx:1',
        courseName: '高等数学',
        title: '习题作业',
        deadlineAt: DateTime.now().add(const Duration(days: 1)),
        requirementsText: '完成后提交',
        status: 'pending',
        lastSyncedAt: DateTime.now(),
      ),
    ];
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
    String? displayName,
    String? avatarUrl,
  }) async {
    this.account = account;
    this.password = password;
    chaoxingDisplayName = displayName;
    chaoxingAvatarUrl = avatarUrl;
  }

  @override
  Future<String?> readChaoxingAccount() async => account;

  String? chaoxingDisplayName;
  String? chaoxingAvatarUrl;

  @override
  Future<String?> readChaoxingDisplayName() async => chaoxingDisplayName;

  @override
  Future<String?> readChaoxingAvatarUrl() async => chaoxingAvatarUrl;

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
