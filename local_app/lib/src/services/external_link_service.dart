import 'package:flutter/services.dart';

class ExternalLinkService {
  static const _channel = MethodChannel('study_assistant/external_links');

  Future<bool> openUrl(String url) async {
    final opened = await _channel.invokeMethod<bool>('openUrl', {'url': url});
    return opened ?? false;
  }
}
