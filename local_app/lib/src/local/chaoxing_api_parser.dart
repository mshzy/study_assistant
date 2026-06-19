import '../models/assignment.dart';

class ChaoxingCourseRef {
  const ChaoxingCourseRef({
    required this.courseId,
    required this.clazzId,
    required this.courseName,
    this.cpi,
  });

  final String courseId;
  final String clazzId;
  final String courseName;
  final String? cpi;
}

class ChaoxingApiParser {
  static List<ChaoxingCourseRef> parseCourseRefs(dynamic payload) {
    final roots = _asMap(payload);
    if (roots == null) {
      return [];
    }

    final channels = _asList(roots['channelList']) ??
        _asList(roots['data']) ??
        _asList(roots['courses']) ??
        const [];
    final courses = <ChaoxingCourseRef>[];
    for (final item in channels) {
      final channel = _asMap(item);
      if (channel == null) {
        continue;
      }
      final content = _asMap(channel['content']) ?? channel;
      final courseData = _firstMapFrom(content['course']) ??
          _asMap(content['course']) ??
          content;
      final clazzData = _firstMapFrom(content['clazz']) ??
          _asMap(content['clazz']) ??
          content;

      final courseId = _stringValue(
        courseData['id'] ?? content['courseId'] ?? content['courseid'],
      );
      final clazzId = _stringValue(
        clazzData['id'] ??
            channel['key'] ??
            content['clazzId'] ??
            content['clazzid'],
      );
      final courseName = _stringValue(
        courseData['name'] ??
            courseData['courseName'] ??
            content['name'] ??
            content['courseName'] ??
            channel['name'],
      );
      if (courseId == null ||
          clazzId == null ||
          courseName == null ||
          courseName.isEmpty) {
        continue;
      }

      courses.add(
        ChaoxingCourseRef(
          courseId: courseId,
          clazzId: clazzId,
          courseName: courseName,
          cpi: _stringValue(content['cpi'] ?? channel['cpi']),
        ),
      );
    }
    return courses;
  }

  static List<Assignment> parseActivityAssignments(
    dynamic payload,
    ChaoxingCourseRef course, {
    DateTime? now,
  }) {
    final parsedAt = now ?? DateTime.now();
    final root = _asMap(payload);
    if (root == null) {
      return [];
    }

    final data = _asMap(root['data']) ?? root;
    final activities = _asList(data['activeList']) ??
        _asList(data['list']) ??
        _asList(data['activities']) ??
        const [];
    final assignments = <Assignment>[];
    for (final item in activities) {
      final activity = _asMap(item);
      if (activity == null || !_looksLikeHomework(activity)) {
        continue;
      }
      final id = _stringValue(
        activity['id'] ?? activity['activeId'] ?? activity['aid'],
      );
      final title = _stringValue(
        activity['nameOne'] ??
            activity['name'] ??
            activity['title'] ??
            activity['activeName'],
      );
      if (_isCompletedPeerReview(activity, title ?? '')) {
        continue;
      }
      final deadline = _deadlineFrom(activity);
      if (id == null || title == null || title.isEmpty || deadline == null) {
        continue;
      }

      assignments.add(
        Assignment(
          id: 'cx:activity:$id',
          courseName: course.courseName,
          title: title,
          deadlineAt: deadline,
          requirementsText: _stringValue(
                activity['description'] ??
                    activity['content'] ??
                    activity['remark'],
              ) ??
              title,
          status: Assignment.statusFromChaoxing(
            _stringValue(activity['statusName'] ?? activity['stateName']),
            _stringValue(activity['status'] ?? activity['state']),
          ),
          submitUrl: _activityUrl(course, id),
          lastSyncedAt: parsedAt,
        ),
      );
    }
    return assignments;
  }

  // ---------- Exam parsing ----------

  static List<Assignment> parseActivityExamAssignments(
    dynamic payload,
    ChaoxingCourseRef course, {
    DateTime? now,
  }) {
    final parsedAt = now ?? DateTime.now();
    final root = _asMap(payload);
    if (root == null) {
      return [];
    }

    final data = _asMap(root['data']) ?? root;
    final activities = _asList(data['activeList']) ??
        _asList(data['list']) ??
        _asList(data['activities']) ??
        const [];
    final assignments = <Assignment>[];
    for (final item in activities) {
      final activity = _asMap(item);
      if (activity == null || !_looksLikeExam(activity)) {
        continue;
      }
      final id = _stringValue(
        activity['id'] ?? activity['activeId'] ?? activity['aid'],
      );
      final title = _stringValue(
        activity['nameOne'] ??
            activity['name'] ??
            activity['title'] ??
            activity['activeName'],
      );
      final examDate = _examTimeFrom(activity);
      if (id == null || title == null || title.isEmpty || examDate == null) {
        continue;
      }
      // Skip exams that are more than 30 days in the past
      if (examDate.isBefore(parsedAt.subtract(const Duration(days: 30)))) {
        continue;
      }

      final location = _stringValue(
        activity['location'] ??
            activity['address'] ??
            activity['place'] ??
            activity['examPlace'],
      );

      final durationStr = _stringValue(
        activity['duration'] ??
            activity['examDuration'] ??
            activity['timeLong'],
      );
      final durationMinutes =
          durationStr != null ? int.tryParse(durationStr) : null;

      final completed = examDate.isBefore(parsedAt);

      assignments.add(
        Assignment(
          id: 'cx:exam:$id',
          courseName: course.courseName,
          title: title,
          deadlineAt: examDate,
          requirementsText: _examRequirementsText(
            title: title,
            location: location,
            durationMinutes: durationMinutes,
            notes: _stringValue(activity['remark'] ?? activity['description']),
          ),
          status: completed ? 'completed' : 'pending',
          submitUrl: _activityUrl(course, id),
          completedAt: completed ? examDate : null,
          lastSyncedAt: parsedAt,
        ),
      );
    }
    return assignments;
  }

