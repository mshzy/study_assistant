import 'package:flutter/foundation.dart';

import '../local/chaoxing_assignment_parser.dart';
import '../local/chaoxing_local_client.dart';
import '../local/local_assignment_repository.dart';
import '../models/assignment.dart';
import 'local_notification_service.dart';
import 'reminder_rule_store.dart';
import 'secure_session_store.dart';
import 'widget_snapshot_service.dart';

class AssignmentStore extends ChangeNotifier {
  AssignmentStore({
    required this.sessionStore,
    required this.notificationService,
    required this.widgetSnapshotService,
    LocalAssignmentRepository? repository,
    ChaoxingLocalClient? chaoxingClient,
    ReminderRuleStore? reminderRuleStore,
  }) : repository = repository ?? LocalAssignmentRepository(),
       chaoxingClient = chaoxingClient ?? ChaoxingLocalClient(),
       reminderRuleStore = reminderRuleStore ?? ReminderRuleStore();

  final SecureSessionStore sessionStore;
  final LocalNotificationService notificationService;
  final WidgetSnapshotService widgetSnapshotService;
  final LocalAssignmentRepository repository;
  final ChaoxingLocalClient chaoxingClient;
  final ReminderRuleStore reminderRuleStore;

  bool _authenticated = false;
  bool _loading = false;
  bool _agreementAccepted = false;
  String? _error;
  String? _account;
  DateTime? _lastSyncAt;
  List<int> _reminderOffsetsMinutes = ReminderRuleStore.defaultOffsetsMinutes;
  final List<Assignment> _assignments = [];

  bool get isAuthenticated => _authenticated;
  bool get isLoading => _loading;
  bool get agreementAccepted => _agreementAccepted;
  String? get error => _error;
  String? get account => _account;
  DateTime? get lastSyncAt => _lastSyncAt;
  List<int> get reminderOffsetsMinutes =>
      List.unmodifiable(_reminderOffsetsMinutes);
  List<Assignment> get assignments => List.unmodifiable(_assignments);
  List<Assignment> get visibleAssignments =>
      _assignments.where((item) => !item.isCompleted).toList(growable: false);
  Map<String, dynamic>? get syncStatus => {
    'localOnly': true,
    'lastSyncedAt': _lastSyncAt?.toIso8601String(),
    'stale':
        _lastSyncAt == null ||
        DateTime.now().difference(_lastSyncAt!).inHours >= 24,
  };

  Assignment? findAssignment(String assignmentId) {
    for (final assignment in _assignments) {
      if (assignment.id == assignmentId) {
        return assignment;
      }
    }
    return null;
  }

  Future<void> restoreSession() async {
    _account = await sessionStore.readChaoxingAccount();
    _authenticated = _account != null;
    _reminderOffsetsMinutes = await reminderRuleStore.loadOffsetsMinutes();
    _assignments
      ..clear()
      ..addAll(await repository.loadAssignments());
    _lastSyncAt = await repository.lastSyncAt();
    await _afterAssignmentsChanged();
    notifyListeners();
  }

  Future<void> loginChaoxing({
    required String account,
    required String password,
    required bool agreementAccepted,
  }) async {
    if (!agreementAccepted) {
      _error = '请先阅读并同意服务协议和隐私协议';
      notifyListeners();
      return;
    }
    await _run(() async {
      final result = await chaoxingClient.login(
        account: account,
        password: password,
      );
      if (!result.success) {
        throw StateError(result.message ?? '登录失败');
      }
      await sessionStore.saveChaoxingAccount(
        account: account,
        password: password,
      );
      _account = account;
      _agreementAccepted = true;
      _authenticated = true;
      await syncAssignments();
    });
  }

  Future<void> syncAssignments() async {
    await _run(() async {
      final incoming = await chaoxingClient.fetchAssignments();
      final merged = await repository.mergeAndSave(incoming);
      _assignments
        ..clear()
        ..addAll(merged);
      _lastSyncAt = await repository.lastSyncAt();
      await _afterAssignmentsChanged();
    });
  }

  Future<void> importAssignmentsFromHtml(String html) async {
    await _run(() async {
      final incoming = ChaoxingAssignmentParser.parseWorkHtml(
        html,
        fallbackCourseName: '学习通课程',
        sourcePrefix: 'manual',
        baseUri: Uri.parse('https://mooc1.chaoxing.com'),
      );
      final merged = await repository.mergeAndSave(incoming);
      _assignments
        ..clear()
        ..addAll(merged);
      _lastSyncAt = await repository.lastSyncAt();
      await _afterAssignmentsChanged();
    });
  }

  Future<void> refreshAssignments() async {
    _assignments
      ..clear()
      ..addAll(await repository.loadAssignments());
    _lastSyncAt = await repository.lastSyncAt();
    await _afterAssignmentsChanged();
    notifyListeners();
  }

  Future<void> updateCompletion(String assignmentId, bool completed) async {
    await _run(() async {
      final updated = await repository.updateCompletion(
        assignmentId,
        completed,
      );
      _assignments
        ..clear()
        ..addAll(updated);
      await _afterAssignmentsChanged();
    });
  }

  Future<void> saveReminderRule(List<int> offsetsMinutes) async {
    final normalized = await reminderRuleStore.saveOffsetsMinutes(
      offsetsMinutes,
    );
    _reminderOffsetsMinutes = normalized;
    await notificationService.rescheduleAssignments(
      _assignments,
      offsetsMinutes: _reminderOffsetsMinutes,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await sessionStore.clear();
    await repository.clear();
    await reminderRuleStore.clear();
    _authenticated = false;
    _account = null;
    _assignments.clear();
    _lastSyncAt = null;
    await widgetSnapshotService.saveSnapshot([]);
    notifyListeners();
  }

  @visibleForTesting
  void replaceAssignmentsForTest(List<Assignment> assignments) {
    _assignments
      ..clear()
      ..addAll(assignments);
  }

  Future<void> _afterAssignmentsChanged() async {
    await notificationService.rescheduleAssignments(
      _assignments,
      offsetsMinutes: _reminderOffsetsMinutes,
    );
    await widgetSnapshotService.saveAssignments(_assignments);
  }

  Future<void> _run(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Bad state: ', '');
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection') ||
        raw.contains('timeout')) {
      return '作业刷新失败，请检查网络后再试。';
    }
    if (raw.contains('没有获取到作业')) {
      return '暂时没有刷新到作业。如果你确认学习通里有未完成作业，请稍后再试。';
    }
    if (raw.contains('登录失败')) {
      return '登录失败，请检查学习通账号和密码。';
    }
    if (raw.contains('同步失败')) {
      return '登录成功，但作业刷新暂时失败。你可以稍后在同步页重新刷新。';
    }
    return raw.isEmpty ? '操作没有完成，请稍后再试。' : raw;
  }
}
