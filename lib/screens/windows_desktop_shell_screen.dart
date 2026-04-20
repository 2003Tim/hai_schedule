import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/semester_code_formatter.dart';
import 'package:hai_schedule/widgets/windows_desktop_shell_sections.dart';
import 'package:hai_schedule/screens/home_screen.dart';
import 'package:hai_schedule/screens/import_screen.dart';
import 'package:hai_schedule/screens/login_router.dart';
import 'package:hai_schedule/screens/reminder_settings_screen.dart';
import 'package:hai_schedule/screens/schedule_overrides_screen.dart';
import 'package:hai_schedule/screens/school_time_settings_screen.dart';
import 'package:hai_schedule/screens/semester_management_screen.dart';
import 'package:hai_schedule/screens/sync_center_screen.dart';
import 'package:hai_schedule/screens/theme_settings_screen.dart';

class WindowsDesktopShellScreen extends StatefulWidget {
  const WindowsDesktopShellScreen({super.key, required this.onEnterMiniMode});

  final VoidCallback onEnterMiniMode;

  @override
  State<WindowsDesktopShellScreen> createState() =>
      _WindowsDesktopShellScreenState();
}

class _WindowsDesktopShellScreenState extends State<WindowsDesktopShellScreen>
    with WidgetsBindingObserver {
  static const _todayOutOfRangeMessage = '今日日期不在当前学期范围内，无法跳转。';

  int _selectedIndex = 0;
  bool _isDesktopForegroundSyncRunning = false;

  late final List<_DesktopDestination> _destinations = _buildDestinations();
  final Map<int, Widget> _pageCache = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCache[_selectedIndex] = _destinations[_selectedIndex].page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRunDesktopForegroundAutoSync();
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
      _maybeRunDesktopForegroundAutoSync();
    }
  }

  Future<void> _maybeRunDesktopForegroundAutoSync() async {
    if (!Platform.isWindows ||
        !AutoSyncService.supportsForegroundDesktopAutoSync ||
        _isDesktopForegroundSyncRunning ||
        !mounted) {
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final shouldRunNow = await AutoSyncService.shouldSync();
    if (!shouldRunNow) {
      await AutoSyncService.ensureBackgroundSchedule();
      return;
    }

    final beforeSnapshot = await AutoSyncService.loadSnapshot();
    if (!mounted) return;

    _isDesktopForegroundSyncRunning = true;
    try {
      await AutoSyncService.recordDesktopForegroundSyncStart();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => LoginRouter(
                initialSemesterCode: provider.currentSemesterCode,
              ),
        ),
      );

      final afterSnapshot = await AutoSyncService.loadSnapshot();
      final didUpdate =
          afterSnapshot.lastFetchTime != null &&
          (beforeSnapshot.lastFetchTime == null ||
              afterSnapshot.lastFetchTime!.isAfter(
                beforeSnapshot.lastFetchTime!,
              ));
      if (afterSnapshot.state == AutoSyncState.syncing && !didUpdate) {
        await AutoSyncService.recordDesktopForegroundSyncIncomplete();
      }
    } finally {
      _isDesktopForegroundSyncRunning = false;
    }
  }

  Future<void> _openLogin() async {
    final provider = context.read<ScheduleProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                LoginRouter(initialSemesterCode: provider.currentSemesterCode),
      ),
    );
  }

  Future<void> _openImport() async {
    final provider = context.read<ScheduleProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                ImportScreen(initialSemesterCode: provider.currentSemesterCode),
      ),
    );
  }

  void _setDisplayDays(int days) {
    final provider = context.read<ScheduleProvider>();
    if (provider.displayDays == days) return;
    provider.setDisplayDays(days);
  }

  void _setShowNonCurrentWeek(bool value) {
    final provider = context.read<ScheduleProvider>();
    if (provider.showNonCurrentWeek == value) return;
    provider.toggleShowNonCurrentWeek();
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

  void _goToCurrentWeek() {
    final result = context.read<ScheduleProvider>().goToToday(DateTime.now());
    if (result == ScheduleTodayNavigationResult.outOfRange) {
      _showSnack(_todayOutOfRangeMessage, error: true);
    }
  }

  void _selectDestination(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _pageCache.putIfAbsent(index, () => _destinations[index].page);
    });
  }

  Widget _buildPageHost() {
    return Stack(
      fit: StackFit.expand,
      children: _pageCache.entries
          .map((entry) {
            final active = entry.key == _selectedIndex;
            return Positioned.fill(
              child: Offstage(
                offstage: !active,
                child: TickerMode(
                  enabled: active,
                  child: IgnorePointer(
                    ignoring: !active,
                    child: ExcludeSemantics(
                      excluding: !active,
                      child: entry.value,
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  String _formatSemester(String? code) => formatOptionalSemesterCode(code);
  /*
    if (code == null || code.isEmpty) return '未设置学期';
    if (code.length < 5) return code;
    final startYear = int.tryParse(code.substring(0, 4));
    if (startYear == null) return code;
    final endYear = startYear + 1;
    final term = code.endsWith('1') ? '第一学期' : '第二学期';
    return '$startYear-$endYear $term';
  }

  */

  List<_DesktopDestination> _buildDestinations() {
    return [
      _DesktopDestination(
        label: '课表主页',
        icon: Icons.dashboard_customize_rounded,
        page: HomeScreen(
          key: const PageStorageKey('windows_home'),
          onToggleOverlay: widget.onEnterMiniMode,
        ),
      ),
      const _DesktopDestination(
        label: '课表同步',
        icon: Icons.sync_rounded,
        page: SyncCenterScreen(key: PageStorageKey('windows_sync_center')),
      ),
      const _DesktopDestination(
        label: '课前提醒',
        icon: Icons.notifications_active_rounded,
        page: ReminderSettingsScreen(
          key: PageStorageKey('windows_reminder_settings'),
        ),
      ),
      const _DesktopDestination(
        label: '临时安排',
        icon: Icons.edit_calendar_rounded,
        page: ScheduleOverridesScreen(
          key: PageStorageKey('windows_schedule_overrides'),
        ),
      ),
      const _DesktopDestination(
        label: '学期管理',
        icon: Icons.school_rounded,
        page: SemesterManagementScreen(
          key: PageStorageKey('windows_semester_management'),
        ),
      ),
      const _DesktopDestination(
        label: '作息设置',
        icon: Icons.schedule_rounded,
        page: SchoolTimeSettingsScreen(
          key: PageStorageKey('windows_school_time_settings'),
        ),
      ),
      const _DesktopDestination(
        label: '主题设置',
        icon: Icons.palette_rounded,
        page: ThemeSettingsScreen(
          key: PageStorageKey('windows_theme_settings'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selectedWeek = context.select<ScheduleProvider, int>(
      (provider) => provider.selectedWeek,
    );
    final courseCount = context.select<ScheduleProvider, int>(
      (provider) => provider.courses.length,
    );
    final displayDays = context.select<ScheduleProvider, int>(
      (provider) => provider.displayDays,
    );
    final showNonCurrentWeek = context.select<ScheduleProvider, bool>(
      (provider) => provider.showNonCurrentWeek,
    );
    final overridesCount = context.select<ScheduleProvider, int>(
      (provider) => provider.overrides.length,
    );
    final semesterCode = context.select<ScheduleProvider, String?>(
      (provider) => provider.currentSemesterCode,
    );

    final width = MediaQuery.of(context).size.width;
    final sideWidth =
        width >= 1540
            ? 304.0
            : width >= 1380
            ? 280.0
            : 252.0;
    final colorScheme = Theme.of(context).colorScheme;
    final navItems = List<DesktopShellSidebarNavItem>.generate(
      _destinations.length,
      (index) {
        final item = _destinations[index];
        return DesktopShellSidebarNavItem(
          label: item.label,
          icon: item.icon,
          selected: index == _selectedIndex,
          onTap: () => _selectDestination(index),
        );
      },
    );

    return Material(
      color: colorScheme.surface,
      child: Row(
        children: [
          WindowsDesktopSidebar(
            width: sideWidth,
            semesterText: _formatSemester(semesterCode),
            selectedWeek: selectedWeek,
            courseCount: courseCount,
            displayDays: displayDays,
            showNonCurrentWeek: showNonCurrentWeek,
            overridesCount: overridesCount,
            onOpenLogin: () async {
              await _openLogin();
            },
            onOpenImport: () async {
              await _openImport();
            },
            onEnterMiniMode: widget.onEnterMiniMode,
            onDisplayDaysChanged: _setDisplayDays,
            onShowNonCurrentWeekChanged: _setShowNonCurrentWeek,
            onGoToCurrentWeek: _goToCurrentWeek,
            navItems: navItems,
          ),
          Expanded(child: _buildPageHost()),
        ],
      ),
    );
  }
}

class _DesktopDestination {
  const _DesktopDestination({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}
