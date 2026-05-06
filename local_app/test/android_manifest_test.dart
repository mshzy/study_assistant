import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest declares internet permission for local Chaoxing login',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('Android manifest declares scheduled notification boot recovery', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
  });
}
