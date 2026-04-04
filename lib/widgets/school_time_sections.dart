import 'package:flutter/material.dart';

import 'package:hai_schedule/models/school_time.dart';

typedef SchoolTimeAsyncSectionEdit = Future<void> Function(int index);

InputDecoration buildSchoolTimeFilledDecoration(
  BuildContext context,
  String label,
) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
      ),
    ),
    isDense: true,
  );
}

class SchoolTimeBasicsCard extends StatelessWidget {
  const SchoolTimeBasicsCard({
    super.key,
    required this.nameController,
    required this.classTimesCount,
    required this.onAddSection,
    required this.onRemoveSection,
    required this.canRemoveSection,
  });

  final TextEditingController nameController;
  final int classTimesCount;
  final VoidCallback onAddSection;
  final VoidCallback onRemoveSection;
  final bool canRemoveSection;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基础信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: buildSchoolTimeFilledDecoration(
                context,
                '作息名称',
              ).copyWith(hintText: '例如：海南大学 / 自定义作息'),
            ),
            const SizedBox(height: 12),
            Text(
              '当前共 $classTimesCount 节课。提醒、自动静音、小组件都会直接复用这份逐节时间表。',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onAddSection,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('增加一节'),
                ),
                OutlinedButton.icon(
                  onPressed: canRemoveSection ? onRemoveSection : null,
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('减少一节'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SchoolTimeGeneratorCard extends StatelessWidget {
  const SchoolTimeGeneratorCard({
    super.key,
    required this.plannedSections,
    required this.saving,
    required this.lessonMinutesController,
    required this.breakMinutesController,
    required this.morningCount,
    required this.afternoonCount,
    required this.eveningCount,
    required this.onMorningCountChanged,
    required this.onAfternoonCountChanged,
    required this.onEveningCountChanged,
    required this.morningStartText,
    required this.afternoonStartText,
    required this.eveningStartText,
    required this.onPickMorningStart,
    required this.onPickAfternoonStart,
    required this.onPickEveningStart,
    required this.enableMorningLongBreak,
    required this.enableAfternoonLongBreak,
    required this.onMorningLongBreakChanged,
    required this.onAfternoonLongBreakChanged,
    required this.morningLongBreakController,
    required this.afternoonLongBreakController,
    required this.morningLongBreakAfter,
    required this.afternoonLongBreakAfter,
    required this.onMorningLongBreakAfterChanged,
    required this.onAfternoonLongBreakAfterChanged,
    required this.onGenerate,
  });

  final int plannedSections;
  final bool saving;
  final TextEditingController lessonMinutesController;
  final TextEditingController breakMinutesController;
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;
  final ValueChanged<int> onMorningCountChanged;
  final ValueChanged<int> onAfternoonCountChanged;
  final ValueChanged<int> onEveningCountChanged;
  final String morningStartText;
  final String afternoonStartText;
  final String eveningStartText;
  final VoidCallback onPickMorningStart;
  final VoidCallback onPickAfternoonStart;
  final VoidCallback onPickEveningStart;
  final bool enableMorningLongBreak;
  final bool enableAfternoonLongBreak;
  final ValueChanged<bool> onMorningLongBreakChanged;
  final ValueChanged<bool> onAfternoonLongBreakChanged;
  final TextEditingController morningLongBreakController;
  final TextEditingController afternoonLongBreakController;
  final int morningLongBreakAfter;
  final int afternoonLongBreakAfter;
  final ValueChanged<int> onMorningLongBreakAfterChanged;
  final ValueChanged<int> onAfternoonLongBreakAfterChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '快速生成作息',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                SchoolTimeTitleBadge('将生成 $plannedSections 节'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '一键生成后会立即生效，下方逐节时间只在你想继续精调时再使用。',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 14),
            SchoolTimeSectionBlock(
              title: '全局参数',
              child: Row(
                children: [
                  Expanded(
                    child: SchoolTimeCompactNumberField(
                      controller: lessonMinutesController,
                      label: '单节时长(分钟)',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SchoolTimeCompactNumberField(
                      controller: breakMinutesController,
                      label: '普通课间(分钟)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SchoolTimeSectionBlock(
              title: '节数分配',
              child: Row(
                children: [
                  SchoolTimeCountStepper(
                    label: '上午',
                    value: morningCount,
                    onChanged: onMorningCountChanged,
                  ),
                  const SizedBox(width: 8),
                  SchoolTimeCountStepper(
                    label: '下午',
                    value: afternoonCount,
                    onChanged: onAfternoonCountChanged,
                  ),
                  const SizedBox(width: 8),
                  SchoolTimeCountStepper(
                    label: '晚上',
                    value: eveningCount,
                    onChanged: onEveningCountChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SchoolTimeSectionBlock(
              title: '各时段首节开始',
              child: Column(
                children: [
                  SchoolTimeStartTimeTile(
                    icon: Icons.wb_sunny_outlined,
                    label: '上午首节',
                    valueText: morningStartText,
                    onTap: onPickMorningStart,
                  ),
                  SchoolTimeStartTimeTile(
                    icon: Icons.wb_twilight_outlined,
                    label: '下午首节',
                    valueText: afternoonStartText,
                    onTap: onPickAfternoonStart,
                  ),
                  SchoolTimeStartTimeTile(
                    icon: Icons.nights_stay_outlined,
                    label: '晚上首节',
                    valueText: eveningStartText,
                    onTap: onPickEveningStart,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SchoolTimeSectionBlock(
              title: '大课间',
              subtitle:
                  '默认按各时段内部节次计算，上午和下午都默认插在该时段第 2 节后；若上午只有 1 节课，下午插在第 2 节后就会落在全天第 6 和第 7 节之间。',
              child: Column(
                children: [
                  SchoolTimeBreakToggleRow(
                    title: '上午大课间',
                    value: enableMorningLongBreak,
                    onChanged: onMorningLongBreakChanged,
                  ),
                  SchoolTimeCompactNumberField(
                    controller: morningLongBreakController,
                    label: '上午大课间时长(分钟)',
                  ),
                  const SizedBox(height: 10),
                  SchoolTimeLongBreakPlacementTile(
                    title: '上午大课间位置',
                    value: morningLongBreakAfter,
                    count: morningCount,
                    onChanged: onMorningLongBreakAfterChanged,
                  ),
                  const SizedBox(height: 10),
                  SchoolTimeBreakToggleRow(
                    title: '下午大课间',
                    value: enableAfternoonLongBreak,
                    onChanged: onAfternoonLongBreakChanged,
                  ),
                  SchoolTimeCompactNumberField(
                    controller: afternoonLongBreakController,
                    label: '下午大课间时长(分钟)',
                  ),
                  const SizedBox(height: 10),
                  SchoolTimeLongBreakPlacementTile(
                    title: '下午大课间位置',
                    value: afternoonLongBreakAfter,
                    count: afternoonCount,
                    onChanged: onAfternoonLongBreakAfterChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: saving ? null : onGenerate,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('生成并应用作息'),
            ),
          ],
        ),
      ),
    );
  }
}

class SchoolTimeSectionListCard extends StatelessWidget {
  const SchoolTimeSectionListCard({
    super.key,
    required this.classTimes,
    required this.onEditSection,
  });

  final List<ClassTime> classTimes;
  final SchoolTimeAsyncSectionEdit onEditSection;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '逐节时间',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '需要更细地修改每节上下课时间时，再在这里微调并保存。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ...classTimes.asMap().entries.map(
              (entry) => SchoolTimeSectionTile(
                index: entry.key,
                item: entry.value,
                onEdit: () => onEditSection(entry.key),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SchoolTimeCompactNumberField extends StatelessWidget {
  const SchoolTimeCompactNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: buildSchoolTimeFilledDecoration(context, label),
    );
  }
}

class SchoolTimeTitleBadge extends StatelessWidget {
  const SchoolTimeTitleBadge(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class SchoolTimeStartTimeTile extends StatelessWidget {
  const SchoolTimeStartTimeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class SchoolTimeCountStepper extends StatelessWidget {
  const SchoolTimeCountStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onChanged(value - 1),
                    icon: const Icon(Icons.remove_rounded, size: 14),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 16,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onChanged(value + 1),
                    icon: const Icon(Icons.add_rounded, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SchoolTimeSectionBlock extends StatelessWidget {
  const SchoolTimeSectionBlock({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class SchoolTimeBreakToggleRow extends StatelessWidget {
  const SchoolTimeBreakToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class SchoolTimeLongBreakPlacementTile extends StatelessWidget {
  const SchoolTimeLongBreakPlacementTile({
    super.key,
    required this.title,
    required this.value,
    required this.count,
    required this.onChanged,
  });

  final String title;
  final int value;
  final int count;
  final ValueChanged<int> onChanged;

  int get _maxPlacement => count > 1 ? count - 1 : 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canInsert = count > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surface.withValues(alpha: 0.58),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  canInsert ? '插在该时段第 $value 节后' : '当前时段不足 2 节，大课间不会插入',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed:
                canInsert
                    ? () => onChanged((value - 1).clamp(1, _maxPlacement))
                    : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: scheme.primaryContainer.withValues(alpha: 0.82),
            ),
            child: Text(
              '第 $value 节后',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed:
                canInsert
                    ? () => onChanged((value + 1).clamp(1, _maxPlacement))
                    : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class SchoolTimeSectionTile extends StatelessWidget {
  const SchoolTimeSectionTile({
    super.key,
    required this.index,
    required this.item,
    required this.onEdit,
  });

  final int index;
  final ClassTime item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '第 ${index + 1} 节',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.startTime} - ${item.endTime}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '编辑时间',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}
