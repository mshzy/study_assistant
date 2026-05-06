import 'package:flutter/material.dart';

import '../services/assignment_store.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key, required this.store});

  final AssignmentStore store;

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  static const _presetOffsets = {
    1440: '提前 1 天',
    180: '提前 3 小时',
    30: '提前 30 分钟',
    10: '提前 10 分钟',
  };

  final _customController = TextEditingController();
  final Set<int> _offsets = {};
  String _customUnit = '分钟';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _offsets.addAll(widget.store.reminderOffsetsMinutes);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customOffsets =
        _offsets.where((item) => !_presetOffsets.containsKey(item)).toList()
          ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '提醒设置',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '保存后会重新安排所有未完成作业的本地通知',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final item in _presetOffsets.entries)
                  CheckboxListTile(
                    value: _offsets.contains(item.key),
                    onChanged: (checked) => _toggleOffset(item.key, checked),
                    title: Text(item.value),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '自定义提醒',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '输入时间',
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _customUnit,
              items: const [
                DropdownMenuItem(value: '分钟', child: Text('分钟')),
                DropdownMenuItem(value: '小时', child: Text('小时')),
                DropdownMenuItem(value: '天', child: Text('天')),
              ],
              onChanged: (value) => setState(() {
                _customUnit = value ?? _customUnit;
              }),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _addCustomOffset, child: const Text('添加')),
          ],
        ),
        if (customOffsets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final offset in customOffsets)
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(_labelFor(offset)),
                    trailing: IconButton(
                      onPressed: () => setState(() => _offsets.remove(offset)),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _offsets.isEmpty || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? '保存中' : '保存提醒规则'),
        ),
      ],
    );
  }

  void _toggleOffset(int offset, bool? checked) {
    setState(() {
      if (checked ?? false) {
        _offsets.add(offset);
      } else {
        _offsets.remove(offset);
      }
    });
  }

  void _addCustomOffset() {
    final value = int.tryParse(_customController.text.trim());
    if (value == null || value <= 0) {
      _showMessage('请输入大于 0 的时间');
      return;
    }
    final minutes = switch (_customUnit) {
      '天' => value * 1440,
      '小时' => value * 60,
      _ => value,
    };
    setState(() {
      _offsets.add(minutes);
      _customController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.store.saveReminderRule(_offsets.toList());
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    _showMessage('提醒时间已保存');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _labelFor(int offsetMinutes) {
    if (offsetMinutes % 1440 == 0) {
      return '提前 ${offsetMinutes ~/ 1440} 天';
    }
    if (offsetMinutes % 60 == 0) {
      return '提前 ${offsetMinutes ~/ 60} 小时';
    }
    return '提前 $offsetMinutes 分钟';
  }
}
