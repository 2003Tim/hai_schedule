import 'package:flutter/material.dart';

class DesktopShellSidebarNavItem {
  const DesktopShellSidebarNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

class WindowsDesktopSidebar extends StatelessWidget {
  const WindowsDesktopSidebar({
    super.key,
    required this.width,
    required this.semesterText,
    required this.selectedWeek,
    required this.courseCount,
    required this.displayDays,
    required this.showNonCurrentWeek,
    required this.overridesCount,
    required this.onOpenLogin,
    required this.onOpenImport,
    required this.onEnterMiniMode,
    required this.onDisplayDaysChanged,
    required this.onShowNonCurrentWeekChanged,
    required this.onGoToCurrentWeek,
    required this.navItems,
  });

  final double width;
  final String semesterText;
  final int selectedWeek;
  final int courseCount;
  final int displayDays;
  final bool showNonCurrentWeek;
  final int overridesCount;
  final VoidCallback onOpenLogin;
  final VoidCallback onOpenImport;
  final VoidCallback onEnterMiniMode;
  final ValueChanged<int> onDisplayDaysChanged;
  final ValueChanged<bool> onShowNonCurrentWeekChanged;
  final VoidCallback onGoToCurrentWeek;
  final List<DesktopShellSidebarNavItem> navItems;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
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
                    DesktopBrandHeader(semesterText: semesterText),
                    const SizedBox(height: 16),
                    DesktopSummaryCard(
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
                          onPressed: onOpenLogin,
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('登录刷新'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: onOpenImport,
                          icon: const Icon(Icons.paste_rounded, size: 18),
                          label: const Text('手动导入'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onEnterMiniMode,
                      icon: const Icon(Icons.picture_in_picture_alt_rounded),
                      label: const Text('进入迷你模式'),
                    ),
                    const SizedBox(height: 12),
                    DesktopQuickControlsCard(
                      displayDays: displayDays,
                      showNonCurrentWeek: showNonCurrentWeek,
                      onDisplayDaysChanged: onDisplayDaysChanged,
                      onShowNonCurrentWeekChanged: onShowNonCurrentWeekChanged,
                      onGoToCurrentWeek: onGoToCurrentWeek,
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
                      itemCount: navItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        return DesktopNavTile(
                          label: item.label,
                          icon: item.icon,
                          selected: item.selected,
                          onTap: item.onTap,
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
    );
  }
}

class DesktopBrandHeader extends StatelessWidget {
  const DesktopBrandHeader({super.key, required this.semesterText});

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

class DesktopSummaryCard extends StatelessWidget {
  const DesktopSummaryCard({
    super.key,
    required this.title,
    required this.lines,
  });

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

class DesktopQuickControlsCard extends StatelessWidget {
  const DesktopQuickControlsCard({
    super.key,
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
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.32,
              ),
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

class DesktopNavTile extends StatelessWidget {
  const DesktopNavTile({
    super.key,
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
