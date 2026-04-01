import 'package:flutter/material.dart';

/// 课程卡片配色
class CourseColors {
  static const List<Color> cardColors = [
    Color(0xFF4E8DF5), // 蓝
    Color(0xFF43C59E), // 绿
    Color(0xFFFC7B5D), // 珊瑚橙
    Color(0xFF9B7FE6), // 紫
    Color(0xFFF5A623), // 琥珀
    Color(0xFF5BC0EB), // 天蓝
    Color(0xFFE85D75), // 玫红
    Color(0xFF2EC4B6), // 青
    Color(0xFFFF8A5C), // 橙
    Color(0xFF7B68EE), // 中紫
  ];

  static Color getColor(String courseName) {
    final index = courseName.hashCode.abs() % cardColors.length;
    return cardColors[index];
  }
}

/// 星期名称
class WeekdayNames {
  static const short = ['一', '二', '三', '四', '五', '六', '日'];
  static String getShort(int weekday) => short[weekday - 1];
}

/// 时间段划分
enum TimePeriod {
  morning('上午', 1, 4),
  afternoon('下午', 5, 8),
  evening('晚上', 9, 11);

  final String label;
  final int startSection;
  final int endSection;

  const TimePeriod(this.label, this.startSection, this.endSection);

  /// 某节课属于哪个时间段
  static TimePeriod fromSection(int section) {
    if (section <= 4) return morning;
    if (section <= 8) return afternoon;
    return evening;
  }
}
