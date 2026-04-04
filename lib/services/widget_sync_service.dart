import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/schedule_projection_payload.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

/// Flutter -> Android 桌面小组件数据同步
///
/// 第一阶段策略：
/// 1. Flutter 侧把完整课表快照写入 HomeWidget 的 SharedPreferences。
/// 2. Kotlin AppWidgetProvider 在系统更新/应用刷新时，自行根据“今天日期”计算今日课程。
///
/// 这样即便用户没有重新打开 App，小组件也能在系统周期刷新时完成“跨天切换”。
class WidgetSyncService {
  static const String payloadKey = 'hai_schedule_widget_payload';
  static const String androidWidgetClassName = 'TodayScheduleWidgetProvider';

  static Future<void> syncSchedule({
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final payload = _buildPayload(
        courses: courses,
        overrides: overrides,
        weekCalc: weekCalc,
        timeConfig: timeConfig,
      );

      await HomeWidget.saveWidgetData<String>(payloadKey, jsonEncode(payload));

      await HomeWidget.updateWidget(androidName: androidWidgetClassName);
    } catch (e, st) {
      debugPrint('同步桌面小组件失败: $e');
      debugPrint('$st');
    }
  }

  static Future<void> refreshWidget() async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.updateWidget(androidName: androidWidgetClassName);
    } catch (e, st) {
      debugPrint('刷新桌面小组件失败: $e');
      debugPrint('$st');
    }
  }

  static Map<String, dynamic> _buildPayload({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) {
    return ScheduleProjectionPayload.build(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
  }
}
