import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_backup_service.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final TextEditingController _restoreController = TextEditingController();

  String? _backupJson;
  String? _backupPath;
  String? _selectedExportDirectory;
  BackupSummary? _currentSummary;
  BackupSummary? _restoreSummary;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppBackupService.defaultBackupDirectoryPath().then((value) {
      if (!mounted) return;
      setState(() => _selectedExportDirectory = value);
    });
    AppBackupService.buildCurrentSummary().then((value) {
      if (!mounted) return;
      setState(() => _currentSummary = value);
    });
  }

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  Future<void> _pickExportDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择备份导出目录',
    );
    if (path == null || path.isEmpty || !mounted) return;
    setState(() => _selectedExportDirectory = path);
    _showSnack('已选择导出目录');
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final json = await AppBackupService.buildBackupJson();
      final file = await AppBackupService.exportBackupFile(
        directoryPath: _selectedExportDirectory,
      );
      if (!mounted) return;
      final summary = await AppBackupService.buildCurrentSummary();
      setState(() {
        _backupJson = json;
        _backupPath = file.path;
        _selectedExportDirectory = file.parent.path;
        _currentSummary = summary;
      });
      _showSnack('备份已导出到 ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('导出失败: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyBackupJson() async {
    final json = _backupJson;
    if (json == null || json.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _showSnack('备份内容已复制');
  }

  Future<void> _copyBackupPath() async {
    final path = _backupPath ?? _selectedExportDirectory;
    if (path == null || path.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    _showSnack('路径已复制');
  }

  Future<void> _pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('读取备份文件失败', error: true);
      return;
    }

    try {
      final text = utf8.decode(bytes);
      final summary = AppBackupService.parseSummaryFromJson(text);
      _restoreController.text = text;
      setState(() => _restoreSummary = summary);
      _showSnack('已载入备份文件: ${file.name}');
    } catch (e) {
      _showSnack('解析备份文件失败: $e', error: true);
    }
  }

  Future<void> _restoreBackup() async {
    final json = _restoreController.text.trim();
    if (json.isEmpty) {
      _showSnack('请先选择备份文件或粘贴备份 JSON', error: true);
      return;
    }
    BackupSummary summary;
    try {
      summary = AppBackupService.parseSummaryFromJson(json);
    } catch (e) {
      _showSnack('解析备份摘要失败: $e', error: true);
      return;
    }
    final scheduleProvider = context.read<ScheduleProvider>();
    final themeProvider = context.read<ThemeProvider>();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('确认恢复'),
              content: Text(
                '恢复会覆盖当前本地数据。此操作不可撤销。\n\n'
                '学期数：${summary.semesterCount}\n'
                '临时安排：${summary.overrideCount}\n'
                '课前提醒：${summary.reminderEnabled ? '已开启' : '未开启'}\n'
                '上课自动静音：${summary.silenceEnabled ? '已开启' : '未开启'}',
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
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await AppBackupService.restoreFromJson(json);
      if (!mounted) return;

      await scheduleProvider.reloadFromStorage();
      await themeProvider.reloadFromStorage();
      final refreshedSummary = await AppBackupService.buildCurrentSummary();

      if (!mounted) return;
      setState(() {
        _currentSummary = refreshedSummary;
      });
      _showSnack('备份恢复成功');
    } catch (e) {
      if (!mounted) return;
      _showSnack('恢复失败: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与恢复'),
      ),
      body: IgnorePointer(
        ignoring: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                    const Text(
                      '会导出多学期课表、临时安排、提醒、同步、显示偏好和主题设置。',
                    ),
                    if (_currentSummary != null) ...[
                      const SizedBox(height: 12),
                      _buildSummaryPanel(
                        context,
                        title: '当前备份摘要',
                        summary: _currentSummary!,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.45),
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
                            _selectedExportDirectory ?? '正在读取默认目录...',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickExportDirectory,
                                icon: const Icon(Icons.folder_open_rounded),
                                label: const Text('选择导出目录'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _selectedExportDirectory == null
                                    ? null
                                    : _copyBackupPath,
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
                          onPressed: _exportBackup,
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('导出到该目录'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _backupJson == null ? null : _copyBackupJson,
                          icon: const Icon(Icons.copy_all_rounded),
                          label: const Text('复制备份内容'),
                        ),
                      ],
                    ),
                    if (_backupPath != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        '最近导出文件：$_backupPath',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
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
                          onPressed: _pickBackupFile,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('选择备份文件'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _restoreController.clear(),
                          icon: const Icon(Icons.clear_rounded),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _restoreController,
                      onChanged: (value) {
                        final text = value.trim();
                        if (text.isEmpty) {
                          setState(() => _restoreSummary = null);
                          return;
                        }
                        try {
                          setState(() {
                            _restoreSummary =
                                AppBackupService.parseSummaryFromJson(text);
                          });
                        } catch (_) {
                          setState(() => _restoreSummary = null);
                        }
                      },
                      minLines: 8,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '在这里粘贴备份 JSON ...',
                      ),
                    ),
                    if (_restoreSummary != null) ...[
                      const SizedBox(height: 12),
                      _buildSummaryPanel(
                        context,
                        title: '待恢复摘要',
                        summary: _restoreSummary!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _restoreBackup,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('恢复备份'),
                    ),
                  ],
                ),
              ),
            ),
            if (_backupJson != null) ...[
              const SizedBox(height: 16),
              Card(
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
                        _backupJson!,
                        style: const TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPanel(
    BuildContext context, {
    required String title,
    required BackupSummary summary,
  }) {
    final secondary = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.70);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
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
