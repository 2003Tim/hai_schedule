import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/school_time.dart';
import '../services/app_repositories.dart';
import '../services/schedule_provider.dart';

class SchoolTimeSettingsScreen extends StatefulWidget {
  const SchoolTimeSettingsScreen({super.key});

  @override
  State<SchoolTimeSettingsScreen> createState() =>
      _SchoolTimeSettingsScreenState();
}

class _SchoolTimeSettingsScreenState extends State<SchoolTimeSettingsScreen> {
  final SchoolTimeRepository _schoolTimeRepository = SchoolTimeRepository();

  late TextEditingController _nameController;
  late List<ClassTime> _classTimes;
  bool _saving = false;

  final TextEditingController _morningCountController = TextEditingController(
    text: '4',
  );
  final TextEditingController _afternoonCountController = TextEditingController(
    text: '4',
  );
  final TextEditingController _eveningCountController = TextEditingController(
    text: '3',
  );
  final TextEditingController _lessonMinutesController = TextEditingController(
    text: '45',
  );
  final TextEditingController _breakMinutesController = TextEditingController(
    text: '10',
  );
  final TextEditingController _morningLongBreakController =
      TextEditingController(text: '25');
  final TextEditingController _afternoonLongBreakController =
      TextEditingController(text: '25');
  final TextEditingController _morningLongBreakAfterController =
      TextEditingController(text: '2');
  final TextEditingController _afternoonLongBreakAfterController =
      TextEditingController(text: '2');

