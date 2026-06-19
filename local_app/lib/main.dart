import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/app_deep_links.dart';
import 'src/app/app_shell.dart';
import 'src/features/assignment_detail_screen.dart';
import 'src/features/assignment_list_screen.dart';
import 'src/features/login_screen.dart';
import 'src/features/profile_screen.dart';
import 'src/features/reminder_settings_screen.dart';
import 'src/features/sync_status_screen.dart';
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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter();
    widget.notificationService.setPayloadHandler(_handleNotificationPayload);
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
