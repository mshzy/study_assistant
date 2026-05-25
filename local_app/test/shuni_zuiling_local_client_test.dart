import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/local/shuni_zuiling_local_client.dart';

void main() {
  test('fetches Shuni Zuiling schools from smartestu schools envelope', () async {
    final dio = Dio(
      BaseOptions(
        validateStatus: (status) => status != null && status < 500,
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'schools': [
                    {'name': '郑州轻工业大学', 'code': 'zzuli'},
                    {'schoolName': '测试大学', 'code': 'test'},
                  ],
                },
              ),
            );
          },
        ),
      );
    final client = ShuniZuilingLocalClient(dio: dio);

    final schools = await client.fetchSchools();

    expect(schools.map((school) => '${school.name}:${school.code}'), [
      '郑州轻工业大学:zzuli',
      '测试大学:test',
    ]);
  });

  test('parses Shuni Zuiling schools when response data is a JSON string',
      () async {
    final dio = Dio(
      BaseOptions(
        validateStatus: (status) => status != null && status < 500,
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data:
                    '{"schools":[{"name":"郑州轻工业大学","code":"zzuli"}]}',
              ),
            );
          },
        ),
      );
    final client = ShuniZuilingLocalClient(dio: dio);

    final schools = await client.fetchSchools();

    expect(schools.map((school) => '${school.name}:${school.code}'), [
      '郑州轻工业大学:zzuli',
    ]);
  });

  test('falls back to bundled school list when school API is unavailable',
      () async {
    final dio = Dio(
      BaseOptions(
        validateStatus: (status) => status != null && status < 500,
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'network down',
              ),
            );
          },
        ),
      );
    final client = ShuniZuilingLocalClient(dio: dio);

    final schools = await client.fetchSchools();

    expect(
      schools.map((school) => '${school.name}:${school.code}'),
      contains('郑州轻工业大学:zzuli'),
    );
  });

  test('logs in and fetches homework from smartestu API', () async {
    final requests = <_RecordedRequest>[];
    final dio = Dio(
      BaseOptions(
        validateStatus: (status) => status != null && status < 500,
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(
              _RecordedRequest(
                method: options.method,
                path: options.uri.path,
                headers: Map<String, dynamic>.from(options.headers),
                data: options.data,
              ),
            );
            if (options.path.endsWith('/api/auth/login')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'token': 'smart-token'},
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'code': 200,
                  'data': {
                    'courseHomeworkDTOList': [
                      {
                        'courseId': 1485,
                        'courseName': '高等数学',
                        'studentCourseHomeworkDTOList': [
                          {
                            'id': 24738,
                            'name': '第 6 次作业',
                            'endTime': '2026-06-01T15:59:10.900Z',
                            'submission_status': 'not_submitted',
                          },
                        ],
                      },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );
    final client = ShuniZuilingLocalClient(dio: dio);

    final login = await client.login(
      schoolUserLocalId: '20260001',
      password: 'password',
      schoolCode: 'school',
    );
    final assignments = await client.fetchAssignments(
      studentId: 'school-20260001',
      courseIds: const [1485],
    );

    expect(login.success, isTrue);
    expect(assignments.single.id, 'snzl:24738');
    expect(requests.first.path, '/api/auth/login');
    expect(requests.first.data, {
      'schoolUserLocalId': '20260001',
      'password': 'password',
      'schoolCode': 'school',
      'schoolUserId': 'school-20260001',
    });
    expect(requests.last.path, '/api/homework/student/mark/queryHomeworks');
    expect(requests.last.headers['Authorization'], 'Bearer smart-token');
    expect(requests.last.data, {
      'studentId': 'school-20260001',
      'courseIds': [1485],
      'scene': 'homework',
    });
  });
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.data,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final dynamic data;
}
