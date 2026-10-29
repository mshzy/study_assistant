import 'dart:io';

import 'package:flutter/material.dart';

typedef AppUpdateDownload = Future<File> Function(
  void Function(int receivedBytes, int totalBytes) onProgress,
);

class AppUpdateDownloadDialog extends StatefulWidget {
  const AppUpdateDownloadDialog({
    super.key,
    required this.download,
  });

  final AppUpdateDownload download;

  @override
  State<AppUpdateDownloadDialog> createState() =>
      _AppUpdateDownloadDialogState();
}

class _AppUpdateDownloadDialogState extends State<AppUpdateDownloadDialog> {
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDownload());
  }

  Future<void> _startDownload() async {
    try {
      final file = await widget.download((receivedBytes, totalBytes) {
        if (!mounted) {
          return;
        }
        setState(() {
          _receivedBytes = receivedBytes;
          _totalBytes = totalBytes;
        });
      });
      if (mounted) {
        Navigator.of(context).pop(file);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _failed,
      child: AlertDialog(
        title: Text(_failed ? '下载失败' : '正在下载更新包...'),
        content: _failed
            ? const Text('下载更新包失败，请稍后再试')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _totalBytes > 0
                        ? (_receivedBytes / _totalBytes).clamp(0, 1).toDouble()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _totalBytes > 0
                        ? '${(_receivedBytes * 100 / _totalBytes).clamp(0, 100).toStringAsFixed(0)}%'
                        : '连接中...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
        actions: _failed
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ]
            : null,
      ),
    );
  }
}
