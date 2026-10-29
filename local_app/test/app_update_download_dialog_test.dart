import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_mobile/src/app/app_update_download_dialog.dart';

void main() {
  testWidgets('download progress survives dialog rebuilds', (tester) async {
    final download = Completer<File>();
    void Function(int receivedBytes, int totalBytes)? reportProgress;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<File>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AppUpdateDownloadDialog(
                  download: (onProgress) {
                    reportProgress = onProgress;
                    return download.future;
                  },
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pump();
    reportProgress!(5, 10);
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);
    await tester.pump();
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('failed download leaves a closable error dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<File>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AppUpdateDownloadDialog(
                  download: (_) => Future<File>.error(StateError('offline')),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('下载失败'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('下载失败'), findsNothing);
  });
}
