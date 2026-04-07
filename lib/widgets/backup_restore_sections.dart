import 'package:flutter/material.dart';

import 'package:hai_schedule/services/app_backup_service.dart';

Future<bool> showRestoreBackupConfirmDialog(
  BuildContext context, {
  required BackupSummary summary,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: const Text('确认恢复'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                '恢复会覆盖当前本地数据。此操作不可撤销。\n\n'
                '学期数：${summary.semesterCount}\n'
                '临时安排：${summary.overrideCount}\n'
                '课前提醒：${summary.reminderEnabled ? '已开启' : '未开启'}\n'
                '上课自动静音：${summary.silenceEnabled ? '已开启' : '未开启'}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('恢复'),
              ),
            ],
          );
        },
      ) ??
      false;
}

class BackupSummaryPanel extends StatelessWidget {
  const BackupSummaryPanel({
    super.key,
    required this.title,
    required this.summary,
  });

  final String title;
  final BackupSummary summary;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.70);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('学期数：${summary.semesterCount}'),
          Text('临时安排：${summary.overrideCount}'),
          Text('课前提醒：${summary.reminderEnabled ? '已开启' : '未开启'}'),
          Text('上课自动静音：${summary.silenceEnabled ? '已开启' : '未开启'}'),
          const SizedBox(height: 6),
          Text(
            [
              if (summary.hasSemesterData) '包含多学期课表',
              if (summary.hasOverrideData) '包含临时安排',
              if (summary.hasAutomationSettings) '包含自动化设置',
              if (summary.hasAppearanceSettings) '包含主题与外观设置',
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
      ),
    );
  }
}

class BackupExportCard extends StatelessWidget {
  const BackupExportCard({
    super.key,
    required this.currentSummary,
    required this.selectedExportDirectory,
    required this.onPickExportDirectory,
    required this.onCopyBackupPath,
    required this.onExportBackup,
    required this.onCopyBackupJson,
    required this.backupJson,
    required this.backupPath,
  });

  final BackupSummary? currentSummary;
  final String? selectedExportDirectory;
  final VoidCallback onPickExportDirectory;
  final VoidCallback onCopyBackupPath;
  final VoidCallback onExportBackup;
  final VoidCallback onCopyBackupJson;
  final String? backupJson;
  final String? backupPath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '导出备份',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('会导出多学期课表、临时安排、提醒、同步、显示偏好和主题设置。'),
            if (currentSummary != null) ...[
              const SizedBox(height: 12),
              BackupSummaryPanel(title: '当前备份摘要', summary: currentSummary!),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前导出目录',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    selectedExportDirectory ?? '正在读取默认目录...',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPickExportDirectory,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('选择导出目录'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            selectedExportDirectory == null
                                ? null
                                : onCopyBackupPath,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('复制目录路径'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onExportBackup,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('导出到该目录'),
                ),
                OutlinedButton.icon(
                  onPressed: backupJson == null ? null : onCopyBackupJson,
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('复制备份内容'),
                ),
              ],
            ),
            if (backupPath != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                '最近导出文件：$backupPath',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BackupRestoreCard extends StatelessWidget {
  const BackupRestoreCard({
    super.key,
    required this.restoreController,
    required this.restoreSummary,
    required this.onPickBackupFile,
    required this.onClear,
    required this.onRestoreChanged,
    required this.onRestoreBackup,
  });

  final TextEditingController restoreController;
  final BackupSummary? restoreSummary;
  final VoidCallback onPickBackupFile;
  final VoidCallback onClear;
  final ValueChanged<String> onRestoreChanged;
  final VoidCallback onRestoreBackup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '恢复备份',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('可以直接选择备份文件，或手动粘贴备份 JSON 内容。'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickBackupFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('选择备份文件'),
                ),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: restoreController,
              onChanged: onRestoreChanged,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '在这里粘贴备份 JSON ...',
              ),
            ),
            if (restoreSummary != null) ...[
              const SizedBox(height: 12),
              BackupSummaryPanel(title: '待恢复摘要', summary: restoreSummary!),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRestoreBackup,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('恢复备份'),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentBackupJsonCard extends StatelessWidget {
  const RecentBackupJsonCard({super.key, required this.backupJson});

  final String backupJson;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近导出的备份内容',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SelectableText(
              backupJson,
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
