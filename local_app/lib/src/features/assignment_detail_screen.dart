import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/assignment_store.dart';

class AssignmentDetailScreen extends StatelessWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.store,
    required this.assignmentId,
  });

  final AssignmentStore store;
  final String assignmentId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final assignment = store.findAssignment(assignmentId);
        if (assignment == null) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => context.go('/assignments'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('返回主页'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/assignments'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回主页'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              assignment.courseName,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              assignment.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.event_available),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat(
                          'yyyy年M月d日 HH:mm',
                          'zh_CN',
                        ).format(assignment.deadlineAt),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(assignment.requirementsText),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await store.updateCompletion(assignment.id, true);
                if (context.mounted) {
                  context.go('/assignments');
                }
              },
              icon: const Icon(Icons.done),
              label: const Text('标记为已完成'),
            ),
          ],
        );
      },
    );
  }
}
