import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_version.dart';
import '../services/app_update_service.dart';
import '../services/assignment_store.dart';
import '../services/external_link_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    this.updateService,
    this.externalLinkService,
  });

  static const _githubUrl = 'https://github.com/mshzy/study_assistant';

  final AssignmentStore store;
  final AppUpdateService? updateService;
  final ExternalLinkService? externalLinkService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final courses = _topCourses(store.assignments);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHeader(
              displayName: store.profileDisplayName,
              avatarUrl: store.profileAvatarUrl,
              accountLabel: store.account ?? '未绑定账号',
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _CourseCard(courses: courses),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.add_circle_outline,
                          title: '添加平台账号',
                          subtitle: '继续绑定学习通或数你最灵账号',
                          onTap: () => context.go('/login?addPlatform=1'),
                        ),
                        _SettingsTile(
                          icon: Icons.notifications_none,
                          title: '提醒设置',
                          onTap: () => context.go('/reminders'),
                        ),
                        _SettingsTile(
                          icon: Icons.sync,
                          title: '同步学习通',
                          onTap: () => context.go('/sync'),
                        ),
                        _SettingsTile(
                          icon: Icons.cloud_queue,
                          title: '数据备份',
                          subtitle: '${store.assignments.length} 条作业记录保存在本机',
                          onTap: () =>
                              _showMessage(context, '当前数据仅本地保存，暂未开启云备份'),
                        ),
                        _SettingsTile(
                          icon: Icons.help_outline,
                          title: '帮助与反馈',
                          onTap: () => _showMessage(
                              context, '可以在 GitHub 提交 issue 或联系开发者'),
                        ),
                        _SettingsTile(
                          icon: Icons.info_outline,
                          title: '关于我们',
                          subtitle: 'HY · MIT License · v${AppVersion.display}',
                          onTap: () => _showAbout(context),
                        ),
                        _SettingsTile(
                          icon: Icons.system_update_alt,
                          title: '检查更新',
                          subtitle: '从 GitHub 自动检查最新 APK',
                          onTap: () => _checkForUpdates(context),
                        ),
                        _SettingsTile(
                          icon: Icons.code,
                          title: 'GitHub 源码',
                          subtitle: 'github.com/mshzy/study_assistant',
                          trailing: Icons.open_in_new,
                          onTap: () => _openGithub(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: store.logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: const BorderSide(color: Color(0xFFFFE0E0)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('退出登录'),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _topCourses(List<dynamic> assignments) {
    final names = <String>[];
    for (final assignment in assignments) {
      final name = assignment.courseName.toString();
      if (!names.contains(name)) {
        names.add(name);
      }
      if (names.length == 4) {
        break;
      }
    }
    if (names.isEmpty) {
      return const ['高等数学', '大学英语', '线性代数', '中国近现代史纲要'];
    }
    return names;
  }

  Future<void> _openGithub(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await (externalLinkService ?? ExternalLinkService()).openUrl(
      _githubUrl,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('无法打开 GitHub 链接，请检查浏览器或网络')),
      );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '学习通作业提醒',
      applicationVersion: AppVersion.display,
      applicationLegalese: '版权归 HY 所有\n开源协议：MIT License\n微信：HY676-',
      children: const [
        SizedBox(height: 8),
        Text('本应用用于本地同步学习通和数你最灵作业提醒，账号和作业数据仅保存在本机。'),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在检查更新...'),
        duration: Duration(seconds: 1),
      ),
    );
    try {
      final update = await (updateService ?? AppUpdateService()).checkForUpdate(
        currentVersionName: AppVersion.name,
        currentVersionCode: AppVersion.code,
      );
      if (!context.mounted) {
        return;
      }
      if (update == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('当前已经是最新版本')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('发现新版本 ${update.versionName}'),
            content: Text(
              [
                '安装包：${update.apkName}',
                if (update.releaseNotes.trim().isNotEmpty) '',
                if (update.releaseNotes.trim().isNotEmpty)
                  update.releaseNotes.trim(),
              ].join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('稍后'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final apkFile = await _downloadUpdateWithProgress(
                    context,
                    update,
                  );
                  if (apkFile == null) {
                    return;
                  }
                  if (context.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('安装包已下载，正在打开系统安装器')),
                    );
                  }
                  final opened =
                      await (externalLinkService ?? ExternalLinkService())
                          .installApk(apkFile.path);
                  if (!opened && context.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('无法打开系统安装器')),
                    );
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('下载并安装'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      navigator.popUntil((route) => route.isFirst || route.isCurrent);
      messenger.showSnackBar(
        const SnackBar(content: Text('检查更新失败，请稍后再试')),
      );
    }
  }

  Future<File?> _downloadUpdateWithProgress(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ValueNotifier<_DownloadProgress>(
      const _DownloadProgress(receivedBytes: 0, totalBytes: 0),
    );
    File? apkFile;
    Object? downloadError;
    Future<void>? downloadFuture;
    var started = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) {
        if (!started) {
          started = true;
          downloadFuture = (updateService ?? AppUpdateService()).downloadApk(
            update,
            onProgress: (received, total) {
              notifier.value = _DownloadProgress(
                receivedBytes: received,
                totalBytes: total,
              );
            },
          ).then((file) {
            apkFile = file;
          }).catchError((error) {
            downloadError = error;
          }).whenComplete(() {
            if (progressContext.mounted) {
              Navigator.of(progressContext).pop();
            }
          });
        }
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('正在下载更新包'),
            content: ValueListenableBuilder<_DownloadProgress>(
              valueListenable: notifier,
              builder: (context, progress, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress.hasTotal ? progress.ratio : null,
                    ),
                    const SizedBox(height: 12),
                    Text(progress.label),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    await downloadFuture;
    notifier.dispose();

    if (downloadError != null) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('下载更新包失败，请稍后再试')),
        );
      }
      return null;
    }
    return apkFile;
  }
}

