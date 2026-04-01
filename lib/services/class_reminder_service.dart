import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../utils/week_calculator.dart';
import 'app_repositories.dart';

enum ReminderLeadTimeOption {
  off(0, '关闭'),
  fiveMinutes(5, '提前 5 分钟'),
  tenMinutes(10, '提前 10 分钟'),
  fifteenMinutes(15, '提前 15 分钟'),
  thirtyMinutes(30, '提前 30 分钟');

  final int minutes;
  final String label;

  const ReminderLeadTimeOption(this.minutes, this.label);

  static ReminderLeadTimeOption fromMinutes(int? minutes) {
    return ReminderLeadTimeOption.values.firstWhere(
      (item) => item.minutes == minutes,
      orElse: () => ReminderLeadTimeOption.off,
    );
  }
}

class ReminderSettings {
  final ReminderLeadTimeOption leadTime;

  const ReminderSettings({required this.leadTime});

  bool get enabled => leadTime != ReminderLeadTimeOption.off;
}

class ReminderSnapshot {
  final ReminderSettings settings;
  final DateTime? lastBuildTime;
  final DateTime? horizonEnd;
  final int scheduledCount;
  final bool exactAlarmEnabled;

  const ReminderSnapshot({
    required this.settings,
    this.lastBuildTime,
    this.horizonEnd,
    this.scheduledCount = 0,
    this.exactAlarmEnabled = false,
  });
}

class ReminderApplyResult {
  final ReminderSnapshot snapshot;
  final String message;
  final int scheduledCount;
  final bool notificationsGranted;
  final bool exactAlarmEnabled;

  const ReminderApplyResult({
    required this.snapshot,
    required this.message,
    this.scheduledCount = 0,
    this.notificationsGranted = true,
    this.exactAlarmEnabled = false,
  });
}

class ReminderPreviewItem {
  final String courseName;
  final String location;
  final String timeRange;
  final String dateLabel;
  final DateTime remindAt;
  final int leadMinutes;

  const ReminderPreviewItem({
    required this.courseName,
    required this.location,
    required this.timeRange,
    required this.dateLabel,
    required this.remindAt,
    required this.leadMinutes,
  });
}

class _PermissionResult {
  final bool notificationsGranted;
  final bool exactAlarmEnabled;

  const _PermissionResult({
    required this.notificationsGranted,
    required this.exactAlarmEnabled,
  });
}

class _ReminderOccurrence {
  final int notificationId;
  final String title;
  final String body;
  final tz.TZDateTime remindAt;
  final Map<String, dynamic> payload;

  const _ReminderOccurrence({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.remindAt,
    required this.payload,
  });
}

class _ResolvedReminderItem {
  final ScheduleSlot slot;
  final String teacher;

  const _ResolvedReminderItem({required this.slot, required this.teacher});
}

class ClassReminderService {
  static final ReminderRepository _repository = ReminderRepository();

  static const String _lastBuildTimeKey = 'class_reminder_last_build_time';
  static const String _horizonEndKey = 'class_reminder_horizon_end';
  static const String _scheduledCountKey = 'class_reminder_scheduled_count';
  static const String _exactAlarmEnabledKey =
      'class_reminder_exact_alarm_enabled';

  static const String _payloadType = 'class_reminder';
  static const String _channelId = 'hai_schedule_class_reminders';
  static const String _channelName = '课前提醒';
  static const String _channelDescription = '上课前的本地提醒通知';
  static const Duration _scheduleHorizon = Duration(days: 7);
  static const Duration _rebuildThreshold = Duration(days: 2);

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _timezoneReady = false;

  static bool get isSupported => Platform.isAndroid;

  static Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;

