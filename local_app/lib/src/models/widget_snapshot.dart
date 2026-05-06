class WidgetSnapshotItem {
  WidgetSnapshotItem({
    required this.assignmentId,
    required this.title,
    required this.courseName,
    required this.deadlineAt,
    required this.remainingText,
    required this.urgencyLevel,
    required this.deepLinkUrl,
  });

  final String assignmentId;
  final String title;
  final String courseName;
  final DateTime deadlineAt;
  final String remainingText;
  final String urgencyLevel;
  final String deepLinkUrl;

  factory WidgetSnapshotItem.fromJson(Map<String, dynamic> json) {
    return WidgetSnapshotItem(
      assignmentId: json['assignmentId'] as String,
      title: json['title'] as String,
      courseName: json['courseName'] as String,
      deadlineAt: DateTime.parse(json['deadlineAt'] as String).toLocal(),
      remainingText: json['remainingText'] as String,
      urgencyLevel: json['urgencyLevel'] as String,
      deepLinkUrl: json['deepLinkUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'assignmentId': assignmentId,
        'title': title,
        'courseName': courseName,
        'deadlineAt': deadlineAt.toIso8601String(),
        'remainingText': remainingText,
        'urgencyLevel': urgencyLevel,
        'deepLinkUrl': deepLinkUrl,
      };
}
