import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.releaseUrl,
    required this.apkName,
    required this.apkDownloadUrl,
    required this.releaseNotes,
    this.apkSize,
  });

  final String versionName;
  final String releaseUrl;
  final String apkName;
  final String apkDownloadUrl;
  final String releaseNotes;
  final int? apkSize;
}

class AppUpdateService {
  AppUpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.github.com',
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                validateStatus: (status) => status != null && status < 500,
                headers: const {
                  'Accept': 'application/vnd.github+json',
                  'User-Agent': 'StudyAssistant/1.0',
                },
              ),
            );

  static const owner = 'mshzy';
  static const repo = 'study_assistant';

  final Dio _dio;

  Future<AppUpdateInfo?> checkForUpdate({
    required String currentVersionName,
    required int currentVersionCode,
  }) async {
    final response = await _dio.get<dynamic>(
      '/repos/$owner/$repo/releases/latest',
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw StateError('检查更新失败');
    }
    final release = _asMap(response.data);
    if (release == null) {
      throw StateError('更新信息格式无效');
    }
    final rawTag = (release['tag_name'] ?? release['name'])?.toString();
    if (rawTag == null || rawTag.trim().isEmpty) {
      return null;
    }
    final remoteVersion = normalizeVersionName(rawTag);
    if (!isRemoteVersionNewer(remoteVersion, currentVersionName)) {
      return null;
    }
    final asset = _findApkAsset(release['assets']);
    if (asset == null) {
      return null;
    }
    final apkUrl = asset['browser_download_url']?.toString();
    final apkName = asset['name']?.toString();
    if (apkUrl == null ||
        apkUrl.isEmpty ||
        apkName == null ||
        apkName.isEmpty) {
      return null;
    }
    return AppUpdateInfo(
      versionName: remoteVersion,
      releaseUrl: release['html_url']?.toString() ??
          'https://github.com/$owner/$repo/releases/tag/$rawTag',
      apkName: apkName,
      apkDownloadUrl: apkUrl,
      releaseNotes: release['body']?.toString() ?? '',
      apkSize: _asInt(asset['size']),
    );
  }

  Future<File> downloadApk(
    AppUpdateInfo update, {
    String? targetDirectory,
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final baseDirectory = targetDirectory == null
        ? Directory(
            '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
          )
        : Directory(targetDirectory);
    await baseDirectory.create(recursive: true);
    final file = File(
      '${baseDirectory.path}${Platform.pathSeparator}${_safeFileName(update.apkName)}',
    );
    final response = await _dio.get<List<int>>(
      update.apkDownloadUrl,
      onReceiveProgress: onProgress,
      options: Options(responseType: ResponseType.bytes),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300 || response.data == null) {
      throw StateError('下载 APK 失败');
    }
    final bytes = response.data!;
    final totalBytes = _asInt(response.headers.value('content-length')) ??
        update.apkSize ??
        bytes.length;
    onProgress?.call(bytes.length, totalBytes);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static bool isRemoteVersionNewer(String remote, String current) {
    final remoteParts = _versionParts(remote);
    final currentParts = _versionParts(current);
    final length = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;
    for (var index = 0; index < length; index += 1) {
      final remotePart = index < remoteParts.length ? remoteParts[index] : 0;
      final currentPart = index < currentParts.length ? currentParts[index] : 0;
      if (remotePart > currentPart) {
        return true;
      }
      if (remotePart < currentPart) {
        return false;
      }
    }
    return false;
  }

  static String normalizeVersionName(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    final plusIndex = normalized.indexOf('+');
    if (plusIndex >= 0) {
      normalized = normalized.substring(0, plusIndex);
    }
    return normalized;
  }

  static List<int> _versionParts(String value) {
    return normalizeVersionName(value)
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  Map<String, dynamic>? _findApkAsset(dynamic assets) {
    if (assets is! List) {
      return null;
    }
    for (final item in assets) {
      final asset = _asMap(item);
      final name = asset?['name']?.toString().toLowerCase();
      if (asset != null && name != null && name.endsWith('.apk')) {
        return asset;
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
    if (sanitized.isEmpty || !sanitized.toLowerCase().endsWith('.apk')) {
      return 'study-assistant-update.apk';
    }
    return sanitized;
  }
}
