import 'dart:convert';

import '../models/course.dart';
import '../models/login_fetch_models.dart';
import '../models/schedule_parser.dart';

class LoginFetchPayloadParser {
  static List<Course> parseCourses(String jsonStr) {
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
