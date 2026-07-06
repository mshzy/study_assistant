import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/app_deep_links.dart';
import 'src/app/app_shell.dart';
import 'src/features/assignment_detail_screen.dart';
import 'src/features/assignment_list_screen.dart';
import 'src/features/calendar_screen.dart';
import 'src/features/login_screen.dart';
import 'src/features/profile_screen.dart';
import 'src/features/reminder_settings_screen.dart';
import 'src/features/stats_screen.dart';
import 'src/features/sync_status_screen.dart';
import 'src/services/app_update_service.dart';
import 'src/services/external_link_service.dart';
import 'src/app/app_version.dart';
import 'src/services/assignment_store.dart';
import 'src/services/local_notification_service.dart';
import 'src/services/reminder_rule_store.dart';
import 'src/services/secure_session_store.dart';
import 'src/services/widget_snapshot_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  final sessionStore = SecureSessionStore();
  final notificationService = LocalNotificationService();
  final widgetSnapshotService = WidgetSnapshotService();
  final reminderRuleStore = ReminderRuleStore();

  final assignmentStore = AssignmentStore(
    sessionStore: sessionStore,
    notificationService: notificationService,
    widgetSnapshotService: widgetSnapshotService,
    reminderRuleStore: reminderRuleStore,
  );

  await notificationService.initializeSafely();
  await assignmentStore.restoreSession();

  runApp(StudyAssistantApp(
    assignmentStore: assignmentStore,
    notificationService: notificationService,
  ));
}

class StudyAssistantApp extends StatefulWidget {
  const StudyAssistantApp({
    super.key,
    required this.assignmentStore,
    required this.notificationService,
  });

  final AssignmentStore assignmentStore;
  final LocalNotificationService notificationService;

  @override
  State<StudyAssistantApp> createState() => _StudyAssistantAppState();
}

class _StudyAssistantAppState extends State<StudyAssistantApp>
    with WidgetsBindingObserver {
  AssignmentStore get assignmentStore => widget.assignmentStore;
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter();
    widget.notificationService.setPayloadHandler(_handleNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdateOnStartup());
  }

  Future<void> _checkUpdateOnStartup() async {
    debugPrint('[UpdateCheck] _checkUpdateOnStartup START, version=${AppVersion.name}');
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        debugPrint('[UpdateCheck] Attempt $attempt...');
        final update = await AppUpdateService().checkForUpdate(
          currentVersionName: AppVersion.name,
          currentVersionCode: AppVersion.code,
        );
        debugPrint('[UpdateCheck] checkForUpdate result: $update');
        if (update == null || !mounted) return;
        // Use postFrameCallback to ensure Navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showUpdateDialog(update);
        });
        return;
      } catch (e, stack) {
        debugPrint('[UpdateCheck] Attempt $attempt failed: $e');
        debugPrint('[UpdateCheck] Stack: $stack');
        if (attempt < 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    if (!mounted) return;
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    showDialog<void>(
      context: navigatorContext,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text('v${update.versionName} 已发布，是否更新？\n\n${update.releaseNotes}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _downloadAndInstall(update);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(AppUpdateInfo update) async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;

    // Show download progress dialog
    showDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            var _received = 0;
            var _total = 0;
            var _done = false;
            var _error = false;

            void startDownload() {
              AppUpdateService().downloadApk(update, onProgress: (received, total) {
                if (ctx.mounted) {
                  setDialogState(() {
                    _received = received;
                    _total = total;
                  });
                }
              }).then((file) async {
                if (ctx.mounted) {
                  setDialogState(() => _done = true);
                  Navigator.of(ctx).pop();
                  final success = await ExternalLinkService().installApk(file.path);
                  final mc = _navigatorKey.currentContext;
                  if (!success && mc != null && mc.mounted) {
                    ScaffoldMessenger.of(mc).showSnackBar(
                      const SnackBar(content: Text('无法打开系统安装器')),
                    );
                  }
                }
              }).catchError((_) {
                if (ctx.mounted) {
                  setDialogState(() => _error = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  });
                }
              });
            }

            startDownload();

            return AlertDialog(
              title: Text(_error ? '下载失败' : (_done ? '下载完成' : '正在下载更新包...')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_error && !_done) ...[
                    LinearProgressIndicator(
                      value: _total > 0 ? _received / _total : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _total > 0
                          ? '${(_received / 1024 / 1024).toStringAsFixed(1)} MB / ${(_total / 1024 / 1024).toStringAsFixed(1)} MB'
                          : '连接中...',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                  if (_error)
                    const Text('下载更新包失败，请稍后再试'),
                ],
              ),
              actions: _error
                  ? [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('关闭'),
                      ),
                    ]
                  : null,
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationService.setPayloadHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      assignmentStore.runDueAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '学习通作业提醒',
      debugShowCheckedModeBanner: false,
      theme: StudyAssistantTheme.light,
      routerConfig: _router,
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      navigatorKey: _navigatorKey,
      refreshListenable: assignmentStore,
      initialLocation:
          assignmentStore.isAuthenticated ? '/assignments' : '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, state) => LoginScreen(
            store: assignmentStore,
            addPlatformMode: state.uri.queryParameters['addPlatform'] == '1',
          ),
        ),
        ShellRoute(
          builder: (_, __, child) => AppShell(
            assignmentStore: assignmentStore,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/assignments',
              builder: (_, __) => AssignmentListScreen(store: assignmentStore),
            ),
            GoRoute(
              path: '/assignments/:id',
              builder: (_, state) => AssignmentDetailScreen(
                store: assignmentStore,
                assignmentId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/calendar',
              builder: (_, __) => CalendarScreen(store: assignmentStore),
            ),
            GoRoute(
              path: '/stats',
              builder: (_, __) => StatsScreen(store: assignmentStore),
            ),
            GoRoute(
              path: '/sync',
              builder: (_, __) => SyncStatusScreen(store: assignmentStore),
            ),
            GoRoute(
              path: '/reminders',
              builder: (_, __) => ReminderSettingsScreen(
                assignmentStore: assignmentStore,
              ),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, __) => ProfileScreen(store: assignmentStore),
            ),
          ],
        ),
      ],
      redirect: (_, state) {
        final normalizedLocation =
            AppDeepLinks.normalizeIncomingLocation(state.uri);
        if (normalizedLocation != null) {
          return normalizedLocation;
        }

        final loggedIn = assignmentStore.isAuthenticated;
        final loggingIn = state.matchedLocation == '/login';
        final addingPlatform =
            loggingIn && state.uri.queryParameters['addPlatform'] == '1';
        if (!loggedIn && !loggingIn) {
          return '/login';
        }
        if (loggedIn && loggingIn && !addingPlatform) {
          return '/assignments';
        }
        return null;
      },
    );
  }

  void _handleNotificationPayload(String payload) {
    final location = AppDeepLinks.normalizeIncomingLocation(
      Uri.parse(payload),
    );
    if (location != null) {
      _router.go(location);
    }
  }
}
