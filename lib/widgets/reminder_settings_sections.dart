import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/class_silence_service.dart';
import 'package:hai_schedule/services/theme_provider.dart';

typedef ReminderAsyncVoidCallback = Future<void> Function();
typedef ReminderAsyncBoolCallback = Future<void> Function(bool value);
typedef ReminderLeadTimeCallback =
    Future<void> Function(ReminderLeadTimeOption option);
typedef ReminderTimeFormatter = String Function(DateTime? value);

class ReminderGlassCard extends StatelessWidget {
  const ReminderGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
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
}

class ReminderStatusCard extends StatelessWidget {
  const ReminderStatusCard({
    super.key,
    required this.snapshot,
    required this.isDesktop,
    required this.reminderModeText,
    required this.isApplyingReminder,
    required this.onRebuild,
    required this.formatTime,
  });

  final ReminderSnapshot snapshot;
  final bool isDesktop;
  final String reminderModeText;
  final bool isApplyingReminder;
  final ReminderAsyncVoidCallback onRebuild;
  final ReminderTimeFormatter formatTime;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ReminderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '提醒状态',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    isApplyingReminder
                        ? null
                        : () async {
                          await onRebuild();
                        },
                icon:
                    isApplyingReminder
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
            '上次刷新：${formatTime(snapshot.lastBuildTime)}\n'
            '覆盖到：${formatTime(snapshot.horizonEnd)}\n'
            '模式：$reminderModeText',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderPreviewCard extends StatelessWidget {
  const ReminderPreviewCard({
    super.key,
    required this.snapshot,
    required this.previewItems,
    required this.formatTime,
  });

  final ReminderSnapshot snapshot;
  final List<ReminderPreviewItem> previewItems;
  final ReminderTimeFormatter formatTime;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ReminderGlassCard(
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
              color: colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          if (previewItems.isEmpty)
            Text(
              snapshot.settings.enabled
                  ? '当前预览窗口内没有可提醒课程。'
                  : '先选择一个提醒时间，桌面端就会在这里生成对应预览。',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            )
          else ...[
            ...previewItems
                .take(8)
                .map(
                  (item) =>
                      _ReminderPreviewTile(item: item, formatTime: formatTime),
                ),
            if (previewItems.length > 8)
              Text(
                '另外还有 ${previewItems.length - 8} 条提醒预览未展开显示。',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class ReminderSilenceCard extends StatelessWidget {
  const ReminderSilenceCard({
    super.key,
    required this.snapshot,
    required this.isApplyingSilence,
    required this.isRunningSilenceTest,
    required this.onToggleEnabled,
    required this.onRebuild,
    required this.onOpenPolicySettings,
    required this.onStartManualTest,
    required this.onRestoreNow,
    required this.formatTime,
  });

  final ClassSilenceSnapshot snapshot;
  final bool isApplyingSilence;
  final bool isRunningSilenceTest;
  final ReminderAsyncBoolCallback onToggleEnabled;
  final ReminderAsyncVoidCallback onRebuild;
  final ReminderAsyncVoidCallback onOpenPolicySettings;
  final ReminderAsyncVoidCallback onStartManualTest;
  final ReminderAsyncVoidCallback onRestoreNow;
  final ReminderTimeFormatter formatTime;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ReminderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.do_not_disturb_on_total_silence_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '上课自动静音',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !snapshot.supported
                          ? '当前平台暂不支持'
                          : snapshot.settings.enabled
                          ? '上课时自动静音，下课后恢复原状态'
                          : '当前已关闭',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: snapshot.settings.enabled,
                onChanged:
                    !snapshot.supported || isApplyingSilence
                        ? null
                        : (value) async {
                          await onToggleEnabled(value);
                        },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!snapshot.supported)
            Text(
              'Windows 端暂不支持直接控制系统免打扰，但课前提醒预览、作息设置和临时安排仍然会正常参与桌面端展示。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          if (snapshot.supported) ...[
            Text(
              snapshot.policyAccessGranted
                  ? '已安排 ${snapshot.scheduledCount} 条未来静音时段'
                  : '需要系统免打扰权限才能自动切换静音',
              style: const TextStyle(fontSize: 14),
            ),
            if (!snapshot.policyAccessGranted) ...[
              const SizedBox(height: 8),
              Text(
                ClassSilenceService.permissionHelpText(),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
            if (snapshot.policyAccessGranted) ...[
              const SizedBox(height: 8),
              Text(
                '如果你用的是小米/HyperOS，建议同时打开自启动，并把电池策略改成“不限制”，否则系统可能会延迟静音切换或恢复。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '上次生成：${formatTime(snapshot.lastBuildTime)}\n'
              '覆盖到：${formatTime(snapshot.horizonEnd)}',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed:
                      isApplyingSilence || !snapshot.settings.enabled
                          ? null
                          : () async {
                            await onRebuild();
                          },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重建'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      isApplyingSilence
                          ? null
                          : () async {
                            await onOpenPolicySettings();
                          },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: Text(snapshot.policyAccessGranted ? '系统免打扰权限' : '去授权'),
                ),
                if (snapshot.policyAccessGranted)
                  FilledButton.tonalIcon(
                    onPressed:
                        isRunningSilenceTest
                            ? null
                            : () async {
                              await onStartManualTest();
                            },
                    icon: const Icon(Icons.volume_off_rounded, size: 18),
                    label: const Text('测试静音'),
                  ),
                if (snapshot.policyAccessGranted)
                  OutlinedButton.icon(
                    onPressed:
                        isRunningSilenceTest
                            ? null
                            : () async {
                              await onRestoreNow();
                            },
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
}

class ReminderLeadTimeCard extends StatelessWidget {
  const ReminderLeadTimeCard({
    super.key,
    required this.snapshot,
    required this.isDesktop,
    required this.isApplyingReminder,
    required this.onSelectLeadTime,
  });

  final ReminderSnapshot snapshot;
  final bool isDesktop;
  final bool isApplyingReminder;
  final ReminderLeadTimeCallback onSelectLeadTime;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ReminderGlassCard(
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
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children:
                ReminderLeadTimeOption.values
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ReminderLeadOptionTile(
                          option: option,
                          selected: snapshot.settings.leadTime == option,
                          busy: isApplyingReminder,
                          onTap: () async {
                            await onSelectLeadTime(option);
                          },
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class ReminderTipsCard extends StatelessWidget {
  const ReminderTipsCard({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final tips = <String>[
      if (isDesktop) 'Windows 端当前提供提醒策略保存与未来 7 天预览，不直接发送系统通知。',
      '提醒时间来自当前课表和学校作息时间配置。',
      '登录刷新、手动导入、自动同步成功后，提醒会自动重建。',
      '为了避免系统提醒数量过多，当前只滚动生成未来 7 天提醒。',
      '没有课程时不会报错，导入课表后会自动补齐提醒。',
      '自动静音仅在 Android 生效，需要系统免打扰权限。',
      '如果你临时手动改了铃声模式，可以用“立即恢复”回到自动静音保存的原状态。',
    ];

    return ReminderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '说明',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...tips.map((text) => _ReminderTipItem(text: text)),
        ],
      ),
    );
  }
}

class ReminderLeadOptionTile extends StatelessWidget {
  const ReminderLeadOptionTile({
    super.key,
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

class _ReminderPreviewTile extends StatelessWidget {
  const _ReminderPreviewTile({required this.item, required this.formatTime});

  final ReminderPreviewItem item;
  final ReminderTimeFormatter formatTime;

  @override
  Widget build(BuildContext context) {
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
                formatTime(item.remindAt),
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
}

class _ReminderTipItem extends StatelessWidget {
  const _ReminderTipItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
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
}
