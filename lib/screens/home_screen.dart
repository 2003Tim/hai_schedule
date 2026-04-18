import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/portal_relogin_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/semester_code_formatter.dart';
import 'package:hai_schedule/widgets/home_screen_sections.dart';
import 'package:hai_schedule/screens/backup_restore_screen.dart';
import 'package:hai_schedule/screens/import_screen.dart';
import 'package:hai_schedule/screens/login_router.dart';
import 'package:hai_schedule/screens/reminder_settings_screen.dart';
import 'package:hai_schedule/screens/schedule_overrides_screen.dart';
import 'package:hai_schedule/screens/school_time_settings_screen.dart';
import 'package:hai_schedule/screens/semester_management_screen.dart';
import 'package:hai_schedule/screens/sync_center_screen.dart';
import 'package:hai_schedule/screens/theme_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onToggleOverlay,
    this.isOverlayVisible = false,
  });

  final VoidCallback? onToggleOverlay;
  final bool isOverlayVisible;

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
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    if (!mounted) return;

    final provider = context.read<ScheduleProvider>();
    if (Platform.isAndroid) {
      await provider.reloadFromStorage();
    }
    await _refreshSyncSnapshot();

    if (Platform.isAndroid) {
      await AutoSyncService.ensureBackgroundSchedule();
      await _triggerAutoSyncIfNeeded(silent: true);
    }

    if (!mounted) return;
    await ClassReminderService.ensureCoverage(
      courses: provider.courses,
      overrides: provider.overrides,
      weekCalc: provider.weekCalc,
      timeConfig: provider.timeConfig,
    );
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
    try {
      final provider = context.read<ScheduleProvider>();
      var result = await AutoSyncService.tryAutoSync(
        provider,
        force: force,
        source: force ? 'manual' : 'foreground',
      );

      if (result.requiresLogin && allowRelogin) {
        if (!mounted) return;
        final didRelogin = await PortalReloginService.tryRelogin(
          context,
          semesterCode: provider.currentSemesterCode,
        );
        if (didRelogin && mounted) {
          final snapshot = await AutoSyncService.loadSnapshot();
          result = AutoSyncResult.success(
            provider.courses.length,
            snapshot.message,
            snapshot,
          );
        }
      }

      await _refreshSyncSnapshot();
      if (!mounted) return;

      final shouldToast = force || result.didSync || result.requiresLogin;
      if (!silent && shouldToast) {
        _showSnack(
          result.message,
          error: result.requiresLogin || (!result.didSync && result.attempted),
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _showSnack(String text, {bool error = false}) {
    if (!mounted) return;
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

  String _formatSemesterCode(String code) => formatSemesterCode(code);

  String _currentWeekText(ScheduleProvider provider) {
    if (provider.currentWeek > provider.weekCalc.totalWeeks) {
      return '第${provider.selectedWeek} 周 · 学期已结束';
    }
    final suffix =
        provider.selectedWeek == provider.currentWeek ? ' · 当前周' : '';
    return '第${provider.selectedWeek} 周$suffix';
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

  void _selectDay(int weekday) {
    if (_selectedDay == weekday) return;
    setState(() => _selectedDay = weekday);
  }

  Widget _wrapWindowsScheduleSemantics(Widget child, String label) {
    if (!Platform.isWindows) return child;

    // Keep one stable semantic container on Windows to avoid noisy AXTree
    // updates while the schedule area rebuilds during paging and scrolling.
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }

  Future<void> _pushPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openSyncCenter() async {
    await _pushPage(const SyncCenterScreen());
    await _refreshSyncSnapshot();
  }

  Future<void> _openLoginFetch(ScheduleProvider provider) async {
    await _pushPage(
      LoginRouter(initialSemesterCode: provider.currentSemesterCode),
    );
    await _refreshSyncSnapshot();
  }

  Future<void> _openManualImport(ScheduleProvider provider) async {
    await _pushPage(
      ImportScreen(initialSemesterCode: provider.currentSemesterCode),
    );
  }

  Future<void> _handleMenuAction(
    HomeMenuAction action,
    ScheduleProvider provider,
  ) async {
    switch (action) {
      case HomeMenuAction.syncCenter:
        await _openSyncCenter();
        break;
      case HomeMenuAction.semesterManagement:
        await _pushPage(const SemesterManagementScreen());
        break;
      case HomeMenuAction.reminderSettings:
        await _pushPage(const ReminderSettingsScreen());
        break;
      case HomeMenuAction.schoolTimeSettings:
        await _pushPage(const SchoolTimeSettingsScreen());
        break;
      case HomeMenuAction.scheduleOverrides:
        await _pushPage(const ScheduleOverridesScreen());
        break;
      case HomeMenuAction.themeSettings:
        await _pushPage(const ThemeSettingsScreen());
        break;
      case HomeMenuAction.backupRestore:
        await _pushPage(const BackupRestoreScreen());
        break;
      case HomeMenuAction.toggleNonCurrent:
        provider.toggleShowNonCurrentWeek();
        break;
      case HomeMenuAction.toggleDays:
        provider.setDisplayDays(provider.displayDays == 7 ? 5 : 7);
        break;
      case HomeMenuAction.currentWeek:
        provider.goToCurrentWeek();
        break;
      case HomeMenuAction.loginFetch:
        await _openLoginFetch(provider);
        break;
      case HomeMenuAction.manualImport:
        await _openManualImport(provider);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final width = MediaQuery.of(context).size.width;
    final isDesktopLayout = width >= 1200;
    final layoutKey = ValueKey<String>(
      isDesktopLayout
          ? 'home.layout.desktop'
          : width >= 720
          ? 'home.layout.tablet'
          : 'home.layout.mobile',
    );
    Widget quickActions = HomeOverflowMenu(
      key: const ValueKey('home.panel.quickActions'),
      provider: provider,
      syncSnapshot: _syncSnapshot,
      formatSemesterCode: _formatSemesterCode,
      showLabel: isDesktopLayout,
      onSelected: (action) async {
        await _handleMenuAction(action, provider);
      },
    );
    if (isDesktopLayout) {
      quickActions = KeyedSubtree(
        key: const ValueKey('home.layout.desktop.side'),
        child: quickActions,
      );
    }
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
          tooltip: _viewMode == _ScheduleViewMode.week ? '切换到日视图' : '切换到周视图',
          onPressed: () => _toggleViewMode(provider),
        ),
        title: HomeAppBarTitle(
          key: const ValueKey('home.panel.overview'),
          currentWeekText: _currentWeekText(provider),
          semesterLabel:
              provider.currentSemesterCode == null
                  ? null
                  : _formatSemesterCode(provider.currentSemesterCode!),
        ),
        actions: [
          if (widget.onToggleOverlay != null)
            IconButton(
              icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 20),
              tooltip: '切换悬浮窗',
              onPressed: widget.onToggleOverlay,
            ),
          quickActions,
        ],
      ),
      body: KeyedSubtree(
        key: layoutKey,
        child: HomeScheduleBody(
          key: const ValueKey('home.panel.schedule'),
          provider: provider,
          showDayView: _viewMode == _ScheduleViewMode.day,
          selectedDay: _effectiveSelectedDay(provider),
          navigationKey: const ValueKey('home.panel.navigation'),
          onDaySelected: _selectDay,
          onLoginFetch: () async {
            await _openLoginFetch(provider);
          },
          onManualImport: () async {
            await _openManualImport(provider);
          },
          wrapScheduleSemantics: _wrapWindowsScheduleSemantics,
        ),
      ),
    );
  }
}

enum _ScheduleViewMode { week, day }
