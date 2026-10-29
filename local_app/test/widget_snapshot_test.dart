import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/models/widget_snapshot.dart';

void main() {
  test('widget deadline is an unambiguous instant for native parsers', () {
    final deadline = DateTime(2026, 10, 28, 20, 30);
    final item = WidgetSnapshotItem(
      assignmentId: 'cx:1',
      title: '作业',
      courseName: '课程',
      deadlineAt: deadline,
      remainingText: '1小时',
      urgencyLevel: 'soon',
      deepLinkUrl: 'studyassistant:///assignments/cx%3A1',
    );

    final json = item.toJson();
    final encodedDeadline = json['deadlineAt'] as String;

    expect(encodedDeadline, endsWith('Z'));
    expect(DateTime.parse(encodedDeadline).isAtSameMomentAs(deadline), isTrue);
    expect(
      WidgetSnapshotItem.fromJson(json).deadlineAt.isAtSameMomentAs(deadline),
      isTrue,
    );
  });
}
