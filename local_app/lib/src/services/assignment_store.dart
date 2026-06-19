import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/chaoxing_assignment_parser.dart';
import '../local/chaoxing_local_client.dart';
import '../local/local_assignment_repository.dart';
import '../local/shuni_zuiling_local_client.dart';
import '../models/assignment.dart';
import 'local_notification_service.dart';
import 'reminder_rule_store.dart';
import 'secure_session_store.dart';
import 'widget_snapshot_service.dart';

class AssignmentStore extends ChangeNotifier {
  static const defaultAutoSyncIntervalMinutes = 30;
  static const _autoSyncIntervalKey = 'auto_sync_interval_minutes';

  AssignmentStore({
    required this.sessionStore,
    required this.notificationService,
    required this.widgetSnapshotService,
    LocalAssignmentRepository? repository,
    ChaoxingLocalClient? chaoxingClient,
    ShuniZuilingLocalClient? shuniZuilingClient,
    ReminderRuleStore? reminderRuleStore,
  })  : repository = repository ?? LocalAssignmentRepository(),
        chaoxingClient = chaoxingClient ?? ChaoxingLocalClient(),
        shuniZuilingClient = shuniZuilingClient ?? ShuniZuilingLocalClient(),
        reminderRuleStore = reminderRuleStore ?? ReminderRuleStore();

  final SecureSessionStore sessionStore;
  final LocalNotificationService notificationService;
  final WidgetSnapshotService widgetSnapshotService;
  final LocalAssignmentRepository repository;
  final ChaoxingLocalClient chaoxingClient;
  final ShuniZuilingLocalClient shuniZuilingClient;
  final ReminderRuleStore reminderRuleStore;

  bool _authenticated = false;
  bool _loading = false;
  bool _agreementAccepted = false;
  String? _error;
  String? _account;
  String? _chaoxingDisplayName;
  String? _chaoxingAvatarUrl;
  String? _shuniZuilingAccount;
  String? _shuniZuilingSchoolCode;
  DateTime? _lastSyncAt;
  List<int> _reminderOffsetsMinutes = ReminderRuleStore.defaultOffsetsMinutes;
  int _autoSyncIntervalMinutes = defaultAutoSyncIntervalMinutes;
  final List<Assignment> _assignments = [];
  final List<ShuniZuilingSchool> _shuniZuilingSchools = [];
  Timer? _autoSyncTimer;
  bool _autoSyncRunning = false;

  bool get isAuthenticated => _authenticated;
  bool get isLoading => _loading;
  bool get agreementAccepted => _agreementAccepted;
  String? get error => _error;
  String? get account {
    if (_account != null && _shuniZuilingAccount == null) {
      return _account;
    }
    final labels = <String>[
      if (_account != null) '学习通：$_account',
      if (_shuniZuilingAccount != null) '数你最灵：$_shuniZuilingAccount',
    ];
    if (labels.isEmpty) {
      return null;
    }
    return labels.join('\n');
  }

  String? get chaoxingAccount => _account;
  String? get profileAvatarUrl => _chaoxingAvatarUrl;

  String get profileDisplayName {
    final name = _chaoxingDisplayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final account = _account?.trim();
    if (account != null && account.isNotEmpty) {
      return account;
    }
    final shuniAccount = _shuniZuilingAccount?.trim();
    if (shuniAccount != null && shuniAccount.isNotEmpty) {
      return shuniAccount;
    }
    return '同学';
  }

