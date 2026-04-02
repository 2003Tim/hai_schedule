import '../models/course.dart';

class AutoSyncCourseDiff {
  const AutoSyncCourseDiff._();

  static String buildSummary(List<Course> previous, List<Course> current) {
    final previousMap = {
      for (final course in previous)
        _courseIdentity(course): _courseSignature(course),
    };
    final currentMap = {
      for (final course in current)
        _courseIdentity(course): _courseSignature(course),
    };

    final added =
        currentMap.keys.where((key) => !previousMap.containsKey(key)).length;
    final removed =
        previousMap.keys.where((key) => !currentMap.containsKey(key)).length;
    final changed =
        currentMap.keys
            .where(
              (key) =>
                  previousMap.containsKey(key) &&
                  previousMap[key] != currentMap[key],
            )
            .length;

    if (added == 0 && removed == 0 && changed == 0) {
      return '课表无变化';
    }

    final parts = <String>[];
    if (added > 0) parts.add('新增 $added 门');
    if (removed > 0) parts.add('移除 $removed 门');
    if (changed > 0) parts.add('调整 $changed 门');
    return parts.join('，');
  }

  static String _courseIdentity(Course course) {
    return '${course.code}|${course.name}|${course.teacher}|${course.className}';
  }

  static String _courseSignature(Course course) {
    final slots =
        course.slots
            .map(
              (slot) => [
                slot.weekday,
                slot.startSection,
                slot.endSection,
                slot.location,
                slot.weekRanges
                    .map(
                      (range) =>
                          '${range.start}-${range.end}-${range.type.name}',
                    )
                    .join('/'),
              ].join('|'),
            )
            .toList()
          ..sort();

    return '${course.college}|${course.credits}|${course.totalHours}|${course.semester}|${course.campus}|${course.teachingType}|${slots.join(';')}';
  }
}
