import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/local/local_assignment_repository.dart';
import 'package:study_assistant_mobile/src/models/assignment.dart';

void main() {
  test('mergeAssignments keeps completion state when remote assignment changes',
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

    final merged =
        LocalAssignmentRepository.mergeAssignments([existing], [incoming]);

    expect(merged, hasLength(1));
    expect(merged.first.title, '需求分析报告（更新）');
    expect(merged.first.status, 'completed');
    expect(merged.first.completedAt, existing.completedAt);
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
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'));
    final incomingPeerReview = Assignment(
        id: 'cx:stu-work:new-peer-review',
        courseName: '大学英语',
        title: '互评作业',
        deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
        requirementsText: '互评作业 未完成',
        status: 'pending',
        lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'));

    final merged = LocalAssignmentRepository.mergeAssignments(
        [oldPeerReview], [incoming, incomingPeerReview]);

    expect(merged.map((item) => item.id),
        ['cx:stu-work:normal', 'cx:stu-work:new-peer-review']);
  });

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

    final merged =
        LocalAssignmentRepository.mergeAssignments([oldPeerReview], [incoming]);

    expect(merged.map((item) => item.id), ['cx:stu-work:new-work']);
  });

  test('mergeAssignments filters completed peer review from latest sync result',
      () {
    final completedPeerReview = Assignment(
      id: 'cx:stu-work:completed-peer-review',
      courseName: '大学英语',
      title: '互评作业',
      deadlineAt: DateTime.parse('2026-05-09T10:00:00.000Z'),
      requirementsText: '互评作业 已完成',
      status: 'pending',
      lastSyncedAt: DateTime.parse('2026-05-05T11:00:00.000Z'),
    );

    final merged =
        LocalAssignmentRepository.mergeAssignments([], [completedPeerReview]);

    expect(merged, isEmpty);
  });
}
