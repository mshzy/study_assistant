import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/assignment_store.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key, required this.store});

  final AssignmentStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final lastSyncAt = store.lastSyncAt;
        final stale = lastSyncAt == null ||
            DateTime.now().difference(lastSyncAt).inHours >= 24;
        return RefreshIndicator(
          onRefresh: store.syncAssignments,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('本地同步',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('账号密码和作业数据只保存在本机，不会上传到任何服务器。',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('刷新时会用已保存的学习通账号密码获取作业。',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                      stale ? Icons.warning_amber : Icons.check_circle_outline),
                  title: Text(stale ? '建议刷新学习通作业' : '本地数据较新'),
                  subtitle: Text(lastSyncAt == null
                      ? '尚未同步'
                      : '上次同步：${DateFormat('M月d日 HH:mm', 'zh_CN').format(lastSyncAt)}'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: store.isLoading ? null : store.syncAssignments,
                icon: const Icon(Icons.sync),
                label: Text(store.isLoading ? '正在刷新...' : '刷新学习通作业'),
              ),
              if (store.error != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(store.error!)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
