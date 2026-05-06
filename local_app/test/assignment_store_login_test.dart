import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/local/chaoxing_local_client.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  test(
    'login marks session authenticated even when first assignment sync fails',
    () async {
      final store = AssignmentStore(
        sessionStore: _MemorySessionStore(),
        notificationService: _NoopNotificationService(),
        widgetSnapshotService: _NoopWidgetSnapshotService(),
        chaoxingClient: _LoginOnlyChaoxingClient(),
      );

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

class _MemorySessionStore extends SecureSessionStore {
  String? account;
  String? password;

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
