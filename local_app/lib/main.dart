import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/app_shell.dart';
import 'src/features/assignment_detail_screen.dart';
import 'src/features/assignment_list_screen.dart';
import 'src/features/login_screen.dart';
import 'src/features/profile_screen.dart';
import 'src/features/reminder_settings_screen.dart';
import 'src/features/sync_status_screen.dart';
import 'src/services/assignment_store.dart';
import 'src/services/local_notification_service.dart';
import 'src/services/secure_session_store.dart';
import 'src/services/widget_snapshot_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  final sessionStore = SecureSessionStore();
  final notificationService = LocalNotificationService();
  final widgetSnapshotService = WidgetSnapshotService();
  final assignmentStore = AssignmentStore(
    sessionStore: sessionStore,
    notificationService: notificationService,
    widgetSnapshotService: widgetSnapshotService,
  );
  await notificationService.initializeSafely();
  await assignmentStore.restoreSession();

  runApp(StudyAssistantApp(store: assignmentStore));
}

class StudyAssistantApp extends StatelessWidget {
  const StudyAssistantApp({super.key, required this.store});

  final AssignmentStore store;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      refreshListenable: store,
      initialLocation: store.isAuthenticated ? '/assignments' : '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => LoginScreen(store: store)),
        ShellRoute(
          builder: (_, __, child) => AppShell(store: store, child: child),
          routes: [
            GoRoute(
                path: '/assignments',
                builder: (_, __) => AssignmentListScreen(store: store)),
            GoRoute(
              path: '/assignments/:id',
              builder: (_, state) => AssignmentDetailScreen(
                  store: store, assignmentId: state.pathParameters['id']!),
            ),
            GoRoute(
                path: '/sync',
                builder: (_, __) => SyncStatusScreen(store: store)),
            GoRoute(
                path: '/reminders',
                builder: (_, __) => ReminderSettingsScreen(store: store)),
            GoRoute(
                path: '/profile',
                builder: (_, __) => ProfileScreen(store: store)),
          ],
        ),
      ],
      redirect: (_, state) {
        final loggedIn = store.isAuthenticated;
        final loggingIn = state.matchedLocation == '/login';
        if (!loggedIn && !loggingIn) {
          return '/login';
        }
        if (loggedIn && loggingIn) {
          return '/assignments';
        }
        return null;
      },
    );

    return MaterialApp.router(
      title: '作业提醒',
      debugShowCheckedModeBanner: false,
      theme: StudyAssistantTheme.light,
      routerConfig: router,
    );
  }
}
