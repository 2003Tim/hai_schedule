import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/school_time_sections.dart';

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

  Future<void> _editSection(int index) async {
    await _pickTime(index: index, isStart: true);
    if (!mounted) return;
    await _pickTime(index: index, isStart: false);
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
      _showSnack('已生成并应用作息时间，下方可以继续微调');
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

  void _updateCountController(TextEditingController controller, int next) {
    if (next < 0) return;
    setState(() {
      controller.text = next.toString();
      _syncLongBreakAfterInputs();
    });
  }

  void _updateLongBreakAfterController(
    TextEditingController controller,
    int next,
  ) {
    setState(() {
      controller.text = next.toString();
    });
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

  @override
  Widget build(BuildContext context) {
    final plannedSections =
        (int.tryParse(_morningCountController.text.trim()) ?? 0) +
        (int.tryParse(_afternoonCountController.text.trim()) ?? 0) +
        (int.tryParse(_eveningCountController.text.trim()) ?? 0);
    final morningCount = int.tryParse(_morningCountController.text.trim()) ?? 0;
    final afternoonCount =
        int.tryParse(_afternoonCountController.text.trim()) ?? 0;
    final eveningCount = int.tryParse(_eveningCountController.text.trim()) ?? 0;
    final morningLongBreakAfter =
        int.tryParse(_morningLongBreakAfterController.text.trim()) ?? 2;
    final afternoonLongBreakAfter =
        int.tryParse(_afternoonLongBreakAfterController.text.trim()) ?? 2;

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
          SchoolTimeBasicsCard(
            nameController: _nameController,
            classTimesCount: _classTimes.length,
            onAddSection: _addSection,
            onRemoveSection: _removeSection,
            canRemoveSection: _classTimes.length > 1,
          ),
          const SizedBox(height: 16),
          SchoolTimeGeneratorCard(
            plannedSections: plannedSections,
            saving: _saving,
            lessonMinutesController: _lessonMinutesController,
            breakMinutesController: _breakMinutesController,
            morningCount: morningCount,
            afternoonCount: afternoonCount,
            eveningCount: eveningCount,
            onMorningCountChanged:
                (next) => _updateCountController(_morningCountController, next),
            onAfternoonCountChanged:
                (next) =>
                    _updateCountController(_afternoonCountController, next),
            onEveningCountChanged:
                (next) => _updateCountController(_eveningCountController, next),
            morningStartText: _formatTimeOfDay(_morningStart),
            afternoonStartText: _formatTimeOfDay(_afternoonStart),
            eveningStartText: _formatTimeOfDay(_eveningStart),
            onPickMorningStart: () => _pickGeneratorStart(period: 'morning'),
            onPickAfternoonStart:
                () => _pickGeneratorStart(period: 'afternoon'),
            onPickEveningStart: () => _pickGeneratorStart(period: 'evening'),
            enableMorningLongBreak: _enableMorningLongBreak,
            enableAfternoonLongBreak: _enableAfternoonLongBreak,
            onMorningLongBreakChanged:
                (value) => setState(() => _enableMorningLongBreak = value),
            onAfternoonLongBreakChanged:
                (value) => setState(() => _enableAfternoonLongBreak = value),
            morningLongBreakController: _morningLongBreakController,
            afternoonLongBreakController: _afternoonLongBreakController,
            morningLongBreakAfter: morningLongBreakAfter,
            afternoonLongBreakAfter: afternoonLongBreakAfter,
            onMorningLongBreakAfterChanged:
                (next) => _updateLongBreakAfterController(
                  _morningLongBreakAfterController,
                  next,
                ),
            onAfternoonLongBreakAfterChanged:
                (next) => _updateLongBreakAfterController(
                  _afternoonLongBreakAfterController,
                  next,
                ),
            onGenerate: _generateSchedule,
          ),
          const SizedBox(height: 16),
          SchoolTimeSectionListCard(
            classTimes: _classTimes,
            onEditSection: _editSection,
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
