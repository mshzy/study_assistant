import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/local/shuni_zuiling_assignment_parser.dart';

void main() {
  test('parses Shuni Zuiling JSON homework into assignments', () {
    final assignments = ShuniZuilingAssignmentParser.parseJson(
      {
        'data': {
          'homeworkList': [
            {
              'homeworkId': 987,
              'homeworkName': '高等数学第 6 次作业',
              'courseName': '高等数学 A',
              'deadline': '2026-05-28 22:00:00',
              'description': '完成极限与连续题目并拍照提交',
              'statusName': '未提交',
              'detailUrl': '/student/homework/987',
            },
          ],
        },
      },
      baseUri: Uri.parse('https://snzl.example.edu'),
      now: DateTime(2026, 5, 25, 12),
    );

    expect(assignments, hasLength(1));
    expect(assignments.first.id, 'snzl:987');
    expect(assignments.first.courseName, '高等数学 A');
    expect(assignments.first.title, '高等数学第 6 次作业');
    expect(assignments.first.deadlineAt, DateTime(2026, 5, 28, 22));
    expect(assignments.first.requirementsText, contains('拍照提交'));
    expect(assignments.first.status, 'pending');
    expect(
      assignments.first.submitUrl,
      'https://snzl.example.edu/student/homework/987',
    );
  });

  test('parses Shuni Zuiling HTML homework cards', () {
    const html = '''
      <section class="homework-card" data-id="math-8">
        <h3>数你最灵线性代数作业</h3>
        <span class="course-name">线性代数</span>
        <span>截止时间：2026年05月29日 18:30</span>
        <a href="/student/tasks/math-8">去完成</a>
        <p class="desc">矩阵分解专题练习</p>
      </section>
    ''';

    final assignments = ShuniZuilingAssignmentParser.parseHtml(
      html,
      baseUri: Uri.parse('https://snzl.example.edu'),
      now: DateTime(2026, 5, 25, 12),
    );

    expect(assignments, hasLength(1));
    expect(assignments.first.id, 'snzl:math-8');
    expect(assignments.first.courseName, '线性代数');
    expect(assignments.first.title, '数你最灵线性代数作业');
    expect(assignments.first.deadlineAt, DateTime(2026, 5, 29, 18, 30));
    expect(assignments.first.requirementsText, contains('矩阵分解'));
  });

  test('marks submitted Shuni Zuiling homework as completed assignment state', () {
    final assignments = ShuniZuilingAssignmentParser.parseJson(
      {
        'list': [
          {
            'id': 'done-1',
            'title': '已交作业',
            'courseName': '数学分析',
            'endTime': '2026-05-27 10:00:00',
            'submitStatus': '已提交',
          },
        ],
      },
      now: DateTime(2026, 5, 25, 12),
    );

    expect(assignments, hasLength(1));
    expect(assignments.first.status, 'submitted');
    expect(assignments.first.isCompleted, isTrue);
  });

  test('parses smartestu course homework response', () {
    final assignments = ShuniZuilingAssignmentParser.parseJson(
      {
        'code': 200,
        'msg': '成功',
        'data': {
          'courseHomeworkDTOList': [
            {
              'courseId': 1485,
              'courseName': '高等数学',
              'studentCourseHomeworkDTOList': [
                {
                  'id': 24738,
                  'name': '第 6 次作业',
                  'teacherName': '王老师',
                  'endTime': '2026-06-01T15:59:10.900Z',
                  'totalScore': 100,
                  'submission_status': 'not_submitted',
                  'review_status': 'not_reviewed',
                  'allowLateSubmission': true,
                  'lateSubmissionScoreRatio': 80,
                  'exercise_status': {
                    'total': 8,
                    'submitted': 0,
                    'graded': 0,
                  },
                },
              ],
            },
          ],
        },
      },
      now: DateTime(2026, 5, 25, 12),
    );

    expect(assignments, hasLength(1));
    expect(assignments.first.id, 'snzl:24738');
    expect(assignments.first.courseName, '高等数学');
    expect(assignments.first.title, '第 6 次作业');
    expect(assignments.first.deadlineAt, DateTime(2026, 6, 1, 23, 59, 10, 900));
    expect(assignments.first.requirementsText, contains('王老师'));
    expect(assignments.first.requirementsText, contains('共 8 题'));
    expect(assignments.first.requirementsText, contains('迟交 80%'));
    expect(assignments.first.status, 'pending');
  });

  test('treats submitted smartestu homework as completed', () {
    final assignments = ShuniZuilingAssignmentParser.parseJson(
      {
        'data': {
          'courseHomeworkDTOList': [
            {
              'courseName': '线性代数',
              'studentCourseHomeworkDTOList': [
                {
                  'id': 24739,
                  'name': '已交作业',
                  'endTime': '2026-06-01T15:59:10.900Z',
                  'submission_status': 'submitted',
                  'review_status': 'not_reviewed',
                },
              ],
            },
          ],
        },
      },
      now: DateTime(2026, 5, 25, 12),
    );

    expect(assignments.single.status, 'submitted');
    expect(assignments.single.isCompleted, isTrue);
  });

  test('treats completed smartestu homework as completed', () {
    final assignments = ShuniZuilingAssignmentParser.parseJson(
      {
        'data': {
          'courseHomeworkDTOList': [
            {
              'courseName': '高等数学',
              'studentCourseHomeworkDTOList': [
                {
                  'id': 24740,
                  'name': '完成状态作业',
                  'endTime': '2026-06-01T15:59:10.900Z',
                  'submission_status': 'completed',
                  'review_status': 'not_reviewed',
                },
              ],
            },
          ],
        },
      },
      now: DateTime(2026, 5, 25, 12),
    );

    expect(assignments.single.status, 'submitted');
    expect(assignments.single.isCompleted, isTrue);
  });
}
