import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/main.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';
import 'package:study_assistant_mobile/src/services/app_update_service.dart';
import 'package:study_assistant_mobile/src/services/assignment_store.dart';
import 'package:study_assistant_mobile/src/services/local_notification_service.dart';
import 'package:study_assistant_mobile/src/services/secure_session_store.dart';
import 'package:study_assistant_mobile/src/services/widget_snapshot_service.dart';

void main() {
  testWidgets('iOS startup does not check for APK updates', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync_interval_minutes': 0});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final updateService = _CountingUpdateService();
      final store = AssignmentStore(
        sessionStore: SecureSessionStore(),
        notificationService: _NoopNotificationService(),
        widgetSnapshotService: _NoopWidgetSnapshotService(),
      );
      addTearDown(store.dispose);

      await tester.pumpWidget(
        StudyAssistantApp(
          assignmentStore: store,
          notificationService: _NoopNotificationService(),
          updateService: updateService,
        ),
      );
      await tester.pump();

      expect(updateService.checkCalls, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _CountingUpdateService extends AppUpdateService {
  int checkCalls = 0;

  @override
  Future<AppUpdateInfo?> checkForUpdate({
    required String currentVersionName,
    required int currentVersionCode,
  }) async {
    checkCalls += 1;
    return null;
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
