import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment.dart';

class LocalAssignmentRepository {
  static const _assignmentsKey = 'local_assignments';
  static const _lastSyncKey = 'local_last_sync_at';
  static const _completedIdsKey = 'local_hidden_completed_assignment_ids';

  Future<List<Assignment>> loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assignmentsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final data = jsonDecode(raw) as List<dynamic>;
    final assignments = data
        .map((item) => Assignment.fromJson(item as Map<String, dynamic>))
        .toList();
    await _migrateCompletedAssignments(prefs, assignments);
    final hiddenCompletedIds = _loadCompletedIds(prefs);
    return assignments
        .where(
          (assignment) =>
              !assignment.isCompleted &&
              !hiddenCompletedIds.contains(assignment.id) &&
              !_isCompletedPeerReview(assignment),
        )
        .toList();
  }

  Future<List<Assignment>> mergeAndSave(List<Assignment> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAssignments();
    final hiddenCompletedIds = _loadCompletedIds(prefs);
    final merged = mergeAssignments(
      existing,
      incoming,
      hiddenCompletedIds: hiddenCompletedIds,
    );
    await prefs.setString(
      _assignmentsKey,
      jsonEncode(merged.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    return merged;
  }

  Future<List<Assignment>> updateCompletion(
    String assignmentId,
    bool completed,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenCompletedIds = _loadCompletedIds(prefs);
    if (completed) {
      hiddenCompletedIds.add(assignmentId);
    } else {
      hiddenCompletedIds.remove(assignmentId);
    }
    await _saveCompletedIds(prefs, hiddenCompletedIds);

    final assignments = await loadAssignments();
    final updated = completed
        ? assignments
              .where((assignment) => assignment.id != assignmentId)
              .toList()
        : assignments
              .map(
                (assignment) => assignment.id == assignmentId
                    ? assignment.copyWith(
                        status: _statusFor(assignment.deadlineAt),
                        clearCompletedAt: true,
                      )
                    : assignment,
              )
              .toList();
    await prefs.setString(
      _assignmentsKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    return updated;
  }

  Future<DateTime?> lastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_assignmentsKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_completedIdsKey);
  }

  static List<Assignment> mergeAssignments(
    List<Assignment> existing,
    List<Assignment> incoming, {
    Set<String> hiddenCompletedIds = const {},
  }) {
    final effectiveHiddenCompletedIds = {
      ...hiddenCompletedIds,
      for (final assignment in existing.where((item) => item.isCompleted))
        assignment.id,
    };
    final byId = <String, Assignment>{};
    for (final assignment in incoming) {
      if (effectiveHiddenCompletedIds.contains(assignment.id) ||
          _isCompletedPeerReview(assignment)) {
        continue;
      }
      byId[assignment.id] = assignment.copyWith(
        status: _statusFor(assignment.deadlineAt),
        clearCompletedAt: true,
      );
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
    return merged;
  }

  static Set<String> _loadCompletedIds(SharedPreferences prefs) {
    return (prefs.getStringList(_completedIdsKey) ?? const <String>[])
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static Future<void> _saveCompletedIds(
    SharedPreferences prefs,
    Set<String> ids,
  ) {
    final sorted = ids.toList()..sort();
    return prefs.setStringList(_completedIdsKey, sorted);
  }

  static Future<void> _migrateCompletedAssignments(
    SharedPreferences prefs,
    List<Assignment> assignments,
  ) async {
    final completedIds = assignments
        .where((assignment) => assignment.isCompleted)
        .map((assignment) => assignment.id)
        .toSet();
    if (completedIds.isEmpty) {
      return;
    }
    final hiddenCompletedIds = _loadCompletedIds(prefs)..addAll(completedIds);
    await _saveCompletedIds(prefs, hiddenCompletedIds);
  }

  static String _statusFor(DateTime deadlineAt) {
    return deadlineAt.isBefore(DateTime.now()) ? 'overdue' : 'pending';
  }

  static bool _isCompletedPeerReview(Assignment assignment) {
    final text =
        '${assignment.title} ${assignment.requirementsText} ${assignment.status}';
    if (!text.contains('互评')) {
      return false;
    }
    if (RegExp(r'(未完成|未提交|待互评|待评价|进行中)').hasMatch(text)) {
      return false;
    }
    return RegExp(r'(已互评|已完成|已提交|已评价|评价完成|互评完成|completed)').hasMatch(text);
  }
}
