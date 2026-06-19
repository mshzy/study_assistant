import 'dart:convert';

import '../models/assignment.dart';

class ShuniZuilingAssignmentParser {
  static List<Assignment> parseJson(
    dynamic payload, {
    Uri? baseUri,
    DateTime? now,
  }) {
    final parsedAt = now ?? DateTime.now();
    final root = _decodePayload(payload);
    if (root == null) {
      return [];
    }

    final items = _collectAssignmentMaps(root);
    final seen = <String>{};
    final assignments = <Assignment>[];
    for (final item in items) {
      final assignment = _assignmentFromMap(
        item,
        baseUri: baseUri,
        now: parsedAt,
      );
      if (assignment != null && seen.add(assignment.id)) {
        assignments.add(assignment);
      }
    }
    return assignments..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
  }

  static List<Assignment> parseHtml(
    String html, {
    Uri? baseUri,
    DateTime? now,
  }) {
    final parsedAt = now ?? DateTime.now();
    final blocks = RegExp(
      r'<(?:div|li|section|article)[^>]*(?:class=["'
      '][^"'
      ']*(?:homework|assignment|task|work|作业)[^"'
      ']*["'
      ']|data-id=["'
      '][^"'
      ']+["'
      ']|data(?:-url)?=["'
      '][^"'
      ']*(?:homework|assignment|task|work)[^"'
      ']*["'
      '])[^>]*>.*?</(?:div|li|section|article)>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html).map((match) => match.group(0)!).toList();

    final candidates = blocks.isEmpty ? <String>[html] : blocks;
    final seen = <String>{};
    final assignments = <Assignment>[];
    for (final block in candidates) {
      final assignment = _assignmentFromHtmlBlock(
        block,
        baseUri: baseUri,
        now: parsedAt,
      );
      if (assignment != null && seen.add(assignment.id)) {
        assignments.add(assignment);
      }
    }
    return assignments..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
  }

  static dynamic _decodePayload(dynamic payload) {
    if (payload is String) {
      final text = payload.trim();
      if (text.isEmpty) {
        return null;
      }
      return jsonDecode(text);
    }
    return payload;
  }

  static List<Map<String, dynamic>> _collectAssignmentMaps(dynamic value) {
    final assignments = <Map<String, dynamic>>[];
    void visit(dynamic node, {String? keyHint}) {
      if (node is List) {
        if (_looksLikeAssignmentList(keyHint, node)) {
          for (final item in node) {
            final map = _asMap(item);
            if (map != null) {
              assignments.add(map);
            }
          }
          return;
        }
        for (final item in node) {
          visit(item, keyHint: keyHint);
        }
        return;
      }
      final map = _asMap(node);
      if (map == null) {
        return;
      }
      final smartestuItems = _smartestuHomeworkItems(map);
      if (smartestuItems.isNotEmpty) {
        assignments.addAll(smartestuItems);
        return;
      }
      if (_looksLikeAssignmentMap(map)) {
        assignments.add(map);
        return;
      }
      for (final entry in map.entries) {
        visit(entry.value, keyHint: entry.key);
      }
    }

    visit(value);
    return assignments;
  }

  static List<Map<String, dynamic>> _smartestuHomeworkItems(
    Map<String, dynamic> map,
  ) {
    final courseName = _firstString(map, const ['courseName']);
    final homeworkList = _firstList(map, const [
      'studentCourseHomeworkDTOList',
      'homeworkList',
    ]);
    if (courseName == null || homeworkList == null) {
      return [];
    }
    return homeworkList
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(
          (homework) => {
            'courseName': courseName,
            'courseId': _firstString(map, const ['courseId']),
            ...homework,
          },
        )
        .toList();
  }

  static bool _looksLikeAssignmentList(String? keyHint, List<dynamic> value) {
    final key = keyHint?.toLowerCase() ?? '';
    if (!RegExp(r'(homework|assignment|task|work|作业)').hasMatch(key)) {
      return false;
    }
    return value.any((item) => _looksLikeAssignmentMap(_asMap(item) ?? {}));
  }

  static bool _looksLikeAssignmentMap(Map<String, dynamic> map) {
    final hasTitle = _firstString(map, const [
          'homeworkName',
          'assignmentName',
          'taskName',
          'workName',
          'title',
          'name',
        ]) !=
        null;
    final hasDeadline = _deadlineFrom(map) != null;
    return hasTitle && hasDeadline;
  }

  static Assignment? _assignmentFromMap(
    Map<String, dynamic> item, {
    required Uri? baseUri,
    required DateTime now,
  }) {
    final title = _firstString(item, const [
      'homeworkName',
      'assignmentName',
      'taskName',
      'workName',
      'title',
      'name',
    ]);
    final deadline = _deadlineFrom(item);
    if (title == null || title.isEmpty || deadline == null) {
      return null;
    }

    final id = _firstString(item, const [
          'homeworkId',
          'assignmentId',
          'taskId',
          'workId',
          'id',
          'bizId',
        ]) ??
        '$title:${deadline.toIso8601String()}';
    final submitUrl = _resolveUrl(
      _firstString(item, const [
        'detailUrl',
        'submitUrl',
        'url',
        'href',
        'link',
      ]),
      baseUri,
    );
    final requirements = _firstString(item, const [
          'description',
          'requirement',
          'requirements',
          'content',
          'remark',
          'notice',
        ]) ??
        _smartestuRequirements(item) ??
        title;

    return Assignment(
      id: 'snzl:$id',
      courseName: _firstString(item, const [
            'courseName',
            'subjectName',
            'className',
            'clazzName',
            'course',
            'subject',
          ]) ??
          '数你最灵',
      title: title,
      deadlineAt: deadline,
      requirementsText: requirements,
      status: _inferStatus(item),
      submitUrl: submitUrl,
      lastSyncedAt: now,
    );
  }

  static Assignment? _assignmentFromHtmlBlock(
    String block, {
    required Uri? baseUri,
    required DateTime now,
  }) {
    final cleanText = _decodeEntities(_stripTags(block))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final deadline = _deadlineFromText(cleanText);
    if (deadline == null) {
      return null;
    }

    final title = _decodeEntities(_stripTags(_firstMatch(block, [
              RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>',
                  caseSensitive: false, dotAll: true),
              RegExp(
                r'class=["'
                '][^"'
                ']*(?:title|name|homework-name|task-name)[^"'
                ']*["'
                '][^>]*>(.*?)</',
                caseSensitive: false,
                dotAll: true,
              ),
              RegExp(r'<a[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true),
            ]) ??
            _fallbackTitle(cleanText)))
        .trim();
    if (title.isEmpty) {
      return null;
    }

    final sourceUrl = _firstMatch(block, [
      RegExp(
        r'<a[^>]+href=["'
        ']([^"'
        ']+)["'
        ']',
        caseSensitive: false,
      ),
      RegExp(
        r'data(?:-url)?=["'
        ']([^"'
        ']+)["'
        ']',
        caseSensitive: false,
      ),
    ]);
    final id = _firstMatch(block, [
          RegExp(
            r'data-id=["'
            ']([^"'
            ']+)["'
            ']',
            caseSensitive: false,
          ),
        ]) ??
        _idFromUrl(sourceUrl) ??
        '$title:${deadline.toIso8601String()}';

    return Assignment(
      id: 'snzl:$id',
      courseName: _extractHtmlCourseName(block) ?? '数你最灵',
      title: title,
      deadlineAt: deadline,
      requirementsText: _extractHtmlRequirement(block, cleanText),
      status: _inferStatusFromText(cleanText),
      submitUrl: _resolveUrl(sourceUrl, baseUri),
      lastSyncedAt: now,
    );
  }

  static DateTime? _deadlineFrom(Map<String, dynamic> item) {
    final raw = _firstString(item, const [
      'deadline',
      'deadlineAt',
      'endTime',
      'endDate',
      'finishTime',
      'dueTime',
      'submitEndTime',
      'expireTime',
    ]);
    if (raw == null || raw.isEmpty || raw == '0') {
      return null;
    }
    return _parseDateTime(raw);
  }

  static DateTime? _deadlineFromText(String text) {
    final absolute = _firstMatch(text, [
      RegExp(
        r'(20\d{2}[-/年]\d{1,2}[-/月]\d{1,2}日?\s+\d{1,2}:\d{2}(?::\d{2})?)',
      ),
    ]);
    return absolute == null ? null : _parseDateTime(absolute);
  }

  static DateTime? _parseDateTime(String raw) {
    final iso = DateTime.tryParse(raw.trim());
    if (iso != null) {
      return iso.toLocal();
    }

    final millis = int.tryParse(raw.trim());
    if (millis != null) {
      final value = millis > 100000000000 ? millis : millis * 1000;
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    final normalized = raw
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', '')
        .replaceAll('/', '-')
        .replaceAll('T', ' ')
        .replaceFirst(RegExp(r'Z$'), '')
        .trim();
    final match = RegExp(
      r'(20\d{2})-(\d{1,2})-(\d{1,2})(?:\s+)(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }
    final local = DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
    );
    return raw.trim().endsWith('Z') ? local.toUtc().toLocal() : local;
  }

  static String _inferStatus(Map<String, dynamic> item) {
    final submissionStatus = _firstString(item, const [
      'submitStatus',
      'submission_status',
    ]);
    if (submissionStatus != null) {
      switch (submissionStatus) {
        case 'not_submitted':
          return 'pending';
        case 'submitted':
        case 'graded':
        case 'completed':
        case 'complete':
          return 'submitted';
      }
      if (RegExp(r'(已提交|已完成|已批改|已批阅|已评价|通过)').hasMatch(submissionStatus)) {
        return 'submitted';
      }
      if (RegExp(r'(未提交|未完成|待完成|未开始)').hasMatch(submissionStatus)) {
        return 'pending';
      }
    }

    final reviewStatus = _firstString(item, const ['review_status']);
    if (reviewStatus == 'reviewed') {
      return 'submitted';
    }

    final text = [
      _firstString(item, const ['statusName', 'stateName', 'statusText']),
      _firstString(item, const [
        'status',
        'state',
      ]),
    ].whereType<String>().join(' ');
    return _inferStatusFromText(text);
  }

  static String _inferStatusFromText(String text) {
    if (RegExp(r'(未提交|未完成|待完成|未开始|not[_\s-]?submitted|incomplete|pending)',
            caseSensitive: false)
        .hasMatch(text)) {
      return 'pending';
    }
    if (RegExp(
            r'(待批阅|待批改|已提交|已完成|已批阅|已批改|已评价|通过|submitted|graded|reviewed|done|complete)',
            caseSensitive: false)
        .hasMatch(text)) {
      return 'submitted';
    }
    return 'pending';
  }

  static String? _extractHtmlCourseName(String block) {
    final named = _firstMatch(block, [
      RegExp(
        r'class=["'
        '][^"'
        ']*(?:course-name|courseName|subject-name|class-name)[^"'
        ']*["'
        '][^>]*>(.*?)</',
        caseSensitive: false,
        dotAll: true,
      ),
    ]);
    return named == null ? null : _decodeEntities(_stripTags(named)).trim();
  }

  static String _extractHtmlRequirement(String block, String cleanText) {
    final desc = _firstMatch(block, [
      RegExp(
        r'class=["'
        '][^"'
        ']*(?:desc|require|content|detail|remark)[^"'
        ']*["'
        '][^>]*>(.*?)</',
        caseSensitive: false,
        dotAll: true,
      ),
    ]);
    return _decodeEntities(_stripTags(desc ?? cleanText)).trim();
  }

  static String _fallbackTitle(String cleanText) {
    return cleanText
        .replaceFirst(RegExp(r'截止(?:时间)?[:：]?\s*20\d{2}.*$'), '')
        .replaceAll(RegExp(r'(未提交|已提交|待批阅|已完成|去完成|查看)'), '')
        .trim();
  }

  static String? _resolveUrl(String? raw, Uri? baseUri) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = _decodeEntities(raw.trim());
    if (baseUri == null) {
      return decoded;
    }
    return baseUri.resolve(decoded).toString();
  }

  static String? _idFromUrl(String? raw) {
    if (raw == null) {
      return null;
    }
    final uri = Uri.tryParse(_decodeEntities(raw));
    if (uri == null) {
      return null;
    }
    for (final key in const [
      'homeworkId',
      'assignmentId',
      'taskId',
      'workId',
      'id',
    ]) {
      final value = uri.queryParameters[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() != key.toLowerCase()) {
          continue;
        }
        final value = entry.value?.toString().trim();
        if (value != null && value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }
    return null;
  }

  static List<dynamic>? _firstList(
      Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() != key.toLowerCase()) {
          continue;
        }
        if (entry.value is List) {
          return entry.value as List<dynamic>;
        }
      }
    }
    return null;
  }

  static String? _smartestuRequirements(Map<String, dynamic> item) {
    final parts = <String>[];
    final teacherName = _firstString(item, const ['teacherName']);
    if (teacherName != null) {
      parts.add('老师：$teacherName');
    }
    final totalScore = _firstString(item, const ['totalScore']);
    if (totalScore != null) {
      parts.add('总分：$totalScore');
    }
    final status = _firstString(item, const ['submission_status']);
    if (status != null) {
      parts.add('提交状态：${_submissionStatusText(status)}');
    }
    final allowLateSubmission =
        _firstString(item, const ['allowLateSubmission']) == 'true';
    final lateRatio = _firstString(item, const ['lateSubmissionScoreRatio']);
    if (allowLateSubmission) {
      parts.add(lateRatio == null ? '允许迟交' : '允许迟交，迟交 $lateRatio%');
    }
    final exerciseStatus = _asMap(item['exercise_status']);
    if (exerciseStatus != null) {
      final total = _firstString(exerciseStatus, const ['total']);
      final submitted = _firstString(exerciseStatus, const ['submitted']);
      final graded = _firstString(exerciseStatus, const ['graded']);
      if (total != null) {
        parts.add(
          '共 $total 题'
          '${submitted == null ? '' : '，已提交 $submitted'}'
          '${graded == null ? '' : '，已批改 $graded'}',
        );
      }
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  static String _submissionStatusText(String status) {
    switch (status) {
      case 'not_submitted':
        return '未提交';
      case 'submitted':
        return '已提交';
      case 'graded':
        return '已批改';
      default:
        return status;
    }
  }

  static String? _firstMatch(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
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

  static String _stripTags(String value) =>
      value.replaceAll(RegExp(r'<[^>]+>'), ' ');

  static String _decodeEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final codePoint = int.tryParse(match.group(1)!, radix: 16);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    }).replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final codePoint = int.tryParse(match.group(1)!);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    });
  }
}
