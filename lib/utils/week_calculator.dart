/// 周次计算工具
class WeekCalculator {
  /// 学期第一周周一的日期
  final DateTime semesterStart;

  /// 总周数
  final int totalWeeks;

  WeekCalculator({required this.semesterStart, this.totalWeeks = 20});

  /// 计算指定日期是第几周（从1开始）。
  /// 返回值可能超过 totalWeeks（学期结束后继续计数）。
  int getWeekNumber([DateTime? date]) {
    date ??= DateTime.now();
    final diff = date.difference(semesterStart).inDays;
    if (diff < 0) return 0;
    return (diff ~/ 7) + 1;
  }

  /// 获取今天是星期几（1=周一, 7=周日）
  int getTodayWeekday([DateTime? date]) {
    date ??= DateTime.now();
    return date.weekday;
  }

  /// 获取指定周次的周一日期
  DateTime getWeekMonday(int weekNumber) {
    return semesterStart.add(Duration(days: (weekNumber - 1) * 7));
  }

  /// 获取指定周次某天的日期
  DateTime getDate(int weekNumber, int weekday) {
    return getWeekMonday(weekNumber).add(Duration(days: weekday - 1));
  }

  /// 根据学期码自动推算开学日期。
  /// 第一学期（term=1）：该学年9月1日起的第一个周一。
  /// 第二学期（term=2）：次年3月1日起的第一个周一。
  /// 学期码无法解析时，fallback 到当前年份的第二学期。
  factory WeekCalculator.hainanuSemester(String? semesterCode) {
    if (semesterCode != null && semesterCode.length >= 5) {
      final startYear = int.tryParse(semesterCode.substring(0, 4));
      final term = semesterCode.substring(4);
      if (startYear != null) {
        if (term == '1') {
          return WeekCalculator(
            semesterStart: _firstMondayOnOrAfter(DateTime(startYear, 9, 1)),
            totalWeeks: 20,
          );
        }
        if (term == '2') {
          return WeekCalculator(
            semesterStart: _firstMondayOnOrAfter(DateTime(startYear + 1, 3, 1)),
            totalWeeks: 20,
          );
        }
      }
    }
    // Fallback: 当前年份春季学期
    final year =
        DateTime.now().month >= 9
            ? DateTime.now().year
            : DateTime.now().year - 1;
    return WeekCalculator(
      semesterStart: _firstMondayOnOrAfter(DateTime(year + 1, 3, 1)),
      totalWeeks: 20,
    );
  }

  static String inferSemesterCode(DateTime now) {
    final month = now.month;
    final year = now.year;
    if (month >= 8) {
      return '${year}1';
    }
    if (month <= 1) {
      return '${year - 1}1';
    }
    return '${year - 1}2';
  }

  static DateTime _firstMondayOnOrAfter(DateTime date) {
    final offset = (DateTime.monday - date.weekday + 7) % 7;
    return date.add(Duration(days: offset));
  }
}
