import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../services/auto_sync_service.dart';
import '../services/class_silence_service.dart';
import '../services/class_reminder_service.dart';
import '../services/portal_relogin_service.dart';
import '../services/schedule_provider.dart';
import '../widgets/daily_schedule_view.dart';
import '../widgets/schedule_background.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/swipeable_daily_schedule_view.dart';
import '../widgets/swipeable_schedule_view.dart';
import '../utils/constants.dart';
import '../widgets/week_selector.dart';
import 'backup_restore_screen.dart';
import 'import_screen.dart';
import 'login_router.dart';
import 'reminder_settings_screen.dart';
import 'schedule_overrides_screen.dart';
import 'school_time_settings_screen.dart';
import 'semester_management_screen.dart';
import 'sync_center_screen.dart';
import 'theme_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onToggleOverlay;
  final bool isOverlayVisible;

  const HomeScreen({
    super.key,
    this.onToggleOverlay,
    this.isOverlayVisible = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  AutoSyncSnapshot? _syncSnapshot;
  bool _isSyncing = false;
  _ScheduleViewMode _viewMode = _ScheduleViewMode.week;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSyncSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isAndroid) {
        await AutoSyncService.ensureBackgroundSchedule();
      }
      await _refreshSyncSnapshot();
      await _triggerAutoSyncIfNeeded(silent: true);
      if (!mounted) return;
      final provider = context.read<ScheduleProvider>();
      await ClassReminderService.ensureCoverage(
        courses: provider.courses,
        overrides: provider.overrides,
        weekCalc: provider.weekCalc,
        timeConfig: provider.timeConfig,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSyncSnapshot();
      if (Platform.isAndroid) {
        AutoSyncService.ensureBackgroundSchedule();
        _triggerAutoSyncIfNeeded(silent: true);
      }
      final provider = context.read<ScheduleProvider>();
      ClassReminderService.ensureCoverage(
        courses: provider.courses,
        overrides: provider.overrides,
        weekCalc: provider.weekCalc,
        timeConfig: provider.timeConfig,
      );
    }
  }

  Future<void> _refreshSyncSnapshot() async {
    final snapshot = await AutoSyncService.loadSnapshot();
    if (!mounted) return;
    setState(() => _syncSnapshot = snapshot);
  }

  Future<void> _triggerAutoSyncIfNeeded({
    bool silent = false,
    bool force = false,
    bool allowRelogin = true,
  }) async {
    if (!Platform.isAndroid || !mounted || _isSyncing) return;

    _isSyncing = true;
    final provider = context.read<ScheduleProvider>();
    var result = await AutoSyncService.tryAutoSync(
      provider,
      force: force,
      source: force ? 'manual' : 'foreground',
    );

    if (result.requiresLogin && allowRelogin) {
      if (!mounted) return;
      final didStartRelogin = await PortalReloginService.tryRelogin(
        context,
        semesterCode: provider.currentSemesterCode,
      );
      if (didStartRelogin && mounted) {
        result = await AutoSyncService.tryAutoSync(
          provider,
          force: true,
          source: force ? 'manual_relogin' : 'foreground_relogin',
        );
      }
    }

    await _refreshSyncSnapshot();
    if (!mounted) return;

    _isSyncing = false;

    final shouldToast = force || result.didSync || result.requiresLogin;
    if (!silent && shouldToast) {
      _showSnack(
        result.message,
        error: result.requiresLogin || (!result.didSync && result.attempted),
      );
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

  String _formatSemesterCode(String code) {
    if (code.length < 5) return code;
    final startYear = int.tryParse(code.substring(0, 4));
    if (startYear == null) return code;
    final endYear = startYear + 1;
    final term =
        code.substring(4) == '1'
            ? '\u7b2c\u4e00\u5b66\u671f'
            : '\u7b2c\u4e8c\u5b66\u671f';
    return '$startYear-$endYear $term';
  }

  String _currentWeekText(ScheduleProvider provider) {
    if (provider.currentWeek > provider.weekCalc.totalWeeks) {
      return '第 ${provider.selectedWeek} 周 · 学期已结束';
    }
    final suffix =
        provider.selectedWeek == provider.currentWeek ? ' · 当前周' : '';
    return '第 ${provider.selectedWeek} 周$suffix';
  }

  int _effectiveSelectedDay(ScheduleProvider provider) {
    final maxDay = provider.displayDays;
    final fallback =
        provider.todayWeekday <= maxDay ? provider.todayWeekday : 1;
    final current = _selectedDay;
    if (current == null || current < 1 || current > maxDay) {
      return fallback;
    }
    return current;
  }

  String _weekdayLabel(int weekday) {
    const labels = <String>[
      '\u5468\u4e00',
      '\u5468\u4e8c',
      '\u5468\u4e09',
      '\u5468\u56db',
      '\u5468\u4e94',
      '\u5468\u516d',
      '\u5468\u65e5',
    ];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  void _toggleViewMode(ScheduleProvider provider) {
    setState(() {
      _viewMode =
          _viewMode == _ScheduleViewMode.week
              ? _ScheduleViewMode.day
              : _ScheduleViewMode.week;
      if (_viewMode == _ScheduleViewMode.day) {
        _selectedDay = _effectiveSelectedDay(provider);
      }
    });
  }

  Widget _buildDaySelector(BuildContext context, ScheduleProvider provider) {
    final selectedDay = _effectiveSelectedDay(provider);
    final week = provider.selectedWeek;

    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: provider.displayDays,
        itemBuilder: (context, index) {
          final weekday = index + 1;
          final date = provider.getDateForSlot(week, weekday);
          final isSelected = weekday == selectedDay;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayLabel(weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
              onSelected: (_) => _selectDay(weekday),
            ),
          );
        },
      ),
    );
  }

  void _selectDay(int weekday) {
    if (_selectedDay == weekday) return;
    setState(() => _selectedDay = weekday);
  }

  Widget _wrapWindowsScheduleSemantics({
    required Widget child,
    required String label,
  }) {
    if (!Platform.isWindows) return child;

    // Windows desktop can emit unstable AXTree updates when this schedule area
    // rapidly rebuilds during nested paging and scrolling. Keep one stable
    // semantic container while preserving normal pointer interactions.
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            _viewMode == _ScheduleViewMode.week
                ? Icons.today_rounded
                : Icons.view_week_rounded,
            size: 20,
          ),
          tooltip:
              _viewMode == _ScheduleViewMode.week
                  ? '\u5207\u6362\u5230\u65e5\u89c6\u56fe'
                  : '\u5207\u6362\u5230\u5468\u89c6\u56fe',
          onPressed: () => _toggleViewMode(provider),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '\u6d77\u5927\u8bfe\u8868',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _currentWeekText(provider),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            if (provider.currentSemesterCode != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatSemesterCode(provider.currentSemesterCode!),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.90),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.onToggleOverlay != null)
            IconButton(
              icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 20),
              tooltip: '\u5207\u6362\u60ac\u6d6e\u7a97',
              onPressed: widget.onToggleOverlay,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) async {
              switch (value) {
                case 'sync_center':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
                  );
                  await _refreshSyncSnapshot();
                  break;
                case 'login_fetch':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => LoginRouter(
                            initialSemesterCode: provider.currentSemesterCode,
                          ),
                    ),
                  );
                  await _refreshSyncSnapshot();
                  break;
                case 'manual_import':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ImportScreen(
                            initialSemesterCode: provider.currentSemesterCode,
                          ),
                    ),
                  );
                  break;
                case 'semester_management':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SemesterManagementScreen(),
                    ),
                  );
                  break;
                case 'reminder_settings':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReminderSettingsScreen(),
                    ),
                  );
                  break;
                case 'schedule_overrides':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScheduleOverridesScreen(),
                    ),
                  );
                  break;
                case 'school_time_settings':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SchoolTimeSettingsScreen(),
                    ),
                  );
                  break;
                case 'theme_settings':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsScreen(),
                    ),
                  );
                  break;
                case 'backup_restore':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BackupRestoreScreen(),
                    ),
                  );
                  break;
                case 'toggle_days':
                  provider.setDisplayDays(provider.displayDays == 7 ? 5 : 7);
                  break;
                case 'toggle_non_current':
                  provider.toggleShowNonCurrentWeek();
                  break;
                case 'current_week':
                  provider.goToCurrentWeek();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'sync_center',
                    child: ListTile(
                      leading: const Icon(Icons.sync_rounded, size: 20),
                      title: const Text('\u8bfe\u8868\u540c\u6b65'),
                      subtitle:
                          _syncSnapshot?.lastFetchTime != null
                              ? Text(
                                '\u4e0a\u6b21\uff1a${AutoSyncService.formatDateTime(_syncSnapshot!.lastFetchTime)}',
                                style: const TextStyle(fontSize: 11),
                              )
                              : null,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'semester_management',
                    child: ListTile(
                      leading: const Icon(Icons.school_outlined, size: 20),
                      title: const Text('\u5b66\u671f\u7ba1\u7406'),
                      subtitle:
                          provider.currentSemesterCode == null
                              ? const Text(
                                '\u65b0\u5efa\u3001\u5207\u6362\u6216\u5220\u9664\u5b66\u671f',
                                style: TextStyle(fontSize: 11),
                              )
                              : Text(
                                _formatSemesterCode(
                                  provider.currentSemesterCode!,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'reminder_settings',
                    child: ListTile(
                      leading: Icon(
                        Icons.notifications_active_outlined,
                        size: 20,
                      ),
                      title: Text('\u8bfe\u524d\u63d0\u9192'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'school_time_settings',
                    child: ListTile(
                      leading: Icon(Icons.schedule_outlined, size: 20),
                      title: Text('\u4f5c\u606f\u65f6\u95f4\u8bbe\u7f6e'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'schedule_overrides',
                    child: ListTile(
                      leading: const Icon(
                        Icons.edit_calendar_outlined,
                        size: 20,
                      ),
                      title: const Text('\u4e34\u65f6\u5b89\u6392'),
                      subtitle:
                          provider.overrides.isEmpty
                              ? null
                              : Text(
                                '${provider.overrides.length} \u6761\u8bb0\u5f55',
                                style: const TextStyle(fontSize: 11),
                              ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'theme_settings',
                    child: ListTile(
                      leading: Icon(Icons.palette_outlined, size: 20),
                      title: Text('\u4e3b\u9898\u8bbe\u7f6e'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'backup_restore',
                    child: ListTile(
                      leading: Icon(Icons.backup_outlined, size: 20),
                      title: Text('\u5907\u4efd\u4e0e\u6062\u590d'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'toggle_non_current',
                    child: ListTile(
                      leading: Icon(
                        provider.showNonCurrentWeek
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                      ),
                      title: Text(
                        provider.showNonCurrentWeek
                            ? '\u9690\u85cf\u975e\u672c\u5468\u8bfe\u7a0b'
                            : '\u663e\u793a\u975e\u672c\u5468\u8bfe\u7a0b',
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_days',
                    child: ListTile(
                      leading: const Icon(Icons.view_week_rounded, size: 20),
                      title: Text(
                        provider.displayDays == 7
                            ? '\u4ec5\u663e\u793a\u5de5\u4f5c\u65e5'
                            : '\u663e\u793a\u5168\u90e8 7 \u5929',
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'current_week',
                    child: ListTile(
                      leading: Icon(Icons.today_rounded, size: 20),
                      title: Text('\u56de\u5230\u672c\u5468'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: ScheduleBackground(
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
              if (_viewMode == _ScheduleViewMode.day)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildDaySelector(context, provider),
                ),
              const _NextLessonCard(),
              Expanded(
                child:
                    provider.courses.isEmpty
                        ? _buildEmptyState(context)
                        : _viewMode == _ScheduleViewMode.week
                        ? _wrapWindowsScheduleSemantics(
                          label: '周课表区域，可左右切换周次并上下滚动查看课程。',
                          child: SwipeableScheduleView(
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
                        )
                        : _wrapWindowsScheduleSemantics(
                          label: '日课表区域，可左右切换日期并滚动查看课程列表。',
                          child: SwipeableDailyScheduleView(
                            totalDays: provider.displayDays,
                            currentDay: _effectiveSelectedDay(provider),
                            onDayChanged: _selectDay,
                            dayBuilder: (weekday) {
                              return DailyScheduleView(
                                provider: provider,
                                week: provider.selectedWeek,
                                weekday: weekday,
                              );
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loginButtonStyle = FilledButton.styleFrom(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      overlayColor: colorScheme.onPrimary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 56,
                  color: colorScheme.primary.withValues(alpha: 0.28),
                ),
                const SizedBox(height: 14),
                const Text(
                  '\u8fd8\u6ca1\u6709\u5bfc\u5165\u8bfe\u8868',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u53ef\u4ee5\u767b\u5f55\u6559\u52a1\u7cfb\u7edf\u76f4\u63a5\u6293\u53d6\uff0c\u4e5f\u53ef\u4ee5\u624b\u52a8\u7c98\u8d34\u5bfc\u5165\u3002',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: loginButtonStyle,
                  onPressed: () async {
                    final provider = context.read<ScheduleProvider>();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => LoginRouter(
                              initialSemesterCode: provider.currentSemesterCode,
                            ),
                      ),
                    );
                    await _refreshSyncSnapshot();
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(
                    '\u767b\u5f55\u5e76\u5237\u65b0\u8bfe\u8868',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final provider = context.read<ScheduleProvider>();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ImportScreen(
                              initialSemesterCode: provider.currentSemesterCode,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.paste_rounded),
                  label: const Text('\u624b\u52a8\u7c98\u8d34\u5bfc\u5165'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Next-lesson card — isolated StatefulWidget so it rebuilds independently
// from the rest of HomeScreen.  The const constructor lets Flutter skip
// rebuilding it whenever the parent rebuilds (identity check short-circuit).
// ---------------------------------------------------------------------------

class _NextLessonCard extends StatefulWidget {
  const _NextLessonCard();

  @override
  State<_NextLessonCard> createState() => _NextLessonCardState();
}

class _NextLessonCardState extends State<_NextLessonCard>
    with WidgetsBindingObserver {
  ReminderSnapshot? _reminderSnapshot;
  ClassSilenceSnapshot? _silenceSnapshot;
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _scheduleMinuteTimer();
  }

  void _scheduleMinuteTimer() {
    // Fire at the start of the next minute, then every minute after that.
    final now = DateTime.now();
    final msUntilNextMinute = (60 - now.second) * 1000 - now.millisecond;
    Future.delayed(Duration(milliseconds: msUntilNextMinute), () {
      if (!mounted) return;
      setState(() {});
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final reminder = await ClassReminderService.loadSnapshot();
    final silence = await ClassSilenceService.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _reminderSnapshot = reminder;
      _silenceSnapshot = silence;
    });
  }

  _NextLessonInfo? _computeNextLesson(ScheduleProvider provider) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final todayWeekday = provider.todayWeekday;
    final currentWeek = provider.currentWeek;
    final timeConfig = provider.timeConfig;

    final slots =
        provider
            .getDisplaySlotsForDay(currentWeek, todayWeekday)
            .where(
              (d) =>
                  d.isActive && d.overrideType != ScheduleOverrideType.cancel,
            )
            .toList();
    if (slots.isEmpty) return null;

    // Look for ongoing first, then soonest upcoming.
    DisplayScheduleSlot? found;
    bool isOngoing = false;

    for (final d in slots) {
      final start = timeConfig.getClassTime(d.slot.startSection);
      final end = timeConfig.getClassTime(d.slot.endSection);
      if (start == null || end == null) continue;
      if (nowMinutes >= start.startMinutes && nowMinutes <= end.endMinutes) {
        found = d;
        isOngoing = true;
        break;
      }
    }

    if (!isOngoing) {
      DisplayScheduleSlot? earliest;
      int? earliestStart;
      for (final d in slots) {
        final start = timeConfig.getClassTime(d.slot.startSection);
        if (start == null) continue;
        if (start.startMinutes > nowMinutes) {
          if (earliestStart == null || start.startMinutes < earliestStart) {
            earliestStart = start.startMinutes;
            earliest = d;
          }
        }
      }
      if (earliest == null) return null;
      found = earliest;
    }

    if (found == null) return null;

    final startTime = timeConfig.getClassTime(found.slot.startSection);
    final endTime = timeConfig.getClassTime(found.slot.endSection);
    final startText = startTime?.startTime ?? '';
    final endText = endTime?.endTime ?? '';
    final timeText =
        (startText.isNotEmpty && endText.isNotEmpty)
            ? '$startText - $endText'
            : '';

    String label;
    if (isOngoing) {
      label = '进行中';
    } else {
      final start = timeConfig.getClassTime(found.slot.startSection)!;
      final diffMin = start.startMinutes - nowMinutes;
      if (diffMin <= 60) {
        label = '$diffMin 分钟后';
      } else {
        final h = diffMin ~/ 60;
        final m = diffMin % 60;
        label = m == 0 ? '$h 小时后' : '$h 时 $m 分后';
      }
    }

    return _NextLessonInfo(
      slot: found.slot,
      teacher: found.teacher,
      label: label,
      timeText: timeText,
      startText: startText,
      endText: endText,
      isOngoing: isOngoing,
    );
  }

  Widget _buildStatusIcon(
    BuildContext context, {
    required IconData icon,
    required Color baseColor,
  }) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 0.5,
        ),
      ),
      child: Icon(icon, size: 11, color: baseColor.withValues(alpha: 0.88)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final info = _computeNextLesson(provider);
    if (info == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final baseColor = CourseColors.getColor(info.slot.courseName);
    final onSurfaceColor = theme.colorScheme.onSurface;

    final reminderEnabled = _reminderSnapshot?.settings.enabled == true;
    final silenceEnabled =
        _silenceSnapshot?.settings.enabled == true &&
        _silenceSnapshot?.policyAccessGranted == true;
    final sectionText = '第${info.slot.startSection}-${info.slot.endSection}节';
    final primaryMeta = [
      sectionText,
      if (info.timeText.isNotEmpty) info.timeText,
    ].join(' · ');
    final secondaryMeta = [
      if (info.slot.location.isNotEmpty) '@${info.slot.location}',
      if (info.teacher.isNotEmpty) info.teacher,
    ].join(' · ');
    final countdownText = info.label;
    final timeText =
        info.isOngoing && info.endText.isNotEmpty
            ? '至 ${info.endText}'
            : (info.startText.isNotEmpty ? info.startText : '--:--');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 320;
          final horizontalGap = isCompact ? 10.0 : 14.0;
          final indicatorHeight = isCompact ? 20.0 : 24.0;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info.slot.courseName,
                maxLines: isCompact ? 3 : 2,
                softWrap: true,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                  color: onSurfaceColor.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primaryMeta,
                maxLines: isCompact ? 2 : 1,
                overflow: TextOverflow.fade,
                softWrap: true,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: onSurfaceColor.withValues(alpha: 0.72),
                ),
              ),
              if (secondaryMeta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  secondaryMeta,
                  maxLines: isCompact ? 3 : 2,
                  softWrap: true,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: onSurfaceColor.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ],
          );

          final trailing = Column(
            crossAxisAlignment:
                isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                countdownText,
                textAlign: isCompact ? TextAlign.left : TextAlign.right,
                maxLines: isCompact ? 3 : 2,
                softWrap: true,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  color: baseColor.withValues(alpha: 0.96),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeText,
                textAlign: isCompact ? TextAlign.left : TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceColor.withValues(alpha: 0.62),
                ),
              ),
              if (reminderEnabled || silenceEnabled) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reminderEnabled)
                      _buildStatusIcon(
                        context,
                        icon: Icons.notifications_active_rounded,
                        baseColor: baseColor,
                      ),
                    if (reminderEnabled && silenceEnabled)
                      const SizedBox(width: 4),
                    if (silenceEnabled)
                      _buildStatusIcon(
                        context,
                        icon: Icons.volume_off_rounded,
                        baseColor: baseColor,
                      ),
                  ],
                ),
              ],
            ],
          );

          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 0.5,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 14,
              9,
              isCompact ? 12 : 14,
              9,
            ),
            child:
                isCompact
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: indicatorHeight,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                color: baseColor.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: details),
                          ],
                        ),
                        const SizedBox(height: 8),
                        trailing,
                      ],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: indicatorHeight,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        SizedBox(width: horizontalGap),
                        Flexible(child: trailing),
                      ],
                    ),
          );
        },
      ),
    );
  }
}

class _NextLessonInfo {
  final ScheduleSlot slot;
  final String teacher;
  final String label;
  final String timeText;
  final String startText;
  final String endText;
  final bool isOngoing;

  const _NextLessonInfo({
    required this.slot,
    required this.teacher,
    required this.label,
    required this.timeText,
    required this.startText,
    required this.endText,
    this.isOngoing = false,
  });
}

enum _ScheduleViewMode { week, day }
