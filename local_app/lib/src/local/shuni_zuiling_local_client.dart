import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/assignment.dart';
import 'shuni_zuiling_assignment_parser.dart';

class ShuniZuilingLoginResult {
  const ShuniZuilingLoginResult({
    required this.success,
    this.token,
    this.message,
  });

  final bool success;
  final String? token;
  final String? message;
}

class ShuniZuilingLocalClient {
  ShuniZuilingLocalClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://smartestu.cn',
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                validateStatus: (status) => status != null && status < 500,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36 StudyAssistant/1.0',
                  'Accept':
                      'application/json,text/html,application/xhtml+xml,*/*',
                },
              ),
            );

  final Dio _dio;
  final Map<String, String> _cookies = {};
  String? _token;

  static const _fallbackSchools = [
    ShuniZuilingSchool(code: 'zzuli', name: '郑州轻工业大学'),
  ];

  Future<ShuniZuilingLoginResult> login({
    required String schoolUserLocalId,
    required String password,
    required String schoolCode,
  }) async {
    if (schoolUserLocalId.trim().isEmpty ||
        password.isEmpty ||
        schoolCode.trim().isEmpty) {
      return const ShuniZuilingLoginResult(
        success: false,
        message: '请输入学号、密码和学校代码',
      );
    }

    final normalizedSchoolCode = schoolCode.trim();
    final normalizedStudentId = schoolUserLocalId.trim();
    final response = await _dio.post<dynamic>(
      '/api/auth/login',
      data: {
        'schoolUserLocalId': normalizedStudentId,
        'password': password,
        'schoolCode': normalizedSchoolCode,
        'schoolUserId': '$normalizedSchoolCode-$normalizedStudentId',
      },
      options: Options(headers: _headers()),
    );
    _rememberCookies(response);
    final token = _readToken(response.data);
    if ((response.statusCode ?? 0) >= 400 || token == null || token.isEmpty) {
      return ShuniZuilingLoginResult(
        success: false,
        message: _readMessage(response.data) ?? '数你最灵登录失败，请检查账号和密码',
      );
    }
    _token = token;
    return ShuniZuilingLoginResult(success: true, token: token);
  }

  Future<List<Assignment>> fetchAssignments({
    required String studentId,
    List<int> courseIds = const [],
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw StateError('数你最灵未登录');
    }
    final response = await _dio.post<dynamic>(
      '/api/homework/student/mark/queryHomeworks',
      data: {
        'studentId': studentId,
        'courseIds': courseIds,
        'scene': 'homework',
      },
      options: Options(headers: _headers({'Authorization': 'Bearer $token'})),
    );
    _rememberCookies(response);
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 400) {
      throw StateError(_readMessage(response.data) ?? '数你最灵作业同步失败');
    }
    return _dedupe(ShuniZuilingAssignmentParser.parseJson(response.data));
  }

  Future<List<ShuniZuilingSchool>> fetchSchools() async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/schools',
        options: Options(headers: _headers()),
      );
      _rememberCookies(response);
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 400) {
        final schools = _parseSchools(response.data);
        return schools.isEmpty ? _fallbackSchools : schools;
      }
    } catch (_) {
      // Keep the login form usable when the school endpoint is temporarily unavailable.
    }
    return _fallbackSchools;
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

  List<Assignment> _dedupe(List<Assignment> assignments) {
    final byId = <String, Assignment>{};
    for (final assignment in assignments) {
      byId[assignment.id] = assignment;
    }
    return byId.values.toList()
      ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
  }

  String? _readToken(dynamic data) {
    final map = _asMap(data);
    if (map == null) {
      return null;
    }
    final direct = map['token']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final nested = _asMap(map['data']);
    return nested?['token']?.toString();
  }

  String? _readMessage(dynamic data) {
    final map = _asMap(data);
    if (map == null) {
      return null;
    }
    return (map['msg'] ?? map['message'] ?? map['error'])?.toString();
  }

  List<ShuniZuilingSchool> _parseSchools(dynamic data) {
    final root = _asMap(data);
    final list = data is List
        ? data
        : root?['data'] is List
            ? root!['data'] as List<dynamic>
            : root?['schools'] is List
                ? root!['schools'] as List<dynamic>
                : const <dynamic>[];
    return list
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final code = item['code']?.toString();
          final name = (item['name'] ?? item['schoolName'])?.toString();
          if (code == null || code.isEmpty || name == null || name.isEmpty) {
            return null;
          }
          return ShuniZuilingSchool(code: code, name: name);
        })
        .whereType<ShuniZuilingSchool>()
        .toList();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return _asMap(decoded);
      } catch (_) {
        return null;
      }
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

class ShuniZuilingSchool {
  const ShuniZuilingSchool({required this.code, required this.name});

  final String code;
  final String name;
}
