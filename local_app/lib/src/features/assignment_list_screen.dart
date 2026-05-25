import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../services/assignment_store.dart';

class AssignmentListScreen extends StatelessWidget {
  const AssignmentListScreen({super.key, required this.store});

  final AssignmentStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final assignments = store.visibleAssignments;
        return RefreshIndicator(
          onRefresh: store.syncAssignments,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '待完成作业',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${assignments.length} 项需要关注',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: store.isLoading ? null : store.syncAssignments,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新作业',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (store.error != null) ...[
                _SyncHint(message: store.error!),
                const SizedBox(height: 12),
              ],
              if (assignments.isEmpty)
                _EmptyAssignments(isAuthenticated: store.isAuthenticated)
              else
                ...assignments.map(
                  (assignment) => _AssignmentCard(assignment: assignment),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncHint extends StatelessWidget {
  const _SyncHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final deadline = DateFormat('M月d日 HH:mm', 'zh_CN').format(
      assignment.deadlineAt,
    );
    final urgent = assignment.deadlineAt.difference(DateTime.now()).inHours <= 24;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go('/assignments/${assignment.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: urgent
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 4),
                          Text(deadline),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAssignments extends StatelessWidget {
  const _EmptyAssignments({required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            isAuthenticated ? '现在没有待完成作业' : '登录后查看作业',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isAuthenticated
                ? '同步后，学习通和数你最灵的待完成作业都会显示在这里。'
                : '登录后，作业会出现在这里。',
          ),
        ],
      ),
    );
  }
}
