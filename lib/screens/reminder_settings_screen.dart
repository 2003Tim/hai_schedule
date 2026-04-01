import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/class_reminder_service.dart';
import '../services/class_silence_service.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';

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

  Widget _buildGlassCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeProvider.glassPanelStrongFill(brightness, strength: 0.70),
                themeProvider.glassPanelFill(brightness, strength: 0.62),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: themeProvider.glassOutline(brightness, strength: 0.76),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.12 : 0.04,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
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

  Widget _buildPreviewTile(ReminderPreviewItem item) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.alarm_rounded, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.courseName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.dateLabel}  ${item.timeRange}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                if (item.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.location.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(item.remindAt),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '提前 ${item.leadMinutes} 分钟',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline_rounded, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    ReminderSnapshot snapshot,
    bool isDesktop,
    String reminderModeText,
  ) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '提醒状态',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.settings.enabled
                          ? isDesktop
                              ? '${snapshot.settings.leadTime.label} · 桌面预览'
                              : snapshot.settings.leadTime.label
                          : '当前已关闭',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _isApplyingReminder ? null : _rebuildNow,
                icon:
                    _isApplyingReminder
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isDesktop ? '刷新预览' : '重建'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.settings.enabled
                ? isDesktop
                    ? '已生成 ${snapshot.scheduledCount} 条未来提醒预览'
                    : '已生成 ${snapshot.scheduledCount} 条未来提醒'
                : isDesktop
                ? '选择提醒时间后，桌面端会按课表生成未来 7 天提醒预览'
                : '选择提醒时间后，系统会按课表生成未来 7 天提醒',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            '上次刷新：${_formatTime(snapshot.lastBuildTime)}\n覆盖到：${_formatTime(snapshot.horizonEnd)}\n模式：$reminderModeText',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    ReminderSnapshot snapshot,
  ) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '未来提醒预览',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '这里会根据当前课表、临时安排和作息时间，预览未来 7 天将会触发的提醒点位。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          if (_previewItems.isEmpty)
            Text(
              snapshot.settings.enabled
                  ? '当前预览窗口内没有可提醒课程。'
                  : '先选择一个提醒时间，桌面端就会在这里生成对应预览。',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            )
          else ...[
            ..._previewItems.take(8).map(_buildPreviewTile),
            if (_previewItems.length > 8)
              Text(
                '另外还有 ${_previewItems.length - 8} 条提醒预览未展开显示。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSilenceCard(
    BuildContext context,
    ClassSilenceSnapshot silenceSnapshot,
  ) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.do_not_disturb_on_total_silence_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '上课自动静音',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !silenceSnapshot.supported
                          ? '当前平台暂不支持'
                          : silenceSnapshot.settings.enabled
                          ? '上课时自动静音，下课后恢复原状态'
                          : '当前已关闭',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: silenceSnapshot.settings.enabled,
                onChanged:
                    !silenceSnapshot.supported || _isApplyingSilence
                        ? null
                        : _toggleClassSilence,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!silenceSnapshot.supported)
            Text(
              'Windows 端暂不支持直接控制系统免打扰，但课前提醒预览、作息设置和临时安排仍然会正常参与桌面端展示。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          if (silenceSnapshot.supported) ...[
            Text(
              silenceSnapshot.policyAccessGranted
                  ? '已安排 ${silenceSnapshot.scheduledCount} 条未来静音时段'
                  : '需要系统免打扰权限才能自动切换静音',
              style: const TextStyle(fontSize: 14),
            ),
            if (!silenceSnapshot.policyAccessGranted) ...[
              const SizedBox(height: 8),
              Text(
                ClassSilenceService.permissionHelpText(),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
            if (silenceSnapshot.policyAccessGranted) ...[
              const SizedBox(height: 8),
              Text(
                '如果你用的是小米/HyperOS，建议同时打开自启动，并把电池策略改成“不限制”，否则系统可能会延迟静音切换或恢复。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '上次生成：${_formatTime(silenceSnapshot.lastBuildTime)}\n覆盖到：${_formatTime(silenceSnapshot.horizonEnd)}',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed:
                      _isApplyingSilence || !silenceSnapshot.settings.enabled
                          ? null
                          : _rebuildClassSilenceNow,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重建'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isApplyingSilence
                          ? null
                          : () async {
                            final opened =
                                await ClassSilenceService.openPolicyAccessSettings();
                            await _refresh();
                            if (!mounted) return;
                            if (!opened) {
                              _showSnack('未能直接打开授权页面，请按说明手动授权', error: true);
                            }
                          },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: Text(
                    silenceSnapshot.policyAccessGranted ? '系统免打扰权限' : '去授权',
                  ),
                ),
                if (silenceSnapshot.policyAccessGranted)
                  FilledButton.tonalIcon(
                    onPressed:
                        _isRunningSilenceTest ? null : _startClassSilenceTest,
                    icon: const Icon(Icons.volume_off_rounded, size: 18),
                    label: const Text('测试静音'),
                  ),
                if (silenceSnapshot.policyAccessGranted)
                  OutlinedButton.icon(
                    onPressed:
                        _isRunningSilenceTest ? null : _restoreClassSilenceNow,
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    label: const Text('立即恢复'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadTimeCard(BuildContext context, bool isDesktop) {
    final snapshot =
        _snapshot ??
        const ReminderSnapshot(
          settings: ReminderSettings(leadTime: ReminderLeadTimeOption.off),
        );

    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '提前多久提醒',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isDesktop
                ? 'Windows 端会保存提醒策略，并实时生成未来 7 天提醒预览；同一套作息时间和临时安排逻辑会继续复用。'
                : '本地课前提醒会持续复用当前课表、作息时间和临时安排数据。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children:
                ReminderLeadTimeOption.values
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ReminderLeadOptionTile(
                          option: option,
                          selected: snapshot.settings.leadTime == option,
                          busy: _isApplyingReminder,
                          onTap: () => _applyLeadTime(option),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context, bool isDesktop) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '说明',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (isDesktop)
            _buildTipItem('Windows 端当前提供提醒策略保存与未来 7 天预览，不直接发送系统通知。'),
          _buildTipItem('提醒时间来自当前课表和学校作息时间配置。'),
          _buildTipItem('登录刷新、手动导入、自动同步成功后，提醒会自动重建。'),
          _buildTipItem('为了避免系统提醒数量过多，当前只滚动生成未来 7 天提醒。'),
          _buildTipItem('没有课程时不会报错，导入课表后会自动补齐提醒。'),
          _buildTipItem('自动静音仅在 Android 生效，需要系统免打扰权限。'),
          _buildTipItem('如果你临时手动改了铃声模式，可以用“立即恢复”回到自动静音保存的原状态。'),
        ],
      ),
    );
  }

  Widget _buildSectionColumn(List<Widget> sections, {double spacing = 14}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index],
          if (index != sections.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
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

    final statusCard = _buildStatusCard(
      context,
      snapshot,
      isDesktop,
      reminderModeText,
    );
    final previewCard = _buildPreviewCard(context, snapshot);
    final silenceCard = _buildSilenceCard(context, silenceSnapshot);
    final leadTimeCard = _buildLeadTimeCard(context, isDesktop);
    final tipsCard = _buildTipsCard(context, isDesktop);

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
                    Expanded(flex: 9, child: _buildSectionColumn([silenceCard])),
                  ],
                ),
                const SizedBox(height: 14),
                tipsCard,
              ] else ...[
                statusCard,
                if (isDesktop) ...[
                  const SizedBox(height: 14),
                  previewCard,
                ],
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

class _ReminderLeadOptionTile extends StatelessWidget {
  const _ReminderLeadOptionTile({
    required this.option,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final ReminderLeadTimeOption option;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        option == ReminderLeadTimeOption.off
            ? '关闭所有课前提醒'
            : '课程开始前 ${option.minutes} 分钟提醒你';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.10)
                    : theme.colorScheme.surface.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.46)
                      : theme.colorScheme.outline.withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withValues(
                                alpha: 0.55,
                              ),
                      width: selected ? 6 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.64,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
