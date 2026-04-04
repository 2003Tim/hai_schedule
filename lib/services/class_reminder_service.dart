import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/reminder_models.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/class_reminder_planner.dart';
import 'package:hai_schedule/utils/schedule_projection_payload.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/services/app_repositories.dart';

export '../models/reminder_models.dart';

class _PermissionResult {
  final bool notificationsGranted;
  final bool exactAlarmEnabled;

  const _PermissionResult({
    required this.notificationsGranted,
    required this.exactAlarmEnabled,
  });
}

class ClassReminderService {
  static final ReminderRepository _repository = ReminderRepository();

  static const String _payloadType = 'class_reminder';
  static const String _channelId = 'hai_schedule_class_reminders';
  static const String _channelName = '课前提醒';
  static const String _channelDescription = '上课前的本地提醒通知';
  static const Duration _scheduleHorizon = Duration(days: 7);
  static const Duration _rebuildThreshold = Duration(days: 2);
  static const MethodChannel _nativeChannel = MethodChannel(
    'hai_schedule/class_reminder',
  );

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
      settings: settings,
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
    final occurrences = ClassReminderPlanner.buildOccurrences(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      leadMinutes: settings.leadTime.minutes,
      now: now,
      horizonEnd: horizonEnd,
      location: _schoolLocation,
      payloadType: _payloadType,
    );
    return occurrences
        .map(ClassReminderPlanner.previewItemFromOccurrence)
        .toList(growable: false);
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
              ? '${option.label}已开启（精确提醒）'
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
    final occurrences = ClassReminderPlanner.buildOccurrences(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      leadMinutes: settings.leadTime.minutes,
      now: now,
      horizonEnd: horizonEnd,
      location: _schoolLocation,
      payloadType: _payloadType,
    );

    if (!isSupported) {
      await _writeBuildState(
        scheduledCount: occurrences.length,
        horizonEnd: horizonEnd,
        exactAlarmEnabled: false,
      );
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message:
            occurrences.isEmpty
                ? '已保存提醒设置；未来 7 天暂无可提醒课程'
                : '已生成 ${occurrences.length} 条提醒预览；当前平台暂不发送系统通知',
        scheduledCount: occurrences.length,
        exactAlarmEnabled: false,
      );
    }

    final payload = ScheduleProjectionPayload.build(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
    await _cancelLegacyPluginReminders();

    try {
      await _nativeChannel.invokeMethod<void>('rebuildFromProjection', {
        'payload': jsonEncode(payload),
        'leadMinutes': settings.leadTime.minutes,
      });
    } on MissingPluginException {
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message: '当前设备暂不支持课前提醒',
        exactAlarmEnabled: false,
      );
    } on PlatformException catch (error) {
      final snapshot = await loadSnapshot();
      return ReminderApplyResult(
        snapshot: snapshot,
        message: error.message ?? '课前提醒调度失败',
        exactAlarmEnabled: snapshot.exactAlarmEnabled,
      );
    }

    final snapshot = await loadSnapshot();
    return ReminderApplyResult(
      snapshot: snapshot,
      message:
          snapshot.scheduledCount == 0
              ? '未来 7 天内没有可提醒的课程'
              : '已生成 ${snapshot.scheduledCount} 条课前提醒',
      scheduledCount: snapshot.scheduledCount,
      exactAlarmEnabled: snapshot.exactAlarmEnabled,
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
    await _cancelLegacyPluginReminders();
    await _invokeNativeCancel();

    await _repository.saveState(
      scheduledCount: 0,
      exactAlarmEnabled: false,
      clearLastBuildTime: true,
      clearHorizonEnd: true,
    );
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
    } catch (error) {
      debugPrint('请求通知权限失败: $error');
    }

    var exactAlarmEnabled = false;
    try {
      exactAlarmEnabled =
          await androidPlugin?.requestExactAlarmsPermission() ?? false;
    } catch (error) {
      debugPrint('请求精确闹钟权限失败: $error');
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
    await _repository.saveState(
      scheduledCount: scheduledCount,
      exactAlarmEnabled: exactAlarmEnabled,
      lastBuildTime: DateTime.now(),
      horizonEnd: horizonEnd?.toLocal(),
      clearHorizonEnd: horizonEnd == null,
    );
  }

  static Future<void> _cancelLegacyPluginReminders() async {
    if (!Platform.isAndroid) return;
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_isClassReminderPayload(request.payload)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  static Future<void> _invokeNativeCancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<void>('cancelSchedule');
    } on MissingPluginException {
      // Ignore in unsupported environments.
    } on PlatformException catch (error) {
      debugPrint('取消课前提醒失败: ${error.message}');
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

  static tz.Location get _schoolLocation {
    _ensureTimezoneReady();
    return tz.getLocation('Asia/Shanghai');
  }
}
