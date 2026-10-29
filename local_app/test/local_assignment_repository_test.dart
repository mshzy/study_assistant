import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_assistant_mobile/src/local/local_assignment_repository.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';

void main() {
  test('loadAssignments clears malformed assignment cache', () async {
    SharedPreferences.setMockInitialValues({
      'local_assignments': '{broken json',
      'local_last_sync_at': '2026-05-05T11:00:00.000Z',
    });
    final repository = LocalAssignmentRepository();

    expect(await repository.loadAssignments(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('local_assignments'), isNull);
    expect(await repository.lastSyncAt(), isNull);
  });

  test('loadAssignments clears assignment cache with legacy schema', () async {
    SharedPreferences.setMockInitialValues({
      'local_assignments': '[{"id":"legacy-work"}]',
      'local_last_sync_at': '2026-05-05T11:00:00.000Z',
    });
    final repository = LocalAssignmentRepository();

    expect(await repository.loadAssignments(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('local_assignments'), isNull);
    expect(await repository.lastSyncAt(), isNull);
  });

  test(
    'mergeAssignments keeps previously completed status when refreshed',
    () {
      final existing = Assignment(
        id: 'web:course-1:work-1',
        courseName: '软件工程',
        title: '需求分析报告',
        deadlineAt: DateTime.parse('2026-05-08T10:00:00.000Z'),
        requirementsText: '提交 PDF',
        status: 'completed',
        completedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        lastSyncedAt: DateTime.parse('2026-05-05T09:00:00.000Z'),
      );
      final incoming = Assignment(
        id: 'web:course-1:work-1',
        courseName: '软件工程',
        title: '需求分析报告（更新）',
        deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
        requirementsText: '提交 PDF 和截图',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
      );

      final merged = LocalAssignmentRepository.mergeAssignments(
        [existing],
        [incoming],
      );

      expect(merged, hasLength(1));
      expect(merged.single.id, existing.id);
      expect(merged.single.status, 'completed');
      expect(merged.single.title, existing.title);
    },
  );

  test('mergeAssignments skips assignments hidden by manual completion', () {
    final incoming = Assignment(
      id: 'web:course-1:work-1',
      courseName: '软件工程',
      title: '需求分析报告',
      deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
      requirementsText: '提交 PDF',
      status: 'pending',
      lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
    );

    final merged = LocalAssignmentRepository.mergeAssignments(
      [],
      [incoming],
      hiddenCompletedIds: {'web:course-1:work-1'},
    );

    expect(merged, isEmpty);
  });

  test('manual completion marker does not hide remote completed history', () {
    final submitted = Assignment(
      id: 'web:course-1:work-1',
      courseName: '软件工程',
      title: '需求分析报告',
      deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
      requirementsText: '提交 PDF',
      status: 'submitted',
      lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
    );

    final merged = LocalAssignmentRepository.mergeAssignments(
      [],
      [submitted],
      hiddenCompletedIds: {'web:course-1:work-1'},
    );

    expect(merged, hasLength(1));
    expect(merged.single.isCompleted, isTrue);
  });

  test('mergeAndSave retains review items as completed statistics', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalAssignmentRepository();
    final reviewing = Assignment(
      id: 'cx:activity:reviewing',
      courseName: '大学英语',
      title: '章节作业',
      deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
      requirementsText: '完成后提交',
      status: 'submitted',
      lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
    );

    final afterSync = await repository.mergeAndSave([reviewing]);
    final afterReload = await repository.loadAssignments();

    expect(afterSync, hasLength(1));
    expect(afterSync.single.isCompleted, isTrue);
    expect(afterReload, hasLength(1));
    expect(afterReload.single.isCompleted, isTrue);
  });

  test(
    'mergeAssignments keeps unfinished peer review and filters completed peer review',
    () {
      final oldPeerReview = Assignment(
        id: 'cx:stu-work:peer-review',
        courseName: '大学英语',
        title: '互评作业',
        deadlineAt: DateTime.parse('2026-05-08T10:00:00.000Z'),
        requirementsText: '互评作业 已完成',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T09:00:00.000Z'),
      );
      final incoming = Assignment(
        id: 'cx:stu-work:normal',
        courseName: '大学英语',
        title: '章节作业',
        deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
        requirementsText: '提交 PDF',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
      );
      final incomingPeerReview = Assignment(
        id: 'cx:stu-work:new-peer-review',
        courseName: '大学英语',
        title: '互评作业',
        deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
        requirementsText: '互评作业 未完成',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
      );

      final merged = LocalAssignmentRepository.mergeAssignments(
        [oldPeerReview],
        [incoming, incomingPeerReview],
      );

      expect(merged.map((item) => item.id), [
        'cx:stu-work:normal',
        'cx:stu-work:new-peer-review',
      ]);
    },
  );

  test(
    'mergeAssignments drops old pending assignments that are missing from the latest sync',
    () {
      final oldPeerReview = Assignment(
        id: 'cx:stu-work:old-peer-review',
        courseName: '大学英语',
        title: '互评作业',
        deadlineAt: DateTime.parse('2026-05-08T10:00:00.000Z'),
        requirementsText: '互评作业',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T09:00:00.000Z'),
      );
      final incoming = Assignment(
        id: 'cx:stu-work:new-work',
        courseName: '大学英语',
        title: '章节作业',
        deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
        requirementsText: '提交 PDF',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
      );

      final merged = LocalAssignmentRepository.mergeAssignments(
        [oldPeerReview],
        [incoming],
      );

      expect(merged.map((item) => item.id), ['cx:stu-work:new-work']);
    },
  );

  test(
    'mergeAssignments filters completed peer review from latest sync result',
    () {
      final completedPeerReview = Assignment(
        id: 'cx:stu-work:completed-peer-review',
        courseName: '大学英语',
        title: '互评作业',
        deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
        requirementsText: '互评作业 已互评',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
      );

      final merged = LocalAssignmentRepository.mergeAssignments([], [
        completedPeerReview,
      ]);

      expect(merged, isEmpty);
    },
  );

  test('updateCompletion preserves completed status across later syncs',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalAssignmentRepository();
    final assignment = Assignment(
      id: 'cx:stu-work:work-1',
      courseName: '大学英语',
      title: '章节作业',
      deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
      requirementsText: '提交 PDF',
      status: 'pending',
      lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
    );

    await repository.mergeAndSave([assignment]);
    final afterComplete = await repository.updateCompletion(
      assignment.id,
      true,
    );
    final afterRefresh = await repository.mergeAndSave([
      assignment.copyWith(
        lastSyncedAt: DateTime.parse('2026-05-05T12:00:00.000Z'),
      ),
    ]);

    expect(afterComplete, hasLength(1));
    expect(afterComplete.single.isCompleted, isTrue);
    expect(afterRefresh, hasLength(1));
    expect(afterRefresh.single.isCompleted, isTrue);
    final reloaded = await repository.loadAssignments();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.isCompleted, isTrue);
  });
}
