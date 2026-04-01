import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auto_sync_service.dart';
import '../services/schedule_provider.dart';
import 'backup_restore_screen.dart';
import 'home_screen.dart';
import 'import_screen.dart';
import 'login_router.dart';
import 'reminder_settings_screen.dart';
import 'schedule_overrides_screen.dart';
import 'school_time_settings_screen.dart';
import 'semester_management_screen.dart';
import 'sync_center_screen.dart';
import 'theme_settings_screen.dart';

class WindowsDesktopShellScreen extends StatefulWidget {
  const WindowsDesktopShellScreen({super.key, required this.onEnterMiniMode});

  final VoidCallback onEnterMiniMode;

  @override
  State<WindowsDesktopShellScreen> createState() =>
      _WindowsDesktopShellScreenState();
}

class _WindowsDesktopShellScreenState extends State<WindowsDesktopShellScreen>
    with WidgetsBindingObserver {
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
              (_) =>
                  LoginRouter(initialSemesterCode: provider.currentSemesterCode),
        ),
      );

      var afterSnapshot = await AutoSyncService.loadSnapshot();
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

  void _goToCurrentWeek() {
    context.read<ScheduleProvider>().goToCurrentWeek();
  }

  Widget _buildPageHost() {
    return Stack(
      fit: StackFit.expand,
      children:
          _pageCache.entries.map((entry) {
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
          }).toList(growable: false),
    );
  }

  String _formatSemester(String? code) {
    if (code == null || code.isEmpty) return '未设置学期';
    if (code.length < 5) return code;
    final startYear = int.tryParse(code.substring(0, 4));
    if (startYear == null) return code;
    final endYear = startYear + 1;
    final term = code.endsWith('1') ? '第一学期' : '第二学期';
    return '$startYear-$endYear $term';
  }

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
      const _DesktopDestination(
        label: '备份恢复',
        icon: Icons.backup_rounded,
        page: BackupRestoreScreen(
          key: PageStorageKey('windows_backup_restore'),
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
        width >= 1540 ? 304.0 : width >= 1380 ? 280.0 : 252.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: Row(
        children: [
          Container(
            width: sideWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
                  colorScheme.surface.withValues(alpha: 0.96),
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DesktopBrandHeader(
                            semesterText: _formatSemester(semesterCode),
                          ),
                          const SizedBox(height: 16),
                          _DesktopSummaryCard(
                            title: '桌面工作台',
                            lines: [
                              '当前周次：第 $selectedWeek 周',
                              '课程总数：$courseCount 门',
                              '临时安排：$overridesCount 条',
                              '显示模式：${displayDays == 7 ? '完整 7 天' : '工作日 5 天'}',
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _openLogin,
                                icon: const Icon(Icons.login_rounded, size: 18),
                                label: const Text('登录刷新'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _openImport,
                                icon: const Icon(Icons.paste_rounded, size: 18),
                                label: const Text('手动导入'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: widget.onEnterMiniMode,
                            icon: const Icon(Icons.picture_in_picture_alt_rounded),
                            label: const Text('进入迷你模式'),
                          ),
                          const SizedBox(height: 12),
                          _DesktopQuickControlsCard(
                            displayDays: displayDays,
                            showNonCurrentWeek: showNonCurrentWeek,
                            onDisplayDaysChanged: _setDisplayDays,
                            onShowNonCurrentWeekChanged: _setShowNonCurrentWeek,
                            onGoToCurrentWeek: _goToCurrentWeek,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '功能导航',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _destinations.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _destinations[index];
                              final selected = index == _selectedIndex;
                              return _DesktopNavTile(
                                label: item.label,
                                icon: item.icon,
                                selected: selected,
                                onTap: () {
                                  if (_selectedIndex == index) return;
                                  setState(() {
                                    _selectedIndex = index;
                                    _pageCache.putIfAbsent(
                                      index,
                                      () => _destinations[index].page,
                                    );
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Windows 端现在已经把课表、同步、提醒、临时安排、学期与备份这些核心入口提到了桌面工作台里，常用视图控制也可以直接在左侧完成。',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: colorScheme.onSurface.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: _buildPageHost(),
          ),
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

class _DesktopBrandHeader extends StatelessWidget {
  const _DesktopBrandHeader({required this.semesterText});

  final String semesterText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.tertiary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '海大课表',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Windows 工作台',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    semesterText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSummaryCard extends StatelessWidget {
  const _DesktopSummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: colorScheme.onSurface.withValues(alpha: 0.76),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopQuickControlsCard extends StatelessWidget {
  const _DesktopQuickControlsCard({
    required this.displayDays,
    required this.showNonCurrentWeek,
    required this.onDisplayDaysChanged,
    required this.onShowNonCurrentWeekChanged,
    required this.onGoToCurrentWeek,
  });

  final int displayDays;
  final bool showNonCurrentWeek;
  final ValueChanged<int> onDisplayDaysChanged;
  final ValueChanged<bool> onShowNonCurrentWeekChanged;
  final VoidCallback onGoToCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '桌面快捷控制',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('工作日 5 天'),
                selected: displayDays == 5,
                onSelected: (_) => onDisplayDaysChanged(5),
              ),
              ChoiceChip(
                label: const Text('完整 7 天'),
                selected: displayDays == 7,
                onSelected: (_) => onDisplayDaysChanged(7),
              ),
              FilledButton.tonalIcon(
                onPressed: onGoToCurrentWeek,
                icon: const Icon(Icons.today_rounded, size: 18),
                label: const Text('回到本周'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '显示非本周参考课程',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: showNonCurrentWeek,
                  onChanged: onShowNonCurrentWeekChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showNonCurrentWeek
                ? '已开启参考态展示，停开周次的课程也会保留轮廓，方便对照。'
                : '当前只显示本周实际开课内容，周视图会更干净。',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavTile extends StatelessWidget {
  const _DesktopNavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color:
                selected
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : colorScheme.surface.withValues(alpha: 0.38),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.36)
                      : colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
