import '../models/assignment.dart';

class ChaoxingAssignmentParser {
  static List<Assignment> parseWorkHtml(
    String html, {
    required String fallbackCourseName,
    required String sourcePrefix,
    required Uri baseUri,
    DateTime? now,
  }) {
    final parsedAt = now ?? DateTime.now();
    final courseName = _firstMatch(html, [
          RegExp(
            r'class=["'
            '][^"'
            ']*course-name[^"'
            ']*["'
            '][^>]*>([^<]+)',
            caseSensitive: false,
          ),
          RegExp(
            r'class=["'
            '][^"'
            ']*courseName[^"'
            ']*["'
            '][^>]*>([^<]+)',
            caseSensitive: false,
          ),
          RegExp(r'课程[:：]\s*([^<\n\r]+)'),
        ])?.trim() ??
        fallbackCourseName;

    final itemRegex = RegExp(
      r'<(?:div|li)[^>]*(?:class=["'
      '][^"'
      ']*(?:work|homework|task|作业)[^"'
      ']*["'
      ']|data-id=["'
      '][^"'
      ']+["'
      ']|data(?:-url)?=["'
      '][^"'
      ']*(?:doHomeWork|taskrefId|workId|/work/)[^"'
      ']*["'
      '])[^>]*>.*?</(?:div|li)>',
      caseSensitive: false,
      dotAll: true,
    );
    final blocks =
        itemRegex.allMatches(html).map((match) => match.group(0)!).toList();
    final candidates = blocks.isEmpty ? <String>[html] : blocks;

    final seen = <String>{};
    final assignments = <Assignment>[];
    for (final block in candidates) {
      final assignment = _parseBlock(
        block,
        courseName: courseName,
        sourcePrefix: sourcePrefix,
        baseUri: baseUri,
        now: parsedAt,
      );
      if (assignment != null && seen.add(assignment.id)) {
        assignments.add(assignment);
      }
    }
    return assignments;
  }

  static Assignment? _parseBlock(
    String block, {
    required String courseName,
    required String sourcePrefix,
    required Uri baseUri,
    required DateTime now,
  }) {
    final cleanText = _decodeEntities(
      _stripTags(block),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_isCompletedPeerReview(cleanText)) {
      return null;
    }
    if (_isInvalidPage(cleanText, block)) {
      return null;
    }
    final deadline = _extractDeadline(cleanText, now) ??
        _ParsedDeadline(
          rawText: '未识别截止时间',
          value: now.add(const Duration(days: 30)),
        );

    final title = _firstMatch(block, [
          RegExp(
            r'(?:data-title|title)=["'
            ']([^"'
            ']+)["'
            ']',
            caseSensitive: false,
          ),
          RegExp(
            r'class=["'
            '][^"'
            ']*(?:title|work-title|task-title)[^"'
            ']*["'
            '][^>]*>([^<]+)',
            caseSensitive: false,
          ),
          RegExp(r'<a[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true),
          RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
        ])?.trim() ??
        _fallbackTitle(cleanText);
    if (title.isEmpty) {
      return null;
    }

    final sourceUrl = _extractSourceUrl(block);
    final sourceId = _extractSourceId(block, sourceUrl) ??
        '${_decodeEntities(_stripTags(title))}:${deadline.rawText}';
    final blockCourseName = _extractBlockCourseName(block, courseName);

    return Assignment(
      id: 'cx:$sourcePrefix:$sourceId',
      courseName: blockCourseName,
      title: _decodeEntities(_stripTags(title)).trim(),
      deadlineAt: deadline.value,
      requirementsText: _extractRequirement(block, cleanText),
      status: _inferStatus(cleanText),
      submitUrl: sourceUrl == null
          ? null
          : baseUri.resolve(_decodeEntities(sourceUrl)).toString(),
      lastSyncedAt: now,
    );
  }

  static String _inferStatus(String text) {
    if (RegExp(r'(待批阅|待批改|已提交|已完成|已批阅|已批改|已评价|通过|已做完)').hasMatch(text)) {
      return 'submitted';
    }
    return 'pending';
  }

  static _ParsedDeadline? _extractDeadline(String cleanText, DateTime now) {
    final absolute = _firstMatch(cleanText, [
      RegExp(r'(20\d{2}[-/年]\d{1,2}[-/月]\d{1,2}日?\s+\d{1,2}:\d{2}(?::\d{2})?)'),
      RegExp(r'(截止时间[:：]\s*(?:20\d{2}[-/年])?\d{1,2}[-/月]\d{1,2}日?\s*\d{1,2}:\d{2})'),
      RegExp(r'(结束时间[:：]\s*(?:20\d{2}[-/年])?\d{1,2}[-/月]\d{1,2}日?\s*\d{1,2}:\d{2})'),
      RegExp(r'(20\d{2}[-/]\d{1,2}[-/]\d{1,2})'),
    ]);
    if (absolute != null) {
      return _ParsedDeadline(
        rawText: absolute,
        value: _parseChinaTime(absolute),
      );
    }

    final remaining = _firstMatch(cleanText, [
      RegExp(r'(剩余\s*\d+\s*天(?:\s*\d+\s*(?:小时|时))?(?:\s*\d+\s*(?:分钟|分))?)'),
      RegExp(r'(剩余\s*\d+\s*(?:小时|时)(?:\s*\d+\s*(?:分钟|分))?)'),
      RegExp(r'(剩余\s*\d+\s*(?:分钟|分))'),
    ]);
    if (remaining == null) {
      return null;
    }

    final days = _firstInt(remaining, RegExp(r'(\d+)\s*天')) ?? 0;
    final hours = _firstInt(remaining, RegExp(r'(\d+)\s*(?:小时|时)')) ?? 0;
    final minutes = _firstInt(remaining, RegExp(r'(\d+)\s*(?:分钟|分)')) ?? 0;
    return _ParsedDeadline(
      rawText: remaining,
      value: now.add(Duration(days: days, hours: hours, minutes: minutes)),
    );
  }

  static String _fallbackTitle(String cleanText) {
    return cleanText
        .replaceFirst(RegExp(r'截止时间[:：]?\s*20\d{2}.*$'), '')
        .replaceFirst(RegExp(r'剩余\s*\d+\s*(?:天|小时|时|分钟|分).*$'), '')
        .replaceAll(RegExp(r'\b(?:未提交|已提交|待批阅|已完成|已过期)\b'), '')
        .trim();
  }

  static String? _extractSourceUrl(String block) {
    return _firstMatch(block, [
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
        ']*(?:doHomeWork|taskrefId|workId|/work/)[^"'
        ']*)["'
        ']',
        caseSensitive: false,
      ),
    ]);
  }

