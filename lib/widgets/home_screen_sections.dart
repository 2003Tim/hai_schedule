import 'package:flutter/material.dart';

import '../services/auto_sync_service.dart';
import '../services/schedule_provider.dart';
import 'daily_schedule_view.dart';
import 'home_day_selector.dart';
import 'home_empty_state.dart';
import 'home_next_lesson_card.dart';
import 'schedule_background.dart';
import 'schedule_grid.dart';
import 'swipeable_daily_schedule_view.dart';
import 'swipeable_schedule_view.dart';
import 'week_selector.dart';

enum HomeMenuAction {
  syncCenter,
  semesterManagement,
  reminderSettings,
  schoolTimeSettings,
  scheduleOverrides,
  themeSettings,
  backupRestore,
  toggleNonCurrent,
  toggleDays,
  currentWeek,
  loginFetch,
  manualImport,
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
  });

  final ScheduleProvider provider;
  final AutoSyncSnapshot? syncSnapshot;
  final ValueChanged<HomeMenuAction> onSelected;
  final String Function(String code) formatSemesterCode;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HomeMenuAction>(
      icon: const Icon(Icons.more_vert, size: 22),
      onSelected: onSelected,
      itemBuilder: (context) {
        final currentSemesterCode = provider.currentSemesterCode;
        return [
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.syncCenter,
            child: _HomeMenuTile(
              leading: const Icon(Icons.sync_rounded, size: 20),
              title: '课表同步',
              subtitle:
                  syncSnapshot?.lastFetchTime != null
                      ? '上次：${AutoSyncService.formatDateTime(syncSnapshot!.lastFetchTime)}'
                      : null,
            ),
          ),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.semesterManagement,
            child: _HomeMenuTile(
              leading: const Icon(Icons.school_outlined, size: 20),
              title: '学期管理',
              subtitle:
                  currentSemesterCode == null
                      ? '新建、切换或删除学期'
                      : formatSemesterCode(currentSemesterCode),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.reminderSettings,
            child: _HomeMenuTile(
              leading: Icon(Icons.notifications_active_outlined, size: 20),
              title: '课前提醒',
            ),
          ),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.schoolTimeSettings,
            child: _HomeMenuTile(
              leading: Icon(Icons.schedule_outlined, size: 20),
              title: '作息时间设置',
            ),
          ),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.scheduleOverrides,
            child: _HomeMenuTile(
              leading: const Icon(Icons.edit_calendar_outlined, size: 20),
              title: '临时安排',
              subtitle:
                  provider.overrides.isEmpty
                      ? null
                      : '${provider.overrides.length} 条记录',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.themeSettings,
            child: _HomeMenuTile(
              leading: Icon(Icons.palette_outlined, size: 20),
              title: '主题设置',
            ),
          ),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.backupRestore,
            child: _HomeMenuTile(
              leading: Icon(Icons.backup_outlined, size: 20),
              title: '备份与恢复',
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.toggleNonCurrent,
            child: _HomeMenuTile(
              leading: Icon(
                provider.showNonCurrentWeek
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 20,
              ),
              title: provider.showNonCurrentWeek ? '隐藏非本周课程' : '显示非本周课程',
            ),
          ),
          PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.toggleDays,
            child: _HomeMenuTile(
              leading: const Icon(Icons.view_week_rounded, size: 20),
              title: provider.displayDays == 7 ? '仅显示工作日' : '显示全部 7 天',
            ),
          ),
          const PopupMenuItem<HomeMenuAction>(
            value: HomeMenuAction.currentWeek,
            child: _HomeMenuTile(
              leading: Icon(Icons.today_rounded, size: 20),
              title: '回到本周',
            ),
          ),
        ];
      },
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
    required this.onManualImport,
    required this.wrapScheduleSemantics,
  });

  final ScheduleProvider provider;
  final bool showDayView;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final VoidCallback onLoginFetch;
  final VoidCallback onManualImport;
  final Widget Function(Widget child, String label) wrapScheduleSemantics;

  @override
  Widget build(BuildContext context) {
    return ScheduleBackground(
      maxBlurSigma: 10,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: WeekSelector(
                currentWeek: provider.currentWeek,
                selectedWeek: provider.selectedWeek,
                totalWeeks: provider.weekCalc.totalWeeks,
                onWeekSelected: provider.selectWeek,
              ),
            ),
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
            const HomeNextLessonCard(),
            Expanded(
              child:
                  provider.courses.isEmpty
                      ? HomeEmptyState(
                        onLoginFetch: onLoginFetch,
                        onManualImport: onManualImport,
                      )
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

class _HomeMenuTile extends StatelessWidget {
  const _HomeMenuTile({
    required this.leading,
    required this.title,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle:
          subtitle == null
              ? null
              : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
