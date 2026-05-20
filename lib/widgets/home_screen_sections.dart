import 'package:flutter/material.dart';

import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/daily_schedule_view.dart';
import 'package:hai_schedule/widgets/home_day_selector.dart';
import 'package:hai_schedule/widgets/home_empty_state.dart';
import 'package:hai_schedule/widgets/home_next_lesson_card.dart';
import 'package:hai_schedule/widgets/schedule_background.dart';
import 'package:hai_schedule/widgets/schedule_grid.dart';
import 'package:hai_schedule/widgets/swipeable_daily_schedule_view.dart';
import 'package:hai_schedule/widgets/swipeable_schedule_view.dart';
import 'package:hai_schedule/widgets/week_selector.dart';

enum HomeMenuAction {
  syncCenter,
  semesterManagement,
  reminderSettings,
  schoolTimeSettings,
  scheduleOverrides,
  themeSettings,
  toggleNonCurrent,
  toggleDays,
  currentWeek,
  loginFetch,
}

class HomeAppBarTitle extends StatelessWidget {
  const HomeAppBarTitle({
    super.key,
    required this.currentWeekText,
    this.semesterLabel,
  });

  final String currentWeekText;
  final String? semesterLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '海大课表',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          currentWeekText,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        if (semesterLabel != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              semesterLabel!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary.withValues(alpha: 0.90),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class HomeOverflowMenu extends StatelessWidget {
  const HomeOverflowMenu({
    super.key,
    required this.provider,
    required this.onSelected,
    required this.formatSemesterCode,
    this.syncSnapshot,
    this.showLabel = false,
  });

  final ScheduleProvider provider;
  final AutoSyncSnapshot? syncSnapshot;
  final ValueChanged<HomeMenuAction> onSelected;
  final String Function(String code) formatSemesterCode;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<HomeMenuAction>(
      tooltip: '更多设置',
      icon: showLabel ? null : const Icon(Icons.more_vert, size: 22),
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color:
          isDark
              ? colorScheme.surface.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.78),
      elevation: 8,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      itemBuilder: (context) {
        final currentSemesterCode = provider.currentSemesterCode;
        return [
          _buildGroupTitle(context, '数据管理'),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.syncCenter,
            child: _GlassMenuTile(
              icon: Icons.sync_rounded,
              title: '课表同步',
              subtitle:
                  syncSnapshot?.lastFetchTime != null
                      ? '上次：${AutoSyncService.formatDateTime(syncSnapshot!.lastFetchTime)}'
                      : null,
            ),
          ),
          if (provider.hasSyncedAtLeastOneSemester)
            PopupMenuItem<HomeMenuAction>(
              value: HomeMenuAction.semesterManagement,
              child: _GlassMenuTile(
                icon: Icons.school_outlined,
                title: '学期管理',
                subtitle:
                    currentSemesterCode == null
                        ? '新建、切换或删除学期'
                        : formatSemesterCode(currentSemesterCode),
              ),
            ),
          _buildGroupTitle(context, '偏好设置'),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.reminderSettings,
            child: _GlassMenuTile(
              icon: Icons.notifications_active_outlined,
              title: '课前提醒',
            ),
          ),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.schoolTimeSettings,
            child: _GlassMenuTile(
              icon: Icons.schedule_outlined,
              title: '作息时间设置',
            ),
          ),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.scheduleOverrides,
            child: _GlassMenuTile(
              icon: Icons.edit_calendar_outlined,
              title: '临时安排',
              subtitle:
                  provider.overrides.isEmpty
                      ? null
                      : '${provider.overrides.length} 条记录',
            ),
          ),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.themeSettings,
            child: _GlassMenuTile(icon: Icons.palette_outlined, title: '主题设置'),
          ),
          _buildGroupTitle(context, '快捷操作'),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.toggleNonCurrent,
            child: _GlassMenuTile(
              icon:
                  provider.showNonCurrentWeek
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
              title: provider.showNonCurrentWeek ? '隐藏非本周课程' : '显示非本周课程',
            ),
          ),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.toggleDays,
            child: _GlassMenuTile(
              icon: Icons.view_week_rounded,
              title: provider.displayDays == 7 ? '仅显示工作日' : '显示全部 7 天',
            ),
          ),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.currentWeek,
            child: _GlassMenuTile(icon: Icons.today_rounded, title: '回到今天'),
          ),
        ];
      },
      child:
          showLabel
              ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '更多设置',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.expand_more_rounded, size: 18),
                  ],
                ),
              )
              : null,
    );
  }

  static PopupMenuEntry<HomeMenuAction> _buildGroupTitle(
    BuildContext context,
    String title,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuItem<HomeMenuAction>(
      enabled: false,
      height: 36,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: isDark ? 0.45 : 0.48),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class HomeScheduleBody extends StatelessWidget {
  const HomeScheduleBody({
    super.key,
    required this.provider,
    required this.showDayView,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onLoginFetch,
    required this.wrapScheduleSemantics,
    this.navigationKey,
  });

  final ScheduleProvider provider;
  final bool showDayView;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final VoidCallback onLoginFetch;
  final Widget Function(Widget child, String label) wrapScheduleSemantics;
  final Key? navigationKey;

  @override
  Widget build(BuildContext context) {
    return ScheduleBackground(
      maxBlurSigma: 10,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            Padding(
              key: navigationKey,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: WeekSelector(
                currentWeek: provider.currentWeek,
                selectedWeek: provider.selectedWeek,
                totalWeeks: provider.weekCalc.totalWeeks,
                onWeekSelected: provider.selectWeek,
              ),
            ),
            HomeNextLessonCard(),
            if (showDayView)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HomeDaySelector(
                  displayDays: provider.displayDays,
                  selectedDay: selectedDay,
                  dateForWeekday:
                      (weekday) => provider.getDateForSlot(
                        provider.selectedWeek,
                        weekday,
                      ),
                  onSelected: onDaySelected,
                ),
              ),
            Expanded(
              child:
                  provider.courses.isEmpty
                      ? HomeEmptyState(onLoginFetch: onLoginFetch)
                      : showDayView
                      ? wrapScheduleSemantics(
                        SwipeableDailyScheduleView(
                          totalDays: provider.displayDays,
                          currentDay: selectedDay,
                          onDayChanged: onDaySelected,
                          dayBuilder: (weekday) {
                            return DailyScheduleView(
                              provider: provider,
                              week: provider.selectedWeek,
                              weekday: weekday,
                            );
                          },
                        ),
                        '日课表区域，可左右切换日期并滚动查看课程列表。',
                      )
                      : wrapScheduleSemantics(
                        SwipeableScheduleView(
                          totalWeeks: provider.weekCalc.totalWeeks,
                          currentWeek: provider.selectedWeek,
                          onWeekChanged: provider.selectWeek,
                          scheduleBuilder: (weekNumber) {
                            return ScheduleGrid(
                              provider: provider,
                              weekOverride: weekNumber,
                            );
                          },
                        ),
                        '周课表区域，可左右切换周次并上下滚动查看课程。',
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassMenuTile extends StatelessWidget {
  const _GlassMenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = colorScheme.onSurface;

    return Row(
      children: [
        // Icon with soft tinted background
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                    : colorScheme.primary.withValues(alpha: 0.08),
          ),
          child: Icon(
            icon,
            size: 19,
            color:
                isDark
                    ? onSurface.withValues(alpha: 0.72)
                    : colorScheme.primary.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.54),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
