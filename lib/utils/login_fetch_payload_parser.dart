import 'dart:convert';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/models/undergraduate_schedule_parser.dart';

class LoginFetchPayloadParser {
  static List<Course> parseCourses(
    String jsonStr, {
    ScheduleSource source = ScheduleSource.graduate,
  }) {
    if (source.isUndergraduate) {
      final courses = UndergraduateScheduleParser.parseHtml(jsonStr).courses;
      if (courses.isEmpty) {
        throw const LoginFetchException(
          '\u672a\u89e3\u6790\u5230\u8bfe\u7a0b\u6570\u636e',
        );
      }
      return courses;
    }

    final data = json.decode(jsonStr) as Map<String, dynamic>;

    if (data['code'] != '0') {
      throw LoginFetchException(
        '\u63a5\u53e3\u5f02\u5e38 (code=${data['code']})',
      );
    }

    final courses = ScheduleParser.parseApiResponse(data);
    if (courses.isEmpty) {
      throw const LoginFetchException(
        '\u672a\u89e3\u6790\u5230\u8bfe\u7a0b\u6570\u636e',
      );
    }

    return courses;
  }
}
