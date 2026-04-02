import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/class_reminder_service.dart';
import '../services/class_silence_service.dart';
import '../services/schedule_provider.dart';
import '../widgets/reminder_settings_sections.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  ReminderSnapshot? _snapshot;
  ClassSilenceSnapshot? _silenceSnapshot;
  List<ReminderPreviewItem> _previewItems = const <ReminderPreviewItem>[];

  bool _isApplyingReminder = false;
  bool _isApplyingSilence = false;
  bool _isRunningSilenceTest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _messengerKey.currentState?.clearSnackBars();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final provider = context.read<ScheduleProvider>();
    final snapshot = await ClassReminderService.loadSnapshot();
    final silenceSnapshot = await ClassSilenceService.loadSnapshot();
    final previewItems = await ClassReminderService.buildPreview(
      courses: provider.courses,
      overrides: provider.overrides,
      weekCalc: provider.weekCalc,
      timeConfig: provider.timeConfig,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _silenceSnapshot = silenceSnapshot;
      _previewItems = previewItems;
    });
  }

  Future<void> _applyLeadTime(ReminderLeadTimeOption option) async {
    if (_isApplyingReminder) return;
    final provider = context.read<ScheduleProvider>();

    setState(() => _isApplyingReminder = true);
    try {
      final result = await ClassReminderService.updateLeadTime(
        option: option,
        courses: provider.courses,
        overrides: provider.overrides,
        weekCalc: provider.weekCalc,
        timeConfig: provider.timeConfig,
      );
      await _refresh();
      if (!mounted) return;
      _showSnack(result.message, error: !result.notificationsGranted);
    } catch (e) {
      if (!mounted) return;
      _showSnack('更新课前提醒失败: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _isApplyingReminder = false);
      }
    }
  }

  Future<void> _rebuildNow() async {
    if (_isApplyingReminder) return;
    final provider = context.read<ScheduleProvider>();

    setState(() => _isApplyingReminder = true);
    try {
      final result = await ClassReminderService.rebuildForSchedule(
        courses: provider.courses,
        overrides: provider.overrides,
        weekCalc: provider.weekCalc,
        timeConfig: provider.timeConfig,
      );
      await _refresh();
      if (!mounted) return;
      _showSnack(result.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('重建课前提醒失败: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _isApplyingReminder = false);
      }
    }
  }

  Future<void> _toggleClassSilence(bool enabled) async {
    if (_isApplyingSilence) return;
    final provider = context.read<ScheduleProvider>();

    setState(() => _isApplyingSilence = true);
    try {
      final result = await ClassSilenceService.updateEnabled(
        enabled: enabled,
        courses: provider.courses,
        overrides: provider.overrides,
        weekCalc: provider.weekCalc,
        timeConfig: provider.timeConfig,
      );
      await _refresh();
      if (!mounted) return;
      _showSnack(result.message, error: !result.policyAccessGranted && enabled);
    } catch (_) {
      if (!mounted) return;
      _showSnack('更新自动静音失败，请重试', error: true);
    } finally {
      if (mounted) {
        setState(() => _isApplyingSilence = false);
      }
    }
  }

  Future<void> _rebuildClassSilenceNow() async {
    if (_isApplyingSilence) return;
    final provider = context.read<ScheduleProvider>();

    setState(() => _isApplyingSilence = true);
    try {
      final result = await ClassSilenceService.rebuildForSchedule(
        courses: provider.courses,
        overrides: provider.overrides,
        weekCalc: provider.weekCalc,
        timeConfig: provider.timeConfig,
      );
      await _refresh();
      if (!mounted) return;
      _showSnack(result.message, error: !result.policyAccessGranted);
    } catch (_) {
      if (!mounted) return;
      _showSnack('重建自动静音失败，请重试', error: true);
    } finally {
      if (mounted) {
        setState(() => _isApplyingSilence = false);
      }
    }
  }

  Future<void> _openPolicyAccessSettings() async {
    final opened = await ClassSilenceService.openPolicyAccessSettings();
    await _refresh();
    if (!mounted) return;
    if (!opened) {
      _showSnack('未能直接打开授权页面，请按说明手动授权', error: true);
    }
  }

  Future<void> _startClassSilenceTest() async {
    if (_isRunningSilenceTest) return;
    setState(() => _isRunningSilenceTest = true);
    try {
      final message = await ClassSilenceService.startManualTest();
      if (!mounted) return;
      _showSnack(
        message,
        error: message.contains('失败') || message.contains('缺少'),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('测试静音失败，请重试', error: true);
    } finally {
      if (mounted) {
        setState(() => _isRunningSilenceTest = false);
      }
    }
  }

  Future<void> _restoreClassSilenceNow() async {
    if (_isRunningSilenceTest) return;
    setState(() => _isRunningSilenceTest = true);
    try {
      final message = await ClassSilenceService.restoreNow();
      if (!mounted) return;
      _showSnack(message, error: message.contains('失败'));
    } catch (_) {
      if (!mounted) return;
      _showSnack('恢复静音状态失败，请重试', error: true);
    } finally {
      if (mounted) {
        setState(() => _isRunningSilenceTest = false);
      }
    }
  }

  void _showSnack(String text, {bool error = false}) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.removeCurrentSnackBar();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: error ? 2200 : 1600),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        _snapshot ??
        const ReminderSnapshot(
          settings: ReminderSettings(leadTime: ReminderLeadTimeOption.off),
        );
    final silenceSnapshot =
        _silenceSnapshot ??
        const ClassSilenceSnapshot(
          settings: ClassSilenceSettings(enabled: false),
          supported: false,
          policyAccessGranted: false,
        );
    final isDesktop = !Platform.isAndroid;
    final isWideDesktop =
        isDesktop && MediaQuery.of(context).size.width >= 1180;
    final reminderModeText =
        isDesktop
            ? '桌面预览模式，不直接发送系统通知'
            : snapshot.exactAlarmEnabled
            ? '精准提醒'
            : '省电模式';

    final statusCard = ReminderStatusCard(
      snapshot: snapshot,
      isDesktop: isDesktop,
      reminderModeText: reminderModeText,
      isApplyingReminder: _isApplyingReminder,
      onRebuild: _rebuildNow,
      formatTime: _formatTime,
    );
    final previewCard = ReminderPreviewCard(
      snapshot: snapshot,
      previewItems: _previewItems,
      formatTime: _formatTime,
    );
    final silenceCard = ReminderSilenceCard(
      snapshot: silenceSnapshot,
      isApplyingSilence: _isApplyingSilence,
      isRunningSilenceTest: _isRunningSilenceTest,
      onToggleEnabled: _toggleClassSilence,
      onRebuild: _rebuildClassSilenceNow,
      onOpenPolicySettings: _openPolicyAccessSettings,
      onStartManualTest: _startClassSilenceTest,
      onRestoreNow: _restoreClassSilenceNow,
      formatTime: _formatTime,
    );
    final leadTimeCard = ReminderLeadTimeCard(
      snapshot: snapshot,
      isDesktop: isDesktop,
      isApplyingReminder: _isApplyingReminder,
      onSelectLeadTime: _applyLeadTime,
    );
    final tipsCard = ReminderTipsCard(isDesktop: isDesktop);

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('课前提醒')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            children: [
              if (isWideDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: statusCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 9, child: leadTimeCard),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: previewCard),
                    const SizedBox(width: 14),
                    Expanded(flex: 9, child: silenceCard),
                  ],
                ),
                const SizedBox(height: 14),
                tipsCard,
              ] else ...[
                statusCard,
                if (isDesktop) ...[const SizedBox(height: 14), previewCard],
                const SizedBox(height: 14),
                silenceCard,
                const SizedBox(height: 14),
                leadTimeCard,
                const SizedBox(height: 14),
                tipsCard,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
