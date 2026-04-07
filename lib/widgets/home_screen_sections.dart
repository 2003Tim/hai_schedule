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
import 'package:hai_schedule/widgets/adaptive_layout.dart';

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

  Widget _buildSchedulePane() {
    if (provider.courses.isEmpty) {
      return HomeEmptyState(
        onLoginFetch: onLoginFetch,
        onManualImport: onManualImport,
      );
    }

    if (showDayView) {
      return wrapScheduleSemantics(
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
      );
    }

    return wrapScheduleSemantics(
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
    );
  }

  Widget _buildControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
  }

  Widget _buildNarrowLayout({
    required Widget controls,
    required Widget schedulePane,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              const SizedBox(height: 6),
              controls,
              const HomeNextLessonCard(),
              Expanded(child: schedulePane),
            ],
          ),
        ),
      ),
    );
  }

  /// 平板宽屏布局：左侧 96dp 纵向周次侧边栏 + 右侧主内容区
  Widget _buildWideLayout({required double height}) {
    const sidebarWidth = 96.0;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 下一节课卡片横跨全宽，位于分栏上方 ──
            const HomeNextLessonCard(),
            // ── 左右分栏：侧边栏 + 课表主体 ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 左侧：纵向周次选择器 ──
                  SizedBox(
                    width: sidebarWidth,
                    child: _VerticalWeekSidebar(
                      currentWeek: provider.currentWeek,
                      selectedWeek: provider.selectedWeek,
                      totalWeeks: provider.weekCalc.totalWeeks,
                      onWeekSelected: provider.selectWeek,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── 右侧：课表主体（日视图或周视图）──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDayView) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                            child: HomeDaySelector(
                              displayDays: provider.displayDays,
                              selectedDay: selectedDay,
                              dateForWeekday: (weekday) =>
                                  provider.getDateForSlot(
                                provider.selectedWeek,
                                weekday,
                              ),
                              onSelected: onDaySelected,
                            ),
                          ),
                          Expanded(
                            child: wrapScheduleSemantics(
                              SwipeableDailyScheduleView(
                                totalDays: provider.displayDays,
                                currentDay: selectedDay,
                                onDayChanged: onDaySelected,
                                dayBuilder: (weekday) => DailyScheduleView(
                                  provider: provider,
                                  week: provider.selectedWeek,
                                  weekday: weekday,
                                ),
                              ),
                              '日课表区域，可左右切换日期并滚动查看课程列表。',
                            ),
                          ),
                        ] else
                          // 直接显示 ScheduleGrid，由侧边栏控制周次，无需 PageView 包裹
                          Expanded(
                            child: wrapScheduleSemantics(
                              ScheduleGrid(provider: provider),
                              '周课表区域，可上下滚动查看课程。',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCourses = provider.courses.isNotEmpty;

    return ScheduleBackground(
      maxBlurSigma: 10,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideLayout =
                hasCourses &&
                constraints.maxWidth >= 720 &&
                AdaptiveLayout.isTablet(context);

            if (isWideLayout) {
              return _buildWideLayout(height: constraints.maxHeight);
            }

            return _buildNarrowLayout(
              controls: _buildControls(),
              schedulePane: _buildSchedulePane(),
              height: constraints.maxHeight,
            );
          },
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

// ─────────────────────────────────────────────────────────────────────────────
// 平板宽屏专用：纵向周次侧边栏
// ─────────────────────────────────────────────────────────────────────────────

class _VerticalWeekSidebar extends StatefulWidget {
  const _VerticalWeekSidebar({
    required this.currentWeek,
    required this.selectedWeek,
    required this.totalWeeks,
    required this.onWeekSelected,
  });

  final int currentWeek;
  final int selectedWeek;
  final int totalWeeks;
  final ValueChanged<int> onWeekSelected;

  @override
  State<_VerticalWeekSidebar> createState() => _VerticalWeekSidebarState();
}

class _VerticalWeekSidebarState extends State<_VerticalWeekSidebar> {
  late final ScrollController _sc;

  // 每个条目高度 = 44 + 2×3（margin）= 50dp
  static const double _itemHeight = 44.0;
  static const double _itemVMargin = 3.0;
  static const double _itemStride = _itemHeight + _itemVMargin * 2;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _VerticalWeekSidebar old) {
    super.didUpdateWidget(old);
    if (old.selectedWeek != widget.selectedWeek) _scrollToSelected();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_sc.hasClients) return;
    final offset = (widget.selectedWeek - 1) * _itemStride - 80.0;
    _sc.animateTo(
      offset.clamp(0.0, _sc.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 顶部标签：高度与 ScheduleGrid 日期标题栏对齐（tablet = 68dp）
        SizedBox(
          height: 68,
          child: Center(
            child: Text(
              '周次',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        // 周次列表
        Expanded(
          child: ListView.builder(
            controller: _sc,
            itemCount: widget.totalWeeks,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            itemBuilder: (context, index) {
              final week = index + 1;
              final isSelected = week == widget.selectedWeek;
              final isCurrent = week == widget.currentWeek;

              return GestureDetector(
                onTap: () => widget.onWeekSelected(week),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: _itemHeight,
                  margin: const EdgeInsets.symmetric(vertical: _itemVMargin),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withValues(alpha: isDark ? 0.92 : 0.84),
                              cs.primary.withValues(alpha: isDark ? 0.74 : 0.70),
                            ],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : isCurrent
                            ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                            : Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: isDark ? 0.12 : 0.22)
                          : isCurrent
                              ? cs.primary.withValues(alpha: 0.24)
                              : cs.outlineVariant.withValues(alpha: isDark ? 0.10 : 0.06),
                      width: isSelected ? 0.9 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.16),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '第$week周',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || isCurrent
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isCurrent
                              ? cs.primary
                              : theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: isDark ? 0.72 : 0.56),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
