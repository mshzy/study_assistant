import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../services/assignment_store.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.store});

  final AssignmentStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final assignments = store.visibleAssignments;
        final grouped = _groupByDate(assignments);
        final month = DateFormat('yyyy年M月', 'zh_CN').format(DateTime.now());
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '日历',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: store.syncAssignments,
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('筛选'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MonthCard(month: month, assignments: assignments),
            const SizedBox(height: 18),
            if (grouped.isEmpty)
              const _CalendarEmpty()
            else
              for (final entry in grouped.entries) ...[
                _DateHeader(date: entry.key),
                const SizedBox(height: 8),
                for (final assignment in entry.value)
                  _CalendarAssignmentTile(assignment: assignment),
                const SizedBox(height: 14),
              ],
          ],
        );
      },
    );
  }

  Map<DateTime, List<Assignment>> _groupByDate(List<Assignment> assignments) {
    final sorted = [...assignments]
      ..sort((a, b) => a.deadlineAt.compareTo(b.deadlineAt));
    final grouped = <DateTime, List<Assignment>>{};
    for (final item in sorted) {
      final key = DateTime(
        item.deadlineAt.year,
        item.deadlineAt.month,
        item.deadlineAt.day,
      );
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.assignments});

  final String month;
  final List<Assignment> assignments;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dueDays = assignments.map((item) => item.deadlineAt.day).toSet();
    final leading = firstDay.weekday % 7;
    final cells = <Widget>[
      for (final label in const ['日', '一', '二', '三', '四', '五', '六'])
        Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7C8796),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      for (var i = 0; i < leading; i += 1) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day += 1)
        _DayCell(
          day: day,
          selected: day == now.day,
          hasAssignment: dueDays.contains(day),
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.chevron_left, color: Color(0xFF7C8796)),
                Expanded(
                  child: Text(
                    month,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF7C8796)),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.hasAssignment,
  });

  final int day;
  final bool selected;
  final bool hasAssignment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colorScheme.primary : Colors.transparent,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF111827),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          if (hasAssignment)
            Positioned(
              bottom: 6,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : const Color(0xFFFF9F2E),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sameDay = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return Text(
      '${DateFormat('M月d日', 'zh_CN').format(date)} ${sameDay ? '今天' : DateFormat('E', 'zh_CN').format(date)}',
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _CalendarAssignmentTile extends StatelessWidget {
  const _CalendarAssignmentTile({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Text(
            DateFormat('HH:mm', 'zh_CN').format(assignment.deadlineAt),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w900,
                ),
          ),
          title: Text(
            assignment.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            assignment.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const _TypePill(label: '作业'),
          onTap: () => context.go('/assignments/${assignment.id}'),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text('暂无待完成作业'),
          ],
        ),
      ),
    );
  }
}