    _ensureTimezoneReady();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) {},
    );

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );

    _initialized = true;
  }

  static Future<ReminderSettings> loadSettings() async {
    final record = await _repository.loadRecord();
    return ReminderSettings(
      leadTime: ReminderLeadTimeOption.fromMinutes(record.leadMinutes),
    );
  }

  static Future<ReminderSnapshot> loadSnapshot() async {
    final record = await _repository.loadRecord();
    final settings = ReminderSettings(
      leadTime: ReminderLeadTimeOption.fromMinutes(record.leadMinutes),
    );
    return ReminderSnapshot(
      settings: settings,
      lastBuildTime: record.lastBuildTime,
      horizonEnd: record.horizonEnd,
      scheduledCount: record.scheduledCount,
      exactAlarmEnabled: record.exactAlarmEnabled,
    );
  }

  static Future<List<ReminderPreviewItem>> buildPreview({
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    final settings = await loadSettings();
    if (!settings.enabled || courses.isEmpty) {
      return const <ReminderPreviewItem>[];
    }

    final now = _nowInSchoolTimezone();
    final horizonEnd = now.add(_scheduleHorizon);
    final occurrences = _buildOccurrences(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      leadMinutes: settings.leadTime.minutes,
      now: now,
      horizonEnd: horizonEnd,
    );
    return occurrences.map(_previewItemFromOccurrence).toList(growable: false);
  }

  static Future<ReminderApplyResult> updateLeadTime({
    required ReminderLeadTimeOption option,
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    await initialize();

    await _repository.saveLeadMinutes(option.minutes);

    if (option == ReminderLeadTimeOption.off) {
      await cancelAllCourseReminders();
      await _repository.saveState(exactAlarmEnabled: false);
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(snapshot: snapshot, message: '已关闭课前提醒');
    }

    final permissions = await _requestPermissionsForUserInitiatedEnable();
    await _repository.saveState(
      exactAlarmEnabled: permissions.exactAlarmEnabled,
    );

    if (!permissions.notificationsGranted) {
      await cancelAllCourseReminders();
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message: '已保存提醒设置，但系统未授予通知权限',
        notificationsGranted: false,
        exactAlarmEnabled: permissions.exactAlarmEnabled,
      );
    }

    final rebuilt = await rebuildForSchedule(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      exactAlarmEnabledOverride: permissions.exactAlarmEnabled,
    );

    return ReminderApplyResult(
      snapshot: rebuilt.snapshot,
      message:
          rebuilt.exactAlarmEnabled
              ? '${option.label}已开启（精准提醒）'
              : '${option.label}已开启（省电模式）',
      scheduledCount: rebuilt.scheduledCount,
      notificationsGranted: permissions.notificationsGranted,
      exactAlarmEnabled: rebuilt.exactAlarmEnabled,
    );
  }

  static Future<ReminderApplyResult> rebuildForSchedule({
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    bool? exactAlarmEnabledOverride,
  }) async {
    await initialize();
    final settings = await loadSettings();

    if (!settings.enabled) {
      await cancelAllCourseReminders();
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(snapshot: snapshot, message: '课前提醒未开启');
    }

    final record = await _repository.loadRecord();
    final exactAlarmEnabled =
        exactAlarmEnabledOverride ?? record.exactAlarmEnabled;

    await cancelAllCourseReminders();

    if (courses.isEmpty) {
      await _writeBuildState(
        scheduledCount: 0,
        horizonEnd: null,
        exactAlarmEnabled: exactAlarmEnabled,
      );
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message: '当前还没有课程，导入课表后会自动生成提醒',
        exactAlarmEnabled: exactAlarmEnabled,
      );
    }

    final now = _nowInSchoolTimezone();
    final horizonEnd = now.add(_scheduleHorizon);
    final occurrences = _buildOccurrences(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      leadMinutes: settings.leadTime.minutes,
      now: now,
      horizonEnd: horizonEnd,
    );

    if (!isSupported) {
      if (occurrences.isEmpty) {
        await _writeBuildState(
          scheduledCount: 0,
          horizonEnd: horizonEnd,
          exactAlarmEnabled: false,
        );
        final snapshot = await loadSnapshot();
        return ReminderApplyResult(
          snapshot: snapshot,
          message: '已保存提醒设置；未来 7 天暂无可提醒课程',
          exactAlarmEnabled: false,
        );
      }

      await _writeBuildState(
        scheduledCount: occurrences.length,
        horizonEnd: horizonEnd,
        exactAlarmEnabled: false,
      );
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message: '已生成 ${occurrences.length} 条提醒预览；当前平台暂不发送系统通知',
        scheduledCount: occurrences.length,
        exactAlarmEnabled: false,
      );
    }

    if (occurrences.isEmpty) {
      await _writeBuildState(
        scheduledCount: 0,
        horizonEnd: horizonEnd,
        exactAlarmEnabled: exactAlarmEnabled,
      );
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message: '未来 7 天内没有可提醒的课程',
        exactAlarmEnabled: exactAlarmEnabled,
      );
    }

    final scheduleMode =
        exactAlarmEnabled
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    for (final occurrence in occurrences) {
      await _plugin.zonedSchedule(
        occurrence.notificationId,
        occurrence.title,
        occurrence.body,
        occurrence.remindAt,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode(occurrence.payload),
      );
    }

    await _writeBuildState(
      scheduledCount: occurrences.length,
      horizonEnd: horizonEnd,
      exactAlarmEnabled: exactAlarmEnabled,
    );

    final snapshot = await loadSnapshot();
    return ReminderApplyResult(
      snapshot: snapshot,
      message: '已生成 ${occurrences.length} 条课前提醒',
      scheduledCount: occurrences.length,
      exactAlarmEnabled: exactAlarmEnabled,
    );
  }

  static Future<void> ensureCoverage({
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    final snapshot = await loadSnapshot();
    if (!snapshot.settings.enabled) return;

    final now = _nowInSchoolTimezone();
    final horizonEnd = snapshot.horizonEnd;
    if (horizonEnd != null && horizonEnd.isAfter(now.add(_rebuildThreshold))) {
      return;
    }

    await rebuildForSchedule(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
  }

  static Future<void> cancelAllCourseReminders() async {
    if (isSupported) {
      await initialize();
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (_isClassReminderPayload(request.payload)) {
          await _plugin.cancel(request.id);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scheduledCountKey, 0);
    await prefs.remove(_lastBuildTimeKey);
    await prefs.remove(_horizonEndKey);
  }

  static List<_ReminderOccurrence> _buildOccurrences({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    required int leadMinutes,
    required tz.TZDateTime now,
    required tz.TZDateTime horizonEnd,
  }) {
    final occurrences = <_ReminderOccurrence>[];
    final startDate = DateTime(now.year, now.month, now.day);
    final totalDays = horizonEnd.difference(now).inDays + 1;

    for (var offset = 0; offset < totalDays; offset++) {
      final day = startDate.add(Duration(days: offset));
      final week = weekCalc.getWeekNumber(day);
      if (week <= 0 || week > weekCalc.totalWeeks) continue;

      final dayItems = _resolveDaySchedule(
        day: day,
        week: week,
        courses: courses,
        overrides: overrides,
      );

      for (final item in dayItems) {
        final slotTime = timeConfig.getSlotTime(
          item.slot.startSection,
          item.slot.endSection,
        );
        if (slotTime == null) continue;

        final startParts = slotTime.$1.split(':');
        if (startParts.length != 2) continue;

        final startHour = int.tryParse(startParts[0]);
        final startMinute = int.tryParse(startParts[1]);
        if (startHour == null || startMinute == null) continue;

        final classStart = tz.TZDateTime(
          _schoolLocation,
          day.year,
          day.month,
          day.day,
          startHour,
          startMinute,
        );
        final remindAt = classStart.subtract(Duration(minutes: leadMinutes));

        if (!remindAt.isAfter(now)) continue;
        if (remindAt.isAfter(horizonEnd)) continue;

        final range = '${slotTime.$1}-${slotTime.$2}';
        final title = '$leadMinutes 分钟后上课';
        final body = [
          item.slot.courseName,
          range,
          if (item.slot.location.trim().isNotEmpty) item.slot.location.trim(),
        ].join(' · ');

        occurrences.add(
          _ReminderOccurrence(
            notificationId: _notificationIdFor(
              courseId: item.slot.courseId,
              date: day,
              startSection: item.slot.startSection,
              endSection: item.slot.endSection,
            ),
            title: title,
            body: body,
            remindAt: remindAt,
            payload: {
              'type': _payloadType,
              'courseId': item.slot.courseId,
              'courseName': item.slot.courseName,
              'teacher': item.teacher,
              'location': item.slot.location,
              'weekday': item.slot.weekday,
              'week': week,
              'date': _formatDate(day),
              'startSection': item.slot.startSection,
              'endSection': item.slot.endSection,
              'startTime': slotTime.$1,
              'endTime': slotTime.$2,
              'leadMinutes': leadMinutes,
            },
          ),
        );
      }
    }

    occurrences.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return occurrences;
  }

  static List<_ResolvedReminderItem> _resolveDaySchedule({
    required DateTime day,
    required int week,
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
  }) {
    final dateKey = _formatDate(day);
    final weekday = day.weekday;
    final dayOverrides =
        overrides
            .where((item) => item.dateKey == dateKey && item.weekday == weekday)
            .toList();

    final items = <_ResolvedReminderItem>[];

    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday || !slot.isActiveInWeek(week)) {
          continue;
        }

        var cancelled = false;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.cancel) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          final matchesCourse =
              item.targetCourseId != null &&
              item.targetCourseId == slot.courseId;
          final sourceStart = item.sourceStartSection ?? item.startSection;
          final sourceEnd = item.sourceEndSection ?? item.endSection;
          final matchesSections =
              sourceStart == slot.startSection && sourceEnd == slot.endSection;
          if (matchesCourse || matchesSections) {
            cancelled = true;
            break;
          }
        }
        if (cancelled) {
          continue;
        }

        ScheduleOverride? modifyOverride;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.modify) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          final sourceStart = item.sourceStartSection ?? item.startSection;
          final sourceEnd = item.sourceEndSection ?? item.endSection;
          if ((item.targetCourseId != null &&
                  item.targetCourseId == slot.courseId) ||
              (sourceStart == slot.startSection &&
                  sourceEnd == slot.endSection)) {
            modifyOverride = item;
            break;
          }
        }

        if (modifyOverride != null) {
          items.add(
            _ResolvedReminderItem(
              slot: ScheduleSlot(
                courseId: slot.courseId,
                courseName:
                    modifyOverride.courseName.isNotEmpty
                        ? modifyOverride.courseName
                        : slot.courseName,
                teacher:
                    modifyOverride.teacher.isNotEmpty
                        ? modifyOverride.teacher
                        : slot.teacher,
                weekday: weekday,
                startSection: modifyOverride.startSection,
                endSection: modifyOverride.endSection,
                location:
                    modifyOverride.location.isNotEmpty
                        ? modifyOverride.location
                        : slot.location,
                weekRanges: slot.weekRanges,
              ),
              teacher:
                  modifyOverride.teacher.isNotEmpty
                      ? modifyOverride.teacher
                      : course.teacher,
            ),
          );
          continue;
        }

        items.add(_ResolvedReminderItem(slot: slot, teacher: course.teacher));
      }
    }

    for (final item in dayOverrides.where(
      (value) =>
          value.type == ScheduleOverrideType.add &&
          value.status != ScheduleOverrideStatus.orphaned,
    )) {
      items.add(
        _ResolvedReminderItem(
          slot: ScheduleSlot(
            courseId: item.id,
            courseName: item.courseName.isNotEmpty ? item.courseName : '临时课程',
            teacher: item.teacher,
            weekday: weekday,
            startSection: item.startSection,
            endSection: item.endSection,
            location: item.location,
            weekRanges: const <WeekRange>[],
          ),
          teacher: item.teacher,
        ),
      );
    }

    items.sort((a, b) => a.slot.startSection.compareTo(b.slot.startSection));
    return items;
  }

  static int _notificationIdFor({
    required String courseId,
    required DateTime date,
    required int startSection,
    required int endSection,
  }) {
    final raw = Object.hash(
      courseId,
      date.year,
      date.month,
      date.day,
      startSection,
      endSection,
    );
    return raw.abs() % 2147480000;
  }

  static Future<_PermissionResult>
  _requestPermissionsForUserInitiatedEnable() async {
    if (!Platform.isAndroid) {
      return const _PermissionResult(
        notificationsGranted: true,
        exactAlarmEnabled: false,
      );
    }

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    var notificationsGranted = true;
    try {
      notificationsGranted =
          await androidPlugin?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('请求通知权限失败: $e');
    }

    var exactAlarmEnabled = false;
    try {
      exactAlarmEnabled =
          await androidPlugin?.requestExactAlarmsPermission() ?? false;
    } catch (e) {
      debugPrint('请求精准闹钟权限失败: $e');
    }

    return _PermissionResult(
      notificationsGranted: notificationsGranted,
      exactAlarmEnabled: exactAlarmEnabled,
    );
  }

  static Future<void> _writeBuildState({
    required int scheduledCount,
    required bool exactAlarmEnabled,
    required tz.TZDateTime? horizonEnd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scheduledCountKey, scheduledCount);
    await prefs.setBool(_exactAlarmEnabledKey, exactAlarmEnabled);
    await prefs.setString(_lastBuildTimeKey, DateTime.now().toIso8601String());
    if (horizonEnd == null) {
      await prefs.remove(_horizonEndKey);
    } else {
      await prefs.setString(_horizonEndKey, horizonEnd.toIso8601String());
    }
  }

  static bool _isClassReminderPayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> && data['type'] == _payloadType;
    } catch (_) {
      return false;
    }
  }

  static ReminderPreviewItem _previewItemFromOccurrence(
    _ReminderOccurrence occurrence,
  ) {
    final payload = occurrence.payload;
    final startTime = payload['startTime']?.toString() ?? '';
    final endTime = payload['endTime']?.toString() ?? '';
    final timeRange =
        startTime.isEmpty || endTime.isEmpty ? '' : '$startTime - $endTime';
    return ReminderPreviewItem(
      courseName: payload['courseName']?.toString() ?? occurrence.title,
      location: payload['location']?.toString() ?? '',
      timeRange: timeRange,
      dateLabel: payload['date']?.toString() ?? '',
      remindAt: occurrence.remindAt.toLocal(),
      leadMinutes: payload['leadMinutes'] as int? ?? 0,
    );
  }

  static void _ensureTimezoneReady() {
    if (_timezoneReady) return;
    tz.initializeTimeZones();
    final location = tz.getLocation('Asia/Shanghai');
    tz.setLocalLocation(location);
    _timezoneReady = true;
  }

  static tz.TZDateTime _nowInSchoolTimezone() {
    _ensureTimezoneReady();
    return tz.TZDateTime.now(_schoolLocation);
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static tz.Location get _schoolLocation {
    _ensureTimezoneReady();
    return tz.getLocation('Asia/Shanghai');
  }
}