  static String? _extractSourceId(String block, String? sourceUrl) {
    if (sourceUrl != null) {
      final fromUrl = _queryParam(sourceUrl, const [
        'taskrefId',
        'workId',
        'workid',
        'jobid',
        'activeId',
        'id',
      ]);
      if (fromUrl != null) {
        return fromUrl;
      }
    }

    final direct = _firstMatch(block, [
      RegExp(
        r'data-id=["'
        ']([^"'
        ']+)["'
        ']',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:[?&]|^)(?:taskrefId|workId|workid|jobid|activeId|id)=([A-Za-z0-9_-]+)',
        caseSensitive: false,
      ),
    ]);
    return direct;
  }

  static String _extractBlockCourseName(String block, String fallback) {
    final named = _firstMatch(block, [
      RegExp(
        r'class=["'
        '][^"'
        ']*course-name[^"'
        ']*["'
        '][^>]*>([^<]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'class=["'
        '][^"'
        ']*courseName[^"'
        ']*["'
        '][^>]*>([^<]+)',
        caseSensitive: false,
      ),
    ]);
    if (named != null && named.trim().isNotEmpty) {
      return _decodeEntities(_stripTags(named)).trim();
    }

    final spanTexts =
        RegExp(r'<span[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true)
            .allMatches(block)
            .map(
              (match) => _decodeEntities(
                _stripTags(match.group(1) ?? ''),
              ).replaceAll(RegExp(r'\s+'), ' ').trim(),
            )
            .where((text) => text.isNotEmpty);
    for (final text in spanTexts) {
      if (!_looksLikeStatusOrTime(text)) {
        return text;
      }
    }
    return fallback;
  }

  static bool _looksLikeStatusOrTime(String text) {
    return RegExp(
      r'(未提交|已提交|待批阅|已完成|已过期|剩余|截止|开始|查看|得分|分数|成绩|20\d{2}[-/年])',
    ).hasMatch(text);
  }

  static bool _isInvalidPage(String cleanText, String block) {
    if (cleanText.contains('无效的用户') ||
        cleanText.contains('登录失效') ||
        cleanText.contains('请先登录') ||
        cleanText.contains('重新登录') ||
        cleanText.contains('账号异常') ||
        cleanText.contains('密码错误')) {
      return true;
    }
    final jsSignals = [
      'function back()',
      'window.location.href',
      'window.history.go',
      'HOST = "',
      'HOST_CP',
    ];
    for (final signal in jsSignals) {
      if (block.contains(signal) && !_hasRealAssignmentContent(cleanText)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasRealAssignmentContent(String cleanText) {
    return cleanText.contains('作业') ||
           cleanText.contains('任务') ||
           cleanText.contains('考试') ||
           cleanText.contains('截止') ||
           cleanText.contains('提交') ||
           cleanText.contains('待完成');
  }

  static bool _isCompletedPeerReview(String text) {
    if (!text.contains('互评')) {
      return false;
    }
    if (RegExp(r'(未完成|未提交|待互评|待评价|进行中)').hasMatch(text)) {
      return false;
    }
    return RegExp(r'(已互评|已完成|已提交|已评价|评价完成|互评完成)').hasMatch(text);
  }

  static String _extractRequirement(String block, String cleanText) {
    final desc = _firstMatch(block, [
      RegExp(
        r'class=["'
        '][^"'
        ']*(?:desc|require|content|detail)[^"'
        ']*["'
        '][^>]*>(.*?)</',
        caseSensitive: false,
        dotAll: true,
      ),
    ]);
    return _decodeEntities(_stripTags(desc ?? cleanText)).trim();
  }

  static DateTime _parseChinaTime(String raw) {
    final normalized = raw
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', '')
        .replaceAll('/', '-')
        .trim();
    final parts = RegExp(
      r'(20\d{2})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(normalized);
    if (parts == null) {
      throw FormatException('Unsupported deadline format: $raw');
    }
    return DateTime(
      int.parse(parts.group(1)!),
      int.parse(parts.group(2)!),
      int.parse(parts.group(3)!),
      int.parse(parts.group(4)!),
      int.parse(parts.group(5)!),
      int.parse(parts.group(6) ?? '0'),
    );
  }

  static int? _firstInt(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String? _queryParam(String url, List<String> names) {
    final decoded = _decodeEntities(url);
    final uri = Uri.tryParse(decoded);
    if (uri == null) {
      return null;
    }
    for (final entry in uri.queryParameters.entries) {
      for (final name in names) {
        if (entry.key.toLowerCase() == name.toLowerCase()) {
          return entry.value;
        }
      }
    }
    return null;
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

class _ParsedDeadline {
  const _ParsedDeadline({required this.rawText, required this.value});

  final String rawText;
  final DateTime value;
}