  String? get shuniZuilingAccount => _shuniZuilingAccount;
  List<ShuniZuilingSchool> get shuniZuilingSchools =>
      List.unmodifiable(_shuniZuilingSchools);
  DateTime? get lastSyncAt => _lastSyncAt;
  int get autoSyncIntervalMinutes => _autoSyncIntervalMinutes;
  List<int> get reminderOffsetsMinutes =>
      List.unmodifiable(_reminderOffsetsMinutes);
  List<Assignment> get assignments => List.unmodifiable(_assignments);
  List<Assignment> get visibleAssignments =>
      _assignments.where((item) => !item.isCompleted).toList(growable: false);
  Map<String, dynamic>? get syncStatus => {
        'localOnly': true,
        'lastSyncedAt': _lastSyncAt?.toIso8601String(),
        'stale': _lastSyncAt == null ||
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
    _chaoxingDisplayName = await sessionStore.readChaoxingDisplayName();
    _chaoxingAvatarUrl = await sessionStore.readChaoxingAvatarUrl();
    _shuniZuilingAccount = await sessionStore.readShuniZuilingAccount();
    _shuniZuilingSchoolCode = await sessionStore.readShuniZuilingSchoolCode();
    _authenticated = _account != null || _shuniZuilingAccount != null;
    _reminderOffsetsMinutes = await reminderRuleStore.loadOffsetsMinutes();
    _autoSyncIntervalMinutes = await _loadAutoSyncIntervalMinutes();
    _assignments
      ..clear()
      ..addAll(await repository.loadAssignments());
    _lastSyncAt = await repository.lastSyncAt();
    await _afterAssignmentsChanged();
    _restartAutoSyncTimer();
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
        displayName: result.displayName,
        avatarUrl: result.avatarUrl,
      );
      _account = account;
      _chaoxingDisplayName = result.displayName;
      _chaoxingAvatarUrl = result.avatarUrl;
      _agreementAccepted = true;
      _authenticated = true;
      _restartAutoSyncTimer();
      try {
        await _syncAssignmentsBody();
      } catch (error) {
        _error = _friendlyError(error);
      }
    });
  }

  Future<void> loginShuniZuiling({
    required String schoolUserLocalId,
    required String password,
    required String schoolCode,
    required bool agreementAccepted,
  }) async {
    if (!agreementAccepted) {
      _error = '请先阅读并同意服务协议和隐私协议';
      notifyListeners();
      return;
    }
    await _run(() async {
      final normalizedAccount = schoolUserLocalId.trim();
      final normalizedSchoolCode = schoolCode.trim();
      final result = await shuniZuilingClient.login(
        schoolUserLocalId: normalizedAccount,
        password: password,
        schoolCode: normalizedSchoolCode,
      );
      if (!result.success) {
        throw StateError(result.message ?? '数你最灵登录失败');
      }
      await sessionStore.saveShuniZuilingAccount(
        schoolUserLocalId: normalizedAccount,
        password: password,
        schoolCode: normalizedSchoolCode,
      );
      _shuniZuilingAccount = normalizedAccount;
      _shuniZuilingSchoolCode = normalizedSchoolCode;
      _agreementAccepted = true;
      _authenticated = true;
      _restartAutoSyncTimer();
      try {
        await _syncAssignmentsBody();
      } catch (error) {
        _error = _friendlyError(error);
      }
    });
  }

  Future<void> loadShuniZuilingSchools() async {
    if (_shuniZuilingSchools.isNotEmpty) {
      return;
    }
    try {
      final schools = await shuniZuilingClient.fetchSchools();
      _shuniZuilingSchools
        ..clear()
        ..addAll(schools);
      notifyListeners();
    } catch (_) {
      // Manual retries are enough here; school loading should not block login UI.
    }
  }

  Future<void> syncAssignments() async {
    await _run(() async {
      await _syncAssignmentsBody();
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

  Future<void> saveAutoSyncIntervalMinutes(int minutes) async {
    final normalized = normalizeAutoSyncIntervalMinutes(minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoSyncIntervalKey, normalized);
    _autoSyncIntervalMinutes = normalized;
    _restartAutoSyncTimer();
    notifyListeners();
  }

  Future<bool> runDueAutoSync({DateTime? now}) async {
    if (!_authenticated ||
        _autoSyncIntervalMinutes <= 0 ||
        _loading ||
        _autoSyncRunning) {
      return false;
    }
    final currentNow = now ?? DateTime.now();
    final lastSyncAt = _lastSyncAt;
    if (lastSyncAt != null &&
        currentNow.difference(lastSyncAt).inMinutes <
            _autoSyncIntervalMinutes) {
      return false;
    }

    _autoSyncRunning = true;
    try {
      await syncAssignments();
      return _error == null;
    } finally {
      _autoSyncRunning = false;
    }
  }

  Future<void> logout() async {
    await sessionStore.clear();
    await repository.clear();
    await reminderRuleStore.clear();
    _authenticated = false;
    _account = null;
    _chaoxingDisplayName = null;
    _chaoxingAvatarUrl = null;
    _shuniZuilingAccount = null;
    _shuniZuilingSchoolCode = null;
    _error = null;
    _assignments.clear();
    _lastSyncAt = null;
    _restartAutoSyncTimer();
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

  Future<void> _syncAssignmentsBody({bool refreshSession = true}) async {
    final incoming = <Assignment>[];
    final failedPrefixes = <String>{};
    final errors = <Object>[];
    final sources = <_AssignmentSyncSource>[];
    if (_account != null) {
      sources.add(
        _AssignmentSyncSource(
          prefix: 'cx:',
          refresh: _refreshChaoxingSession,
          fetch: chaoxingClient.fetchAssignments,
        ),
      );
    }
    final shuniStudentId = _shuniZuilingStudentId;
    if (shuniStudentId != null) {
      sources.add(
        _AssignmentSyncSource(
          prefix: 'snzl:',
          refresh: _refreshShuniZuilingSession,
          fetch: () => shuniZuilingClient.fetchAssignments(
            studentId: shuniStudentId,
          ),
        ),
      );
    }
    for (final source in sources) {
      try {
        if (refreshSession) {
          await source.refresh();
        }
        incoming.addAll(await source.fetch());
      } catch (error) {
        failedPrefixes.add(source.prefix);
        errors.add(error);
      }
    }
    if (incoming.isEmpty && errors.isNotEmpty) {
      throw errors.first;
    }
    if (incoming.isEmpty) {
      throw StateError('没有获取到作业。学习通或数你最灵当前可能没有未完成作业，或学校接口暂时不可用。');
    }
    final mergeInput = <Assignment>[
      ...incoming,
      if (failedPrefixes.isNotEmpty)
        ..._assignments.where(
          (assignment) => failedPrefixes.any(assignment.id.startsWith),
        ),
    ];
    final merged = await repository.mergeAndSave(mergeInput);
    _assignments
      ..clear()
      ..addAll(merged);
    _lastSyncAt = await repository.lastSyncAt();
    await _afterAssignmentsChanged();
    if (errors.isNotEmpty) {
      _error = '部分平台同步失败，已保留未同步平台的旧作业。';
    }
  }

  Future<void> _refreshChaoxingSession() async {
    final account = _account ?? await sessionStore.readChaoxingAccount();
    final password = await sessionStore.readChaoxingPassword();
    if (account == null ||
        account.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      return;
    }
    final result = await chaoxingClient.login(
      account: account,
      password: password,
    );
    if (!result.success) {
      throw StateError(result.message ?? '登录失败');
    }
    _account = account;
    if (result.displayName != null || result.avatarUrl != null) {
      final displayName = result.displayName ??
          _chaoxingDisplayName ??
          await sessionStore.readChaoxingDisplayName();
      final avatarUrl = result.avatarUrl ??
          _chaoxingAvatarUrl ??
          await sessionStore.readChaoxingAvatarUrl();
      await sessionStore.saveChaoxingAccount(
        account: account,
        password: password,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _chaoxingDisplayName = displayName;
      _chaoxingAvatarUrl = avatarUrl;
    }
  }

  Future<void> _refreshShuniZuilingSession() async {
    final account =
        _shuniZuilingAccount ?? await sessionStore.readShuniZuilingAccount();
    final password = await sessionStore.readShuniZuilingPassword();
    final schoolCode = _shuniZuilingSchoolCode ??
        await sessionStore.readShuniZuilingSchoolCode();
    if (account == null ||
        account.trim().isEmpty ||
        password == null ||
        password.isEmpty ||
        schoolCode == null ||
        schoolCode.trim().isEmpty) {
      return;
    }
    final result = await shuniZuilingClient.login(
      schoolUserLocalId: account,
      password: password,
      schoolCode: schoolCode,
    );
    if (!result.success) {
      throw StateError(result.message ?? '数你最灵登录失败');
    }
  }

  String? get _shuniZuilingStudentId {
    final account = _shuniZuilingAccount;
    final schoolCode = _shuniZuilingSchoolCode;
    if (account == null ||
        account.trim().isEmpty ||
        schoolCode == null ||
        schoolCode.trim().isEmpty) {
      return null;
    }
    return '${schoolCode.trim()}-${account.trim()}';
  }

  Future<int> _loadAutoSyncIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeAutoSyncIntervalMinutes(
      prefs.getInt(_autoSyncIntervalKey) ?? defaultAutoSyncIntervalMinutes,
    );
  }

  void _restartAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    if (!_authenticated || _autoSyncIntervalMinutes <= 0) {
      return;
    }
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncIntervalMinutes),
      (_) => unawaited(runDueAutoSync()),
    );
  }

  static int normalizeAutoSyncIntervalMinutes(int minutes) {
    if (minutes <= 0) {
      return 0;
    }
    if (minutes < 1) {
      return 1;
    }
    if (minutes > 1440) {
      return 1440;
    }
    return minutes;
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
      return '暂时没有刷新到作业。如果你确认平台里有未完成作业，请稍后再试。';
    }
    if (raw.contains('登录失败')) {
      return '登录失败，请检查账号和密码。';
    }
    if (raw.contains('同步失败')) {
      return '登录成功，但作业刷新暂时失败。你可以稍后在同步页重新刷新。';
    }
    return raw.isEmpty ? '操作没有完成，请稍后再试。' : raw;
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}

class _AssignmentSyncSource {
  const _AssignmentSyncSource({
    required this.prefix,
    required this.refresh,
    required this.fetch,
  });

  final String prefix;
  final Future<void> Function() refresh;
  final Future<List<Assignment>> Function() fetch;
}
