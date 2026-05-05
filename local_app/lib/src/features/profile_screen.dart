import 'package:flutter/material.dart';

import '../services/assignment_store.dart';
import '../services/external_link_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.store});

  static const _githubUrl = 'https://github.com/mshzy/study_assistant';

  final AssignmentStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('我的',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(store.account ?? '学习通账号'),
                subtitle: const Text('凭证仅保存在本机安全存储中'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('本地数据'),
                subtitle: Text('${store.assignments.length} 条作业记录'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('关于应用'),
                    subtitle: Text(
                        '版权归 HY 所有\n微信：HY676-\n开源协议：MIT License\n允许使用、修改和分发，需保留版权与许可声明'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('GitHub 源码'),
                    subtitle: const Text('github.com/mshzy/study_assistant'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openGithub(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: store.logout,
              icon: const Icon(Icons.logout),
              label: const Text('清除本地数据并退出'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openGithub(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ExternalLinkService().openUrl(_githubUrl);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('无法打开 GitHub 链接，请检查浏览器或网络')),
      );
    }
  }
}
