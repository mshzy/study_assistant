import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/assignment.dart';
import 'chaoxing_api_parser.dart';
import 'chaoxing_assignment_parser.dart';

class ChaoxingLoginResult {
  const ChaoxingLoginResult({
    required this.success,
    this.message,
    this.displayName,
    this.avatarUrl,
  });

  final bool success;
  final String? message;
  final String? displayName;
  final String? avatarUrl;
}

class ChaoxingLocalClient {
  ChaoxingLocalClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                followRedirects: false,
                validateStatus: (status) => status != null && status < 500,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36 SuperStarStudyHelper/0.1',
                  'Accept':
                      'application/json,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'Referer': 'https://i.chaoxing.com/',
                },
              ),
            );

  final Dio _dio;
  final Map<String, String> _cookies = {};

  Future<ChaoxingLoginResult> login({
    required String account,
    required String password,
  }) async {
    if (account.trim().isEmpty || password.isEmpty) {
      return const ChaoxingLoginResult(success: false, message: '请输入账号和密码');
    }

    final response = await _dio.post<dynamic>(
      'https://passport2-api.chaoxing.com/v11/loginregister',
      data: FormData.fromMap({
        'uname': account.trim(),
        'code': password,
        'loginType': '1',
        'roleSelect': 'true',
      }),
    );
    _rememberCookies(response);
    final body = response.data?.toString() ?? '';
    final success = body.contains('"status":true') ||
        body.contains('"result":true') ||
        body.contains('true');
    if (!success) {
      return ChaoxingLoginResult(
        success: false,
        message: _extractMessage(body) ?? '学习通登录失败，请检查账号和密码',
      );
    }
    final sessionProfile = await _completeLoginSession(response.data);
    final profile = await _fetchProfile(response.data, sessionProfile);
    return ChaoxingLoginResult(
      success: true,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
    );
  }

  Future<List<Assignment>> fetchAssignments() async {
    final assignments = <Assignment>[];
    assignments.addAll(await _fetchActivityAssignments());
    assignments.addAll(await _fetchWorkPages());

    final deduped = _dedupeAssignments(assignments);
    if (deduped.isEmpty) {
      throw StateError('没有获取到作业。学习通当前可能没有未完成作业，或学校接口暂时不可用。');
    }
    return deduped;
  }

  // ---------- Assignment fetching ----------

  Future<List<Assignment>> _fetchActivityAssignments() async {
    final mcode =
        _readCookie('UID') ?? _readCookie('uid') ?? _readCookie('_uid');
    if (mcode == null || mcode.isEmpty) {
      return [];
    }

    final courseResponse = await _safeGet<dynamic>(
      'https://mooc1-api.chaoxing.com/mycourse/backclazzdata',
      queryParameters: {'view': 'json', 'mcode': mcode},
      headers: {'Accept': 'application/json'},
    );
    final courses = ChaoxingApiParser.parseCourseRefs(courseResponse?.data);
    if (courses.isEmpty) {
      return [];
    }

    final assignments = <Assignment>[];
    for (final course in courses) {
      final response = await _safeGet<dynamic>(
        'https://mobilelearn.chaoxing.com/v2/apis/active/student/activelist',
        queryParameters: {
          'fid': '0',
          'courseId': course.courseId,
          'classId': course.clazzId,
          if (course.cpi != null) 'cpi': course.cpi,
        },
        headers: {'Accept': 'application/json'},
      );
      if (response == null) {
        continue;
      }
      assignments.addAll(
        ChaoxingApiParser.parseActivityAssignments(response.data, course),
      );
      assignments.addAll(
        ChaoxingApiParser.parseActivityExamAssignments(response.data, course),
      );
    }
    return assignments;
  }

  Future<List<Assignment>> _fetchWorkPages() async {
    final pages = <_CourseWorkPage>[
      const _CourseWorkPage(
        courseName: '学习通课程',
        sourcePrefix: 'default',
        uri: 'https://mooc1-api.chaoxing.com/work/stu-work',
      ),
      const _CourseWorkPage(
        courseName: '学习通课程',
        sourcePrefix: 'default-app',
        uri: 'https://mooc1.chaoxing.com/mooc2/work/list',
      ),
    ];

    final assignments = <Assignment>[];
    for (final page in pages) {
      final response = await _safeGet<dynamic>(
        page.uri,
        headers: {'Accept': 'text/html,application/xhtml+xml'},
      );
      if (response == null) {
        continue;
      }
      final html = response.data?.toString() ?? '';
      assignments.addAll(
        ChaoxingAssignmentParser.parseWorkHtml(
          html,
          fallbackCourseName: page.courseName,
          sourcePrefix: page.sourcePrefix,
          baseUri: Uri.parse(page.uri),
        ),
      );
    }
    return assignments;
  }

  // ---------- Shared ----------

  Future<Response<T>?> _safeGet<T>(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get<T>(
        uri,
        queryParameters: queryParameters,
        options: Options(headers: _headers(headers)),
      );
      _rememberCookies(response);
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 400) {
        return response;
      }
    } catch (_) {
      // Chaoxing endpoints differ by school/session. Keep the sync pipeline best-effort.
    }
    return null;
  }

  Map<String, String> _headers([Map<String, String>? extra]) {
    return {
      if (_cookies.isNotEmpty)
        'Cookie': _cookies.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; '),
      if (extra != null) ...extra,
    };
  }

  void _rememberCookies(Response<dynamic> response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) {
      return;
    }
    for (final header in raw) {
      final pair = header.split(';').first;
      final separator = pair.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      _cookies[pair.substring(0, separator).trim()] =
          pair.substring(separator + 1).trim();
    }
  }

  String? _readCookie(String name) => _cookies[name];

  List<Assignment> _dedupeAssignments(List<Assignment> assignments) {
    final byId = <String, Assignment>{};
    for (final assignment in assignments) {
      byId[assignment.id] = assignment;
    }
    return byId.values.toList()
      ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
  }

  String? _extractMessage(String body) {
    final match = RegExp(r'"(?:msg|message)"\s*:\s*"([^"]+)"').firstMatch(body);
    return match?.group(1);
  }

  Future<_ChaoxingProfile> _completeLoginSession(dynamic payload) async {
    final redirectUrl = _extractLoginRedirectUrl(payload);
    if (redirectUrl == null) {
      return const _ChaoxingProfile();
    }
    final response = await _safeGet<dynamic>(
      redirectUrl,
      headers: {'Accept': 'text/html,application/xhtml+xml,*/*'},
    );
    return _extractProfile(response?.data);
  }

  Future<_ChaoxingProfile> _fetchProfile(
    dynamic loginPayload,
    _ChaoxingProfile sessionProfile,
  ) async {
    final fromLogin = _extractProfile(loginPayload);
    final fallback = _ChaoxingProfile(
      displayName: sessionProfile.displayName ?? fromLogin.displayName,
      avatarUrl: sessionProfile.avatarUrl ?? fromLogin.avatarUrl,
    );
    final candidates = ['https://i.chaoxing.com/base'];
    for (final uri in candidates) {
      final response = await _safeGet<dynamic>(
        uri,
        headers: {'Accept': 'application/json,text/html,*/*'},
      );
      final fromResponse = response == null
          ? const _ChaoxingProfile()
          : _extractProfile(response.data);
      final merged = _ChaoxingProfile(
        displayName: fromResponse.displayName ?? fallback.displayName,
        avatarUrl: fromResponse.avatarUrl ?? fallback.avatarUrl,
      );
      if (merged.displayName != null || merged.avatarUrl != null) {
        return merged;
      }
    }
    return fallback;
  }

  _ChaoxingProfile _extractProfile(dynamic payload) {
    final decoded = _decodeJsonPayload(payload);
    final displayName = _extractDisplayName(decoded);
    final avatarFromPayload = _extractAvatarUrl(decoded);
    return _ChaoxingProfile(
      displayName: displayName,
      avatarUrl: avatarFromPayload ?? _avatarUrlFromCookie(),
    );
  }

  dynamic _decodeJsonPayload(dynamic payload) {
    if (payload is! String) {
      return payload;
    }
    final trimmed = payload.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return payload;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return payload;
    }
  }

  String? _extractLoginRedirectUrl(dynamic payload) {
    final decoded = _decodeJsonPayload(payload);
    if (decoded is Map) {
      for (final key in ['url', 'loginUrl', 'redirectUrl', 'location']) {
        final normalized = _normalizeUrl(decoded[key]?.toString());
        if (normalized != null) {
          return normalized;
        }
      }
    }
    final body = payload?.toString() ?? '';
    final match = RegExp(
      r'"(?:url|loginUrl|redirectUrl|location)"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(body);
    return _normalizeUrl(match?.group(1));
  }

  String? _extractDisplayName(dynamic payload) {
    final direct = _extractDisplayNameFromJson(payload);
    if (direct != null) {
      return direct;
    }
    final body = payload?.toString() ?? '';
    if (body.isEmpty) {
      return null;
    }
    final userNameElement = RegExp(
      r'''class=["'][^"']*user-name[^"']*["'][^>]*>(.*?)</[^>]+>''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    final fromElement =
        _normalizeDisplayName(_stripTags(userNameElement?.group(1)));
    if (fromElement != null) {
      return fromElement;
    }
    final jsonLike = RegExp(
      r'"(?:realName|realname|name|nickName|nickname|uname|userName|username)"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(body);
    final htmlLike = jsonLike ??
        RegExp(
          r'''(?:realName|realname|name|nickName|nickname|uname|userName|username)["']?\s*[:=]\s*["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(body);
    return _normalizeDisplayName(htmlLike?.group(1));
  }

  String? _extractDisplayNameFromJson(dynamic payload) {
    if (payload is Map) {
      final candidates = [
        payload['realName'],
        payload['realname'],
        payload['name'],
        payload['nickName'],
        payload['nickname'],
        payload['uname'],
        payload['userName'],
        payload['username'],
      ];
      for (final candidate in candidates) {
        final normalized = _normalizeDisplayName(candidate?.toString());
        if (normalized != null) {
          return normalized;
        }
      }
      for (final key in ['msg', 'data', 'user', 'userInfo', 'accountInfo']) {
        final nested = _extractDisplayNameFromJson(payload[key]);
        if (nested != null) {
          return nested;
        }
      }
    }
    if (payload is List) {
      for (final item in payload) {
        final nested = _extractDisplayNameFromJson(item);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  String? _extractAvatarUrl(dynamic payload) {
    final direct = _extractAvatarUrlFromJson(payload);
    if (direct != null) {
      return direct;
    }
    final body = payload?.toString() ?? '';
    if (body.isEmpty) {
      return null;
    }
    final imageLike = RegExp(
      r'''(?:avatar|avatarUrl|avatarurl|photo|photoUrl|pic|picUrl|headPic|headimgurl)["']?\s*[:=]\s*["']?([^"',}\s]+)''',
      caseSensitive: false,
    ).firstMatch(body);
    return _normalizeUrl(imageLike?.group(1));
  }

  String? _extractAvatarUrlFromJson(dynamic payload) {
    if (payload is Map) {
      final candidates = [
        payload['avatar'],
        payload['avatarUrl'],
        payload['avatarurl'],
        payload['photo'],
        payload['photoUrl'],
        payload['pic'],
        payload['picUrl'],
        payload['headPic'],
        payload['headimgurl'],
      ];
      for (final candidate in candidates) {
        final normalized = _normalizeUrl(candidate?.toString());
        if (normalized != null) {
          return normalized;
        }
      }
      for (final key in ['msg', 'data', 'user', 'userInfo', 'accountInfo']) {
        final nested = _extractAvatarUrlFromJson(payload[key]);
        if (nested != null) {
          return nested;
        }
      }
    }
    if (payload is List) {
      for (final item in payload) {
        final nested = _extractAvatarUrlFromJson(item);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  String? _normalizeDisplayName(String? value) {
    final normalized = _decodeHtmlEntities(value ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('@') || normalized.length > 24) {
      return null;
    }
    return normalized;
  }

  String? _avatarUrlFromCookie() {
    final uid = _readCookie('UID') ?? _readCookie('uid') ?? _readCookie('_uid');
    if (uid == null || uid.trim().isEmpty) {
      return null;
    }
    return 'https://photo.chaoxing.com/p/${Uri.encodeComponent(uid.trim())}_160';
  }

  String? _normalizeUrl(String? value) {
    var normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    normalized = normalized.replaceAll(r'\/', '/');
    if (normalized.startsWith('//')) {
      return 'https:$normalized';
    }
    if (normalized.startsWith('http://')) {
      return normalized.replaceFirst('http://', 'https://');
    }
    if (!normalized.startsWith('https://')) {
      return null;
    }
    return normalized;
  }

  String _stripTags(String? html) {
    if (html == null || html.isEmpty) {
      return '';
    }
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

class _ChaoxingProfile {
  const _ChaoxingProfile({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;
}

class _CourseWorkPage {
  const _CourseWorkPage({
    required this.courseName,
    required this.sourcePrefix,
    required this.uri,
  });

  final String courseName;
  final String sourcePrefix;
  final String uri;
}
