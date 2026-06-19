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
        final today = _todayAssignments(assignments);
        final upcoming = assignments
            .where((item) => !today.contains(item))
            .toList(growable: false);
        return RefreshIndicator(
          onRefresh: store.syncAssignments,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '学习通作业提醒',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: store.isLoading ? null : store.syncAssignments,
                    icon: const Icon(Icons.notifications_none),
                    tooltip: '刷新作业',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _HeroBanner(),
              const SizedBox(height: 22),
              if (store.error != null) ...[
                _SyncHint(message: store.error!),
                const SizedBox(height: 12),
              ],
              if (assignments.isEmpty)
                _EmptyAssignments(isAuthenticated: store.isAuthenticated)
              else ...[
                _SectionHeader(
                  title: '今日待完成',
                  count: today.length,
                  action: '全部作业',
                ),
                const SizedBox(height: 10),
                for (final assignment in today.take(3))
                  _AssignmentCard(assignment: assignment, compactDate: false),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _SectionHeader(title: '近期作业'),
                  const SizedBox(height: 10),
                  for (final assignment in upcoming)
                    _AssignmentCard(assignment: assignment, compactDate: true),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  List<Assignment> _todayAssignments(List<Assignment> assignments) {
    final now = DateTime.now();
    final today = assignments
        .where(
          (item) =>
              item.deadlineAt.year == now.year &&
              item.deadlineAt.month == now.month &&
              item.deadlineAt.day == now.day,
        )
        .toList()
      ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
    if (today.isNotEmpty) {
      return today;
    }
    return ([...assignments]
          ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt)))
        .take(2)
        .toList();
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D7DFF), Color(0xFF46A3FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D7DFF).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -18,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 22,
            child: Icon(
              Icons.assignment_turned_in,
              color: Colors.white.withValues(alpha: 0.88),
              size: 58,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '不错过每一次作业',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '学习更高效 ✨',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
    this.action,
  });

  final String title;
  final int? count;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        const Spacer(),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: Color(0xFF8A94A6),
              fontWeight: FontWeight.w600,
            ),
          ),
        if (action != null)
          const Icon(Icons.chevron_right, color: Color(0xFF8A94A6), size: 18),
      ],
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
  const _AssignmentCard({
    required this.assignment,
    required this.compactDate,
  });

  final Assignment assignment;
  final bool compactDate;

  @override
  Widget build(BuildContext context) {
    final deadline = DateFormat('M月d日 HH:mm', 'zh_CN').format(
      assignment.deadlineAt,
    );
    final day = DateFormat('MM.dd', 'zh_CN').format(assignment.deadlineAt);
    final week = DateFormat('E', 'zh_CN').format(assignment.deadlineAt);
    final urgent =
        assignment.deadlineAt.difference(DateTime.now()).inHours <= 24;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/assignments/${assignment.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (compactDate) ...[
                  SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        Text(
                          day,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              week,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: urgent
                          ? const Color(0xFFFFEBE8)
                          : const Color(0xFFFFF2DC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      urgent ? Icons.priority_high : Icons.chevron_right,
                      color: urgent
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.secondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!compactDate)
                            Text(
                              urgent ? '今日截止' : '即将截止',
                              style: TextStyle(
                                color: urgent
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            compactDate ? _relativeDeadline() : '23:59 截止',
                            style: const TextStyle(
                              color: Color(0xFF8A94A6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        assignment.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.requirementsText.isEmpty
                            ? assignment.courseName
                            : assignment.requirementsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF3FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              child: Text(
                                '作业',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (!compactDate) ...[
                            const SizedBox(width: 8),
                            Text(
                              deadline,
                              style: const TextStyle(
                                color: Color(0xFF8A94A6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeDeadline() {
    final diff = assignment.deadlineAt.difference(DateTime.now());
    if (diff.inDays <= 0) {
      return '今天截止';
    }
    if (diff.inDays == 1) {
      return '明天截止';
    }
    return '${diff.inDays}天后截止';
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
            isAuthenticated ? '同步后，学习通和数你最灵的待完成作业都会显示在这里。' : '登录后，作业会出现在这里。',
          ),
        ],
      ),
    );
  }
}
