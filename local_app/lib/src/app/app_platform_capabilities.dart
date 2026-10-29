import 'package:flutter/foundation.dart';

class AppPlatformCapabilities {
  const AppPlatformCapabilities._();

  static bool supportsApkUpdates(TargetPlatform platform) {
    return platform == TargetPlatform.android;
  }
}
