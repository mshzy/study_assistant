import 'package:flutter/material.dart';

import '../services/assignment_store.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key, required this.store});

  final AssignmentStore store;

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final Set<int> _offsets = {1440, 180, 30};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('提醒设置',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        for (final item in const {
          1440: '提前 1 天',
          180: '提前 3 小时',
          30: '提前 30 分钟',
          10: '提前 10 分钟'
        }.entries)
          CheckboxListTile(
            value: _offsets.contains(item.key),
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _offsets.add(item.key);
              } else {
                _offsets.remove(item.key);
              }
            }),
            title: Text(item.value),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _offsets.isEmpty
              ? null
              : () => widget.store.saveReminderRule(_offsets.toList()),
          icon: const Icon(Icons.save),
          label: const Text('保存提醒规则'),
        ),
      ],
    );
  }
}