  static bool _looksLikeExam(Map<String, dynamic> activity) {
    final type = _stringValue(
      activity['activeType'] ?? activity['type'] ?? activity['activeTypeName'],
    );
    final name = _stringValue(
          activity['nameOne'] ??
              activity['name'] ??
              activity['title'] ??
              activity['activeName'],
        ) ??
        '';
    // Exam activity types in Chaoxing: 49 is typically exam
    if (name.contains('考试') ||
        name.contains('考核') ||
        name.contains('期末') ||
        name.contains('期中') ||
        name.toLowerCase().contains('exam')) {
      return true;
    }
    // Activity type 49 is exam, 50 is some variants
    return const {'49', '50'}.contains(type);
  }

  // ---------- Shared ----------

  static bool _looksLikeHomework(Map<String, dynamic> activity) {
    final type = _stringValue(
      activity['activeType'] ?? activity['type'] ?? activity['activeTypeName'],
    );
    final name = _stringValue(
          activity['nameOne'] ??
              activity['name'] ??
              activity['title'] ??
              activity['activeName'],
        ) ??
        '';
    // Don't classify exam-type activities as homework
    if (_looksLikeExam(activity)) {
      return false;
    }
    if (name.contains('作业') ||
        name.contains('测验') ||
        name.toLowerCase().contains('homework')) {
      return true;
    }
    return const {'6', '42', '43', '44', '45', '46', '47'}.contains(type);
  }

  static bool _isCompletedPeerReview(
    Map<String, dynamic> activity,
    String title,
  ) {
    final combined = [
      title,
      _stringValue(activity['description']),
      _stringValue(activity['content']),
      _stringValue(activity['remark']),
      _stringValue(activity['statusName']),
      _stringValue(activity['stateName']),
      _stringValue(activity['statusText']),
    ].whereType<String>().join(' ');
    if (!combined.contains('互评')) {
      return false;
    }
    if (RegExp(r'(未完成|未提交|待互评|待评价|进行中)').hasMatch(combined)) {
      return false;
    }
    if (RegExp(r'(已互评|已完成|已提交|已评价|评价完成|互评完成)').hasMatch(combined)) {
      return true;
    }
    final status = _stringValue(
      activity['status'] ?? activity['state'] ?? activity['completeStatus'],
    );
    return const {
      '2',
      '3',
      '4',
      'finished',
      'done',
      'complete',
      'completed',
    }.contains(status?.toLowerCase());
  }

  static DateTime? _deadlineFrom(Map<String, dynamic> activity) {
    final raw = _stringValue(
      activity['endTime'] ??
          activity['deadline'] ??
          activity['deadlineAt'] ??
          activity['endtime'] ??
          activity['endTimeStr'] ??
          activity['endDate'],
    );
    if (raw == null || raw.isEmpty || raw == '0') {
      return null;
    }

    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return iso.toLocal();
    }

    final millis = int.tryParse(raw);
    if (millis != null) {
      final value = millis > 100000000000 ? millis : millis * 1000;
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    final normalized = raw
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', '')
        .replaceAll('/', '-')
        .trim();
    final match = RegExp(
      r'(20\d{2})-(\d{1,2})-(\d{1,2})(?:\s+|T)(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
    );
  }

  static DateTime? _examTimeFrom(Map<String, dynamic> activity) {
    final examSpecific = _stringValue(
      activity['examTime'] ??
          activity['examStartTime'] ??
          activity['startTime'] ??
          activity['beginTime'] ??
          activity['startDate'],
    );
    if (examSpecific != null &&
        examSpecific.isNotEmpty &&
        examSpecific != '0') {
      return _parseDateTime(examSpecific);
    }
    return _deadlineFrom(activity);
  }

  static DateTime? _parseDateTime(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return iso.toLocal();
    }
    final millis = int.tryParse(raw);
    if (millis != null) {
      final value = millis > 100000000000 ? millis : millis * 1000;
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    final normalized = raw
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', '')
        .replaceAll('/', '-')
        .trim();
    final match = RegExp(
      r'(20\d{2})-(\d{1,2})-(\d{1,2})(?:\s+|T)(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
    );
  }

  static String _activityUrl(ChaoxingCourseRef course, String activeId) {
    return Uri.https('mobilelearn.chaoxing.com', '/widget/pcpick/stu/index', {
      'courseid': course.courseId,
      'jclassId': course.clazzId,
      'activeId': activeId,
      if (course.cpi != null) 'cpi': course.cpi!,
    }).toString();
  }

  static String _examRequirementsText({
    required String title,
    String? location,
    int? durationMinutes,
    String? notes,
  }) {
    final parts = <String>[
      '考试：$title',
      if (location != null && location.isNotEmpty) '地点：$location',
      if (durationMinutes != null) '时长：$durationMinutes 分钟',
      if (notes != null && notes.isNotEmpty) notes,
    ];
    return parts.join('\n');
  }

  static Map<String, dynamic>? _firstMapFrom(dynamic value) {
    final map = _asMap(value);
    if (map != null) {
      final data = _asList(map['data']);
      if (data != null && data.isNotEmpty) {
        return _asMap(data.first);
      }
      return map;
    }
    final list = _asList(value);
    if (list != null && list.isNotEmpty) {
      return _asMap(list.first);
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static List<dynamic>? _asList(dynamic value) => value is List ? value : null;

  static String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
