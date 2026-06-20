import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/local/chaoxing_local_client.dart';

void main() {
  test(
      'login follows Chaoxing redirect before resolving profile name and avatar',
      () async {
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
                host: options.uri.host,
                path: options.uri.path,
                headers: Map<String, dynamic>.from(options.headers),
              ),
            );

            if (options.uri.host == 'passport2-api.chaoxing.com' &&
                options.uri.path == '/v11/loginregister') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': true,
                    'url': 'https://sso.chaoxing.com/login?token=ok',
                  },
                ),
              );
              return;
            }

            if (options.uri.host == 'sso.chaoxing.com') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: 'ok',
                  headers: Headers.fromMap({
                    'set-cookie': ['UID=998877; Path=/; HttpOnly'],
                  }),
                ),
              );
              return;
            }

            if (options.uri.host == 'i.chaoxing.com' &&
                options.uri.path == '/base') {
              final cookie = options.headers['Cookie']?.toString() ?? '';
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: cookie.contains('UID=998877')
                      ? '<html><span class="user-name">李雷</span></html>'
                      : '<html>未登录</html>',
                ),
              );
              return;
            }

            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 404,
                data: 'not found',
              ),
            );
          },
        ),
      );
    final client = ChaoxingLocalClient(dio: dio);

    final result = await client.login(account: 'student', password: 'password');

    expect(result.success, isTrue);
    expect(result.displayName, '李雷');
    expect(
        result.avatarUrl, 'https://photo.chaoxing.com/p/998877_160?ts=998877');
    expect(requests.map((request) => '${request.host}${request.path}'), [
      'passport2-api.chaoxing.com/v11/loginregister',
      'sso.chaoxing.com/login',
      'i.chaoxing.com/base',
    ]);
    expect(requests.last.headers['Cookie'], contains('UID=998877'));
  });

  test('extracts Chaoxing profile from nested SSO msg payload', () async {
    final dio = Dio(
      BaseOptions(
        validateStatus: (status) => status != null && status < 500,
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'passport2-api.chaoxing.com') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': true,
                    'url':
                        'https://sso.chaoxing.com/apis/login/userLogin4Uname.do',
                  },
                ),
              );
              return;
            }
            if (options.uri.host == 'sso.chaoxing.com') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'msg': {
                      'name': '郜小展',
                      'nick': '郜小展',
                      'uid': 354629555,
                      'puid': 402733611,
                      'pic': 'http://photo.chaoxing.com/p/402733611_120?flag=1',
                    },
                    'status': true,
                  },
                  headers: Headers.fromMap({
                    'set-cookie': ['UID=354629555; Path=/; HttpOnly'],
                  }),
                ),
              );
              return;
            }
            if (options.uri.host == 'i.chaoxing.com' &&
                options.uri.path == '/base') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data:
                      '<html><head><meta name="viewport" content="width=device-width"></head></html>',
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 404,
                data: 'not found',
              ),
            );
          },
        ),
      );
    final client = ChaoxingLocalClient(dio: dio);

    final result = await client.login(account: 'student', password: 'password');

    expect(result.success, isTrue);
    expect(result.displayName, '郜小展');
    expect(
      result.avatarUrl,
      'https://photo.chaoxing.com/p/402733611_120?flag=1',
    );
  });
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.host,
    required this.path,
    required this.headers,
  });

  final String method;
  final String host;
  final String path;
  final Map<String, dynamic> headers;
}
