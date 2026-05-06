import 'package:dio/dio.dart';

import '../models/assignment.dart';
import 'chaoxing_api_parser.dart';
import 'chaoxing_assignment_parser.dart';

class ChaoxingLoginResult {
  const ChaoxingLoginResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class ChaoxingLocalClient {
  ChaoxingLocalClient({Dio? dio})
    : _dio =
          dio ??
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
    final success =
        body.contains('"status":true') ||
        body.contains('"result":true') ||
        body.contains('true');
    if (!success) {
      return ChaoxingLoginResult(
        success: false,
        message: _extractMessage(body) ?? '学习通登录失败，请检查账号和密码',
      );
    }
    return const ChaoxingLoginResult(success: true);
  }

  Future<List<Assignment>> fetchAssignments() async {
    final assignments = <Assignment>[];
    assignments.addAll(await _fetchActivityAssignments());
    assignments.addAll(await _fetchWorkPages());

    final deduped = _dedupe(assignments);
    if (deduped.isEmpty) {
      throw StateError('没有获取到作业。学习通当前可能没有未完成作业，或学校接口暂时不可用。');
    }
    return deduped;
  }

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
      _cookies[pair.substring(0, separator).trim()] = pair
          .substring(separator + 1)
          .trim();
    }
  }

  String? _readCookie(String name) => _cookies[name];

  List<Assignment> _dedupe(List<Assignment> assignments) {
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
