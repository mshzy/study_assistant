import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/local/chaoxing_api_parser.dart';

void main() {
  test('parses backclazzdata course list', () {
    final courses = ChaoxingApiParser.parseCourseRefs({
      'channelList': [
        {
          'key': 'fallback-class',
          'content': {
            'cpi': 789,
            'clazz': {
              'data': [
                {'id': 222},
              ],
            },
            'course': {
              'data': [
                {'id': 111, 'name': '大学英语'},
              ],
            },
          },
        },
      ],
    });

    expect(courses, hasLength(1));
    expect(courses.first.courseId, '111');
    expect(courses.first.clazzId, '222');
    expect(courses.first.courseName, '大学英语');
    expect(courses.first.cpi, '789');
  });

  test('parses active list homework items into assignments', () {
    final assignments = ChaoxingApiParser.parseActivityAssignments(
      {
        'data': {
          'activeList': [
            {
              'id': 333,
              'nameOne': '章节作业',
              'activeType': 47,
              'status': 1,
              'endTime': '2026-05-07 08:00:00',
            },
            {
              'id': 444,
              'nameOne': '课堂签到',
              'activeType': 2,
              'status': 1,
              'endTime': '2026-05-07 08:00:00',
            },
          ],
        },
      },
      ChaoxingCourseRef(
        courseId: '111',
        clazzId: '222',
        courseName: '大学英语',
        cpi: '789',
      ),
      now: DateTime(2026, 5, 5, 8),
    );

    expect(assignments, hasLength(1));
    expect(assignments.first.id, 'cx:activity:333');
    expect(assignments.first.title, '章节作业');
    expect(assignments.first.courseName, '大学英语');
    expect(assignments.first.deadlineAt, DateTime(2026, 5, 7, 8));
    expect(assignments.first.submitUrl, contains('courseid=111'));
  });

  test(
    'keeps unfinished peer review homework and skips completed peer review homework',
    () {
      final assignments = ChaoxingApiParser.parseActivityAssignments(
        {
          'data': {
            'activeList': [
              {
                'id': 555,
                'nameOne': '互评作业',
                'activeType': 47,
                'status': 2,
                'statusName': '已互评',
                'endTime': '2026-05-07 08:00:00',
              },
              {
                'id': 556,
                'nameOne': '互评作业',
                'activeType': 47,
                'status': 1,
                'statusName': '未完成',
                'endTime': '2026-05-08 08:00:00',
              },
            ],
          },
        },
        ChaoxingCourseRef(
          courseId: '111',
          clazzId: '222',
          courseName: '大学英语',
          cpi: '789',
        ),
        now: DateTime(2026, 5, 5, 8),
      );

      expect(assignments, hasLength(1));
      expect(assignments.first.id, 'cx:activity:556');
    },
  );
}
