import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../utils/constants.dart';
import '../utils/week_calculator.dart';

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
    final flattenedSlots = <Map<String, dynamic>>[];

    for (final course in courses) {
      for (final slot in course.slots) {
        flattenedSlots.add({
          'courseId': slot.courseId,
          'courseName': slot.courseName,
          'teacher': slot.teacher.isNotEmpty ? slot.teacher : course.teacher,
          'location': slot.location,
          'weekday': slot.weekday,
          'startSection': slot.startSection,
          'endSection': slot.endSection,
          'activeWeeks': slot.getAllActiveWeeks(),
          'color': CourseColors.getColor(slot.courseName).toARGB32(),
        });
      }
    }

    return {
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toIso8601String(),
      'semesterStart': _dateOnly(weekCalc.semesterStart),
      'totalWeeks': weekCalc.totalWeeks,
      'classTimes':
          timeConfig.classTimes
              .map(
                (t) => {
                  'section': t.section,
                  'startTime': t.startTime,
                  'endTime': t.endTime,
                },
              )
              .toList(),
      'slots': flattenedSlots,
      'overrides':
          overrides
              .map(
                (item) => {
                  'id': item.id,
                  'semesterCode': item.semesterCode,
                  'dateKey': item.dateKey,
                  'weekday': item.weekday,
                  'startSection': item.startSection,
                  'endSection': item.endSection,
                  'type': item.type.name,
                  'targetCourseId': item.targetCourseId,
                  'courseName': item.courseName,
                  'teacher': item.teacher,
                  'location': item.location,
                  'note': item.note,
                  'status': item.status.name,
                  'sourceCourseName': item.sourceCourseName,
                  'sourceTeacher': item.sourceTeacher,
                  'sourceLocation': item.sourceLocation,
                  'sourceStartSection': item.sourceStartSection,
                  'sourceEndSection': item.sourceEndSection,
                  'color': CourseColors.getColor(item.courseName).toARGB32(),
                },
              )
              .toList(),
    };
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
