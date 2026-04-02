import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_backup_service.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';
import '../widgets/backup_restore_sections.dart';

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

  void _handleRestoreInputChanged(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      setState(() => _restoreSummary = null);
      return;
    }
    try {
      setState(() {
        _restoreSummary = AppBackupService.parseSummaryFromJson(text);
      });
    } catch (_) {
      setState(() => _restoreSummary = null);
    }
  }

  void _clearRestoreInput() {
    _restoreController.clear();
    setState(() => _restoreSummary = null);
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

    final confirmed = await showRestoreBackupConfirmDialog(
      context,
      summary: summary,
    );
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
      appBar: AppBar(title: const Text('备份与恢复')),
      body: IgnorePointer(
        ignoring: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BackupExportCard(
              currentSummary: _currentSummary,
              selectedExportDirectory: _selectedExportDirectory,
              onPickExportDirectory: _pickExportDirectory,
              onCopyBackupPath: _copyBackupPath,
              onExportBackup: _exportBackup,
              onCopyBackupJson: _copyBackupJson,
              backupJson: _backupJson,
              backupPath: _backupPath,
            ),
            const SizedBox(height: 16),
            BackupRestoreCard(
              restoreController: _restoreController,
              restoreSummary: _restoreSummary,
              onPickBackupFile: _pickBackupFile,
              onClear: _clearRestoreInput,
              onRestoreChanged: _handleRestoreInputChanged,
              onRestoreBackup: _restoreBackup,
            ),
            if (_backupJson != null) ...[
              const SizedBox(height: 16),
              RecentBackupJsonCard(backupJson: _backupJson!),
            ],
          ],
        ),
      ),
    );
  }
}