  TimeOfDay _morningStart = const TimeOfDay(hour: 7, minute: 40);
  TimeOfDay _afternoonStart = const TimeOfDay(hour: 14, minute: 30);
  TimeOfDay _eveningStart = const TimeOfDay(hour: 19, minute: 20);
  bool _enableMorningLongBreak = true;
  bool _enableAfternoonLongBreak = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<ScheduleProvider>().timeConfig;
    _nameController = TextEditingController(text: config.name);
    _classTimes = config.classTimes.map((item) => item.copyWith()).toList();
    _loadGeneratorSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _morningCountController.dispose();
    _afternoonCountController.dispose();
    _eveningCountController.dispose();
    _lessonMinutesController.dispose();
    _breakMinutesController.dispose();
    _morningLongBreakController.dispose();
    _afternoonLongBreakController.dispose();
    _morningLongBreakAfterController.dispose();
    _afternoonLongBreakAfterController.dispose();
    super.dispose();
  }

  Future<void> _loadGeneratorSettings() async {
    final settings = await _schoolTimeRepository.loadGeneratorSettings();
    if (!mounted) return;
    setState(() {
      _morningCountController.text = settings.morningCount.toString();
      _afternoonCountController.text = settings.afternoonCount.toString();
      _eveningCountController.text = settings.eveningCount.toString();
      _lessonMinutesController.text = settings.lessonMinutes.toString();
      _breakMinutesController.text = settings.breakMinutes.toString();
      _morningLongBreakController.text =
          settings.morningLongBreakMinutes.toString();
      _afternoonLongBreakController.text =
          settings.afternoonLongBreakMinutes.toString();
      _morningLongBreakAfterController.text =
          settings.morningLongBreakAfter.toString();
      _afternoonLongBreakAfterController.text =
          settings.afternoonLongBreakAfter.toString();
      _morningStart = _parseTime(settings.morningStart, _morningStart);
      _afternoonStart = _parseTime(settings.afternoonStart, _afternoonStart);
      _eveningStart = _parseTime(settings.eveningStart, _eveningStart);
      _enableMorningLongBreak = settings.enableMorningLongBreak;
      _enableAfternoonLongBreak = settings.enableAfternoonLongBreak;
      _syncLongBreakAfterInputs();
    });
  }

  Future<void> _pickTime({required int index, required bool isStart}) async {
    final current = _classTimes[index];
    final raw = isStart ? current.startTime : current.endTime;
    final initial = _parseTime(raw, const TimeOfDay(hour: 8, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _classTimes[index] = current.copyWith(
        startTime: isStart ? _formatTimeOfDay(picked) : current.startTime,
        endTime: isStart ? current.endTime : _formatTimeOfDay(picked),
      );
    });
  }

  Future<void> _pickGeneratorStart({required String period}) async {
    final initial = switch (period) {
      'morning' => _morningStart,
      'afternoon' => _afternoonStart,
      _ => _eveningStart,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (period) {
        case 'morning':
          _morningStart = picked;
          break;
        case 'afternoon':
          _afternoonStart = picked;
          break;
        default:
          _eveningStart = picked;
      }
    });
  }

  void _addSection() {
    final previous = _classTimes.isNotEmpty ? _classTimes.last : null;
    final start =
        previous == null ? '08:00' : _formatMinutes(previous.endMinutes + 10);
    final end =
        previous == null ? '08:45' : _formatMinutes(previous.endMinutes + 55);
    setState(() {
      _classTimes.add(
        ClassTime(
          section: _classTimes.length + 1,
          startTime: start,
          endTime: end,
        ),
      );
    });
  }

  void _removeSection() {
    if (_classTimes.length <= 1) return;
    setState(() => _classTimes.removeLast());
  }

  SchoolTimeGeneratorSettings _buildGeneratorSettings() {
    _syncLongBreakAfterInputs();
    return SchoolTimeGeneratorSettings(
      morningCount: int.tryParse(_morningCountController.text.trim()) ?? 4,
      afternoonCount: int.tryParse(_afternoonCountController.text.trim()) ?? 4,
      eveningCount: int.tryParse(_eveningCountController.text.trim()) ?? 3,
      lessonMinutes: int.tryParse(_lessonMinutesController.text.trim()) ?? 45,
      breakMinutes: int.tryParse(_breakMinutesController.text.trim()) ?? 10,
      morningLongBreakMinutes:
          int.tryParse(_morningLongBreakController.text.trim()) ?? 25,
      afternoonLongBreakMinutes:
          int.tryParse(_afternoonLongBreakController.text.trim()) ?? 25,
      morningLongBreakAfter:
          int.tryParse(_morningLongBreakAfterController.text.trim()) ?? 2,
      afternoonLongBreakAfter:
          int.tryParse(_afternoonLongBreakAfterController.text.trim()) ?? 2,
      morningStart: _formatTimeOfDay(_morningStart),
      afternoonStart: _formatTimeOfDay(_afternoonStart),
      eveningStart: _formatTimeOfDay(_eveningStart),
      enableMorningLongBreak: _enableMorningLongBreak,
      enableAfternoonLongBreak: _enableAfternoonLongBreak,
    );
  }

  Future<void> _persistGeneratorSettings() {
    return _schoolTimeRepository.saveGeneratorSettings(
      _buildGeneratorSettings(),
    );
  }

  Future<void> _resetToDefault() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('恢复默认作息'),
                content: const Text('会把当前自定义作息恢复为海南大学默认作息。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('恢复'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final provider = context.read<ScheduleProvider>();
    await provider.resetTimeConfigToDefault();
    await _schoolTimeRepository.saveGeneratorSettings(
      SchoolTimeGeneratorSettings.defaults(),
    );
    final config = provider.timeConfig;
    if (!mounted) return;
    setState(() {
      _nameController.text = config.name;
      _classTimes = config.classTimes.map((item) => item.copyWith()).toList();
    });
    await _loadGeneratorSettings();
    _showSnack('已恢复默认作息');
  }

  Future<void> _generateSchedule() async {
    if (_saving) return;
    final morningCount = int.tryParse(_morningCountController.text.trim()) ?? 0;
    final afternoonCount =
        int.tryParse(_afternoonCountController.text.trim()) ?? 0;
    final eveningCount = int.tryParse(_eveningCountController.text.trim()) ?? 0;
    final lessonMinutes =
        int.tryParse(_lessonMinutesController.text.trim()) ?? 0;
    final breakMinutes = int.tryParse(_breakMinutesController.text.trim()) ?? 0;
    final morningLongBreak =
        int.tryParse(_morningLongBreakController.text.trim()) ?? 0;
    final afternoonLongBreak =
        int.tryParse(_afternoonLongBreakController.text.trim()) ?? 0;
    _syncLongBreakAfterInputs();
    final morningLongBreakAfter =
        int.tryParse(_morningLongBreakAfterController.text.trim()) ?? 2;
    final afternoonLongBreakAfter =
        int.tryParse(_afternoonLongBreakAfterController.text.trim()) ?? 2;

    if (lessonMinutes <= 0 ||
        breakMinutes < 0 ||
        morningCount < 0 ||
        afternoonCount < 0 ||
        eveningCount < 0) {
      _showSnack('请填写合法的节数和分钟数', error: true);
      return;
    }

    final generated = <ClassTime>[];
    var section = 1;

    void appendPeriod({
      required int count,
      required TimeOfDay start,
      required bool enableLongBreak,
      required int longBreakMinutes,
      required int longBreakAfter,
    }) {
      if (count <= 0) return;
      var cursor = start.hour * 60 + start.minute;
      for (var index = 0; index < count; index++) {
        final startMinutes = cursor;
        final endMinutes = cursor + lessonMinutes;
        generated.add(
          ClassTime(
            section: section++,
            startTime: _formatMinutes(startMinutes),
            endTime: _formatMinutes(endMinutes),
          ),
        );
        cursor = endMinutes;
        if (index == count - 1) continue;
        final isLongBreak =
            enableLongBreak && count > 1 && index == longBreakAfter - 1;
        cursor += isLongBreak ? longBreakMinutes : breakMinutes;
      }
    }

    appendPeriod(
      count: morningCount,
      start: _morningStart,
      enableLongBreak: _enableMorningLongBreak,
      longBreakMinutes: morningLongBreak,
      longBreakAfter: morningLongBreakAfter,
    );
    appendPeriod(
      count: afternoonCount,
      start: _afternoonStart,
      enableLongBreak: _enableAfternoonLongBreak,
      longBreakMinutes: afternoonLongBreak,
      longBreakAfter: afternoonLongBreakAfter,
    );
    appendPeriod(
      count: eveningCount,
      start: _eveningStart,
      enableLongBreak: false,
      longBreakMinutes: 0,
      longBreakAfter: 1,
    );

    if (!_validateClassTimes(generated)) {
      _showSnack('生成后的时间有重叠，请调整参数', error: true);
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final normalized = _normalizeClassTimes(generated);
    setState(() => _saving = true);
    try {
      await _persistGeneratorSettings();
      await provider.updateTimeConfig(_buildTimeConfig(normalized));
      if (!mounted) return;
      setState(() => _classTimes = normalized);
      _showSnack('已生成并应用作息时间，下面可以继续微调');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_classTimes.isEmpty) {
      _showSnack('至少保留一节课', error: true);
      return;
    }
    if (!_validateClassTimes(_classTimes)) {
      _showSnack('作息时间存在重叠或开始晚于结束，请先修正', error: true);
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<ScheduleProvider>();
    try {
      await _persistGeneratorSettings();
      await provider.updateTimeConfig(_buildTimeConfig(_classTimes));
      if (!mounted) return;
      _showSnack('作息时间已保存');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _validateClassTimes(List<ClassTime> classTimes) {
    for (var index = 0; index < classTimes.length; index++) {
      final item = classTimes[index];
      if (item.startMinutes >= item.endMinutes) {
        return false;
      }
      if (index > 0 && item.startMinutes < classTimes[index - 1].endMinutes) {
        return false;
      }
    }
    return true;
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

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts.last);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 23 * 60 + 59);
    final hour = (safe ~/ 60).toString().padLeft(2, '0');
    final minute = (safe % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  InputDecoration _filledDecoration(String label) {
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

  Widget _buildCompactNumberField(
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _filledDecoration(label),
    );
  }

  Widget _buildTitleBadge(String value) {
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

  Widget _buildStartTimeTile({
    required IconData icon,
    required String label,
    required TimeOfDay value,
    required String period,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pickGeneratorStart(period: period),
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
              _formatTimeOfDay(value),
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

  Widget _buildCountStepper(String label, TextEditingController controller) {
    final scheme = Theme.of(context).colorScheme;
    final value = int.tryParse(controller.text.trim()) ?? 0;

    void update(int next) {
      if (next < 0) return;
      setState(() {
        controller.text = next.toString();
        _syncLongBreakAfterInputs();
      });
    }

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
                    onPressed: () => update(value - 1),
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
                    onPressed: () => update(value + 1),
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

  Widget _buildSectionBlock({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
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
              subtitle,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBreakToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildLongBreakPlacementTile({
    required String title,
    required TextEditingController controller,
    required int count,
    required int fallback,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final value = int.tryParse(controller.text.trim()) ?? fallback;
    final max = _maxLongBreakAfter(count);
    final canInsert = count > 1;

    void update(int delta) {
      if (!canInsert) return;
      final next = (value + delta).clamp(1, max);
      setState(() {
        controller.text = next.toString();
      });
    }

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
                  canInsert ? '插在该时段第$value节后' : '当前时段不足2节，大课间不会插入',
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
            onPressed: canInsert ? () => update(-1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: scheme.primaryContainer.withValues(alpha: 0.82),
            ),
            child: Text(
              '第$value节后',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: canInsert ? () => update(1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  int _maxLongBreakAfter(int count) => count > 1 ? count - 1 : 1;

  int _clampLongBreakAfter(
    TextEditingController controller,
    int count,
    int fallback,
  ) {
    final parsed = int.tryParse(controller.text.trim()) ?? fallback;
    final clamped = parsed.clamp(1, _maxLongBreakAfter(count));
    return clamped;
  }

  void _syncLongBreakAfterInputs() {
    _morningLongBreakAfterController.text =
        _clampLongBreakAfter(
          _morningLongBreakAfterController,
          int.tryParse(_morningCountController.text.trim()) ?? 0,
          2,
        ).toString();
    _afternoonLongBreakAfterController.text =
        _clampLongBreakAfter(
          _afternoonLongBreakAfterController,
          int.tryParse(_afternoonCountController.text.trim()) ?? 0,
          2,
        ).toString();
  }

  List<ClassTime> _normalizeClassTimes(List<ClassTime> classTimes) {
    return classTimes
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(section: entry.key + 1))
        .toList();
  }

  SchoolTimeConfig _buildTimeConfig(List<ClassTime> classTimes) {
    return SchoolTimeConfig(
      name:
          _nameController.text.trim().isEmpty
              ? '自定义作息'
              : _nameController.text.trim(),
      classTimes: _normalizeClassTimes(classTimes),
    );
  }

  Widget _buildSectionTile(int index, ClassTime item) {
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
              '第${index + 1}节',
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
            onPressed: () async {
              await _pickTime(index: index, isStart: true);
              if (!mounted) return;
              await _pickTime(index: index, isStart: false);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plannedSections =
        (int.tryParse(_morningCountController.text.trim()) ?? 0) +
        (int.tryParse(_afternoonCountController.text.trim()) ?? 0) +
        (int.tryParse(_eveningCountController.text.trim()) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('作息时间设置'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _resetToDefault,
            child: const Text('恢复默认'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
                    controller: _nameController,
                    decoration: _filledDecoration(
                      '作息名称',
                    ).copyWith(hintText: '例如：海南大学 / 自定义作息'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '当前共 ${_classTimes.length} 节课。提醒、自动静音、小组件都会直接复用这份逐节时间表。',
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
                        onPressed: _addSection,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('增加一节'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _classTimes.length <= 1 ? null : _removeSection,
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('减少一节'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTitleBadge('将生成 $plannedSections 节'),
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
                  _buildSectionBlock(
                    title: '全局参数',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCompactNumberField(
                            _lessonMinutesController,
                            '单节时长(分钟)',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCompactNumberField(
                            _breakMinutesController,
                            '普通课间(分钟)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionBlock(
                    title: '节数分配',
                    child: Row(
                      children: [
                        _buildCountStepper('上午', _morningCountController),
                        const SizedBox(width: 8),
                        _buildCountStepper('下午', _afternoonCountController),
                        const SizedBox(width: 8),
                        _buildCountStepper('晚上', _eveningCountController),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionBlock(
                    title: '各时段首节开始',
                    child: Column(
                      children: [
                        _buildStartTimeTile(
                          icon: Icons.wb_sunny_outlined,
                          label: '上午首节',
                          value: _morningStart,
                          period: 'morning',
                        ),
                        _buildStartTimeTile(
                          icon: Icons.wb_twilight_outlined,
                          label: '下午首节',
                          value: _afternoonStart,
                          period: 'afternoon',
                        ),
                        _buildStartTimeTile(
                          icon: Icons.nights_stay_outlined,
                          label: '晚上首节',
                          value: _eveningStart,
                          period: 'evening',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionBlock(
                    title: '大课间',
                    subtitle:
                        '默认按各时段内部节次计算，上午和下午都默认插在该时段第2节后；若上午有4节课，下午插在第2节后就会落在全天第6和第7节之间。',
                    child: Column(
                      children: [
                        _buildBreakToggleRow(
                          title: '上午大课间',
                          value: _enableMorningLongBreak,
                          onChanged:
                              (value) => setState(
                                () => _enableMorningLongBreak = value,
                              ),
                        ),
                        _buildCompactNumberField(
                          _morningLongBreakController,
                          '上午大课间时长(分钟)',
                        ),
                        const SizedBox(height: 10),
                        _buildLongBreakPlacementTile(
                          title: '上午大课间位置',
                          controller: _morningLongBreakAfterController,
                          count:
                              int.tryParse(
                                _morningCountController.text.trim(),
                              ) ??
                              0,
                          fallback: 2,
                        ),
                        const SizedBox(height: 10),
                        _buildBreakToggleRow(
                          title: '下午大课间',
                          value: _enableAfternoonLongBreak,
                          onChanged:
                              (value) => setState(
                                () => _enableAfternoonLongBreak = value,
                              ),
                        ),
                        _buildCompactNumberField(
                          _afternoonLongBreakController,
                          '下午大课间时长(分钟)',
                        ),
                        const SizedBox(height: 10),
                        _buildLongBreakPlacementTile(
                          title: '下午大课间位置',
                          controller: _afternoonLongBreakAfterController,
                          count:
                              int.tryParse(
                                _afternoonCountController.text.trim(),
                              ) ??
                              0,
                          fallback: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _generateSchedule,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('生成并应用作息'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
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
                  ..._classTimes.asMap().entries.map(
                    (entry) => _buildSectionTile(entry.key, entry.value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon:
                _saving
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save_rounded),
            label: const Text('保存作息时间'),
          ),
        ],
      ),
    );
  }
}
