class Assignment {
  Assignment({
    required this.id,
    required this.courseName,
    required this.title,
    required this.deadlineAt,
    required this.requirementsText,
    required this.status,
    required this.lastSyncedAt,
    this.submitUrl,
    this.completedAt,
  });

  final String id;
  final String courseName;
  final String title;
  final DateTime deadlineAt;
  final String requirementsText;
  final String status;
  final String? submitUrl;
  final DateTime? completedAt;
  final DateTime lastSyncedAt;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      courseName: json['courseName'] as String,
      title: json['title'] as String,
      deadlineAt: DateTime.parse(json['deadlineAt'] as String).toLocal(),
      requirementsText: json['requirementsText'] as String,
      status: json['status'] as String,
      submitUrl: json['submitUrl'] as String?,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String).toLocal(),
      lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'title': title,
        'deadlineAt': deadlineAt.toIso8601String(),
        'requirementsText': requirementsText,
        'status': status,
        'submitUrl': submitUrl,
        'completedAt': completedAt?.toIso8601String(),
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
      };

  Assignment copyWith({
    String? id,
    String? courseName,
    String? title,
    DateTime? deadlineAt,
    String? requirementsText,
    String? status,
    String? submitUrl,
    DateTime? completedAt,
    DateTime? lastSyncedAt,
    bool clearCompletedAt = false,
  }) {
    return Assignment(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      title: title ?? this.title,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      requirementsText: requirementsText ?? this.requirementsText,
      status: status ?? this.status,
      submitUrl: submitUrl ?? this.submitUrl,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isOverdue => status == 'overdue';
}
