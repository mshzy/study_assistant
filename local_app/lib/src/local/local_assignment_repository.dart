import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assignment.dart';

class LocalAssignmentRepository {
  static const _assignmentsKey = 'local_assignments';
  static const _lastSyncKey = 'local_last_sync_at';

  Future<List<Assignment>> loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assignmentsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((item) => Assignment.fromJson(item as Map<String, dynamic>))
        .where((assignment) => !_isCompletedPeerReview(assignment))
        .toList();
  }

  Future<List<Assignment>> mergeAndSave(List<Assignment> incoming) async {
    final existing = await loadAssignments();
    final merged = mergeAssignments(existing, incoming);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assignmentsKey,
        jsonEncode(merged.map((item) => item.toJson()).toList()));
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    return merged;
  }

  Future<List<Assignment>> updateCompletion(
      String assignmentId, bool completed) async {
    final assignments = await loadAssignments();
    final updated = assignments
        .map((assignment) => assignment.id == assignmentId
            ? assignment.copyWith(
                status:
                    completed ? 'completed' : _statusFor(assignment.deadlineAt),
                completedAt: completed ? DateTime.now() : null,
                clearCompletedAt: !completed,
              )
            : assignment)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assignmentsKey,
        jsonEncode(updated.map((item) => item.toJson()).toList()));
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
  }

  static List<Assignment> mergeAssignments(
      List<Assignment> existing, List<Assignment> incoming) {
    final oldById = {
      for (final assignment in existing
          .where((assignment) => !_isCompletedPeerReview(assignment)))
        assignment.id: assignment,
    };
    final byId = <String, Assignment>{};
    for (final assignment in incoming) {
      if (_isCompletedPeerReview(assignment)) {
        continue;
      }
      final old = oldById[assignment.id];
      byId[assignment.id] = old?.isCompleted == true
          ? assignment.copyWith(
              status: 'completed', completedAt: old!.completedAt)
          : assignment.copyWith(status: _statusFor(assignment.deadlineAt));
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
    return merged;
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
    return RegExp(r'(已完成|已提交|已评价|评价完成|互评完成|completed)').hasMatch(text);
  }
}
