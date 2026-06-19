import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/services/app_update_service.dart';

void main() {
  test('finds newer GitHub release apk asset', () async {
    final dio = Dio(
      BaseOptions(validateStatus: (status) => status != null && status < 500),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'tag_name': 'v1.0.7',
                  'name': 'v1.0.7',
                  'html_url':
                      'https://github.com/mshzy/study_assistant/releases/tag/v1.0.7',
                  'body': 'bug fixes',
                  'assets': [
                    {
                      'name': 'study-assistant-v1.0.7.apk',
                      'browser_download_url':
                          'https://github.com/mshzy/study_assistant/releases/download/v1.0.7/study-assistant-v1.0.7.apk',
                      'size': 123456,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    final service = AppUpdateService(dio: dio);

    final update = await service.checkForUpdate(
      currentVersionName: '1.0.6',
      currentVersionCode: 17,
    );

    expect(update, isNotNull);
    expect(update!.versionName, '1.0.7');
    expect(update.apkName, 'study-assistant-v1.0.7.apk');
    expect(update.apkDownloadUrl, contains('/study-assistant-v1.0.7.apk'));
    expect(update.releaseNotes, 'bug fixes');
  });

  test('ignores release when remote version is not newer', () async {
    final dio = Dio(
      BaseOptions(validateStatus: (status) => status != null && status < 500),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'tag_name': 'v1.0.6',
                  'assets': [
                    {
                      'name': 'study-assistant-v1.0.6.apk',
                      'browser_download_url': 'https://example.com/app.apk',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    final service = AppUpdateService(dio: dio);

    final update = await service.checkForUpdate(
      currentVersionName: '1.0.6',
      currentVersionCode: 17,
    );

    expect(update, isNull);
  });

  test('compares semantic versions numerically', () {
    expect(AppUpdateService.isRemoteVersionNewer('1.0.10', '1.0.6'), isTrue);
    expect(AppUpdateService.isRemoteVersionNewer('1.0.6', '1.0.10'), isFalse);
    expect(AppUpdateService.isRemoteVersionNewer('v2.0.0', '1.9.9'), isTrue);
  });
}