class _DownloadProgress {
  const _DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  bool get hasTotal => totalBytes > 0;

  double? get ratio {
    if (!hasTotal) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  String get label {
    if (!hasTotal) {
      return '已下载 ${_formatBytes(receivedBytes)}';
    }
    final percent = ((ratio ?? 0) * 100).clamp(0, 100).round();
    return '$percent% · ${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.accountLabel,
  });

  final String displayName;
  final String? avatarUrl;
  final String accountLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = _profileAvatarUrl(avatarUrl);
    final avatarHeaders = _profileAvatarHeaders(resolvedAvatarUrl);
    return Container(
      height: 236,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E86FF), Color(0xFF62AEFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 48,
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 54,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: resolvedAvatarUrl == null
                        ? const _DefaultAvatar()
                        : Image.network(
                            key: ValueKey(resolvedAvatarUrl),
                            resolvedAvatarUrl,
                            headers: avatarHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _DefaultAvatar(),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        accountLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _profileAvatarUrl(String? avatarUrl) {
  final trimmed = avatarUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return trimmed;
  }
  if (uri.host.toLowerCase() != 'photo.chaoxing.com') {
    return trimmed;
  }
  final query = Map<String, String>.from(uri.queryParameters)
    ..['psize'] = '160_160c'
    ..['ext'] = 'png';
  return uri.replace(scheme: 'https', queryParameters: query).toString();
}

Map<String, String>? _profileAvatarHeaders(String? avatarUrl) {
  final uri = Uri.tryParse(avatarUrl ?? '');
  final host = uri?.host.toLowerCase();
  if (host == null ||
      (host != 'photo.chaoxing.com' && !host.endsWith('.cldisk.com'))) {
    return null;
  }
  return const {
    'Referer': 'https://photo.chaoxing.com/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
  };
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person,
      color: Color(0xFF2E86FF),
      size: 38,
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.courses});

  final List<String> courses;

  @override
  Widget build(BuildContext context) {
    final colors = const [
      Color(0xFF2F88FF),
      Color(0xFF2AC77B),
      Color(0xFF8A6CFF),
      Color(0xFFFF9F2E),
    ];
    final icons = const [
      Icons.functions,
      Icons.school_outlined,
      Icons.bar_chart,
      Icons.history_edu_outlined,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '我的课程',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '共 ${courses.length} 门课程',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF8A94A6)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < courses.length; i += 1)
                  Expanded(
                    child: _CourseShortcut(
                      title: courses[i],
                      icon: icons[i % icons.length],
                      color: colors[i % colors.length],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseShortcut extends StatelessWidget {
  const _CourseShortcut({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '设置',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          for (var i = 0; i < children.length; i += 1) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing = Icons.chevron_right,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2D3748), size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(trailing, color: const Color(0xFF9AA5B5)),
      onTap: onTap,
    );
  }
}
