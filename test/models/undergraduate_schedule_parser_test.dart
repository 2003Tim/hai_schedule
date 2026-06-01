import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/undergraduate_schedule_parser.dart';

void main() {
  group('UndergraduateScheduleParser', () {
    test('normalizes undergraduate semester values', () {
      expect(
        UndergraduateScheduleParser.normalizeSemesterCode('2024-2025-2'),
        '20242',
      );
      expect(
        UndergraduateScheduleParser.normalizeSemesterCode('2024-2025-1'),
        '20241',
      );
      expect(
        UndergraduateScheduleParser.normalizeSemesterCode('20242'),
        '20242',
      );
      expect(
        UndergraduateScheduleParser.normalizeSemesterCode('2010-2011-3'),
        isNull,
      );
      expect(UndergraduateScheduleParser.normalizeSemesterCode(''), isNull);
    });

    test('parses semester catalog, class times and course slots from HTML', () {
      final result = UndergraduateScheduleParser.parseHtml(_sampleHtml);

      expect(result.semesterCode, '20242');
      expect(result.semesterOptions, hasLength(3));
      expect(result.semesterOptions.first.code, '20252');
      expect(result.semesterOptions.first.name, '2025-2026-2');
      expect(result.semesterOptions.last.code, '20241');

      expect(result.schoolTimeConfig.classTimes, hasLength(15));
      expect(result.schoolTimeConfig.getClassTime(1)?.startTime, '07:40');
      expect(result.schoolTimeConfig.getClassTime(11)?.endTime, '21:55');
      expect(result.schoolTimeConfig.getClassTime(12)?.startTime, '11:35');
      expect(result.schoolTimeConfig.getClassTime(15)?.endTime, '14:20');

      expect(result.courses, hasLength(1));
      final course = result.courses.single;
      expect(course.id, '202420252012135');
      expect(course.code, 'Q00012');
      expect(course.name, '形势与政策8');
      expect(course.teacher, '郎筱宇');
      expect(course.className, '2021-1班');
      expect(course.campus, '海甸');
      expect(course.semester, '2024-2025-2');

      expect(course.slots, hasLength(1));
      final slot = course.slots.single;
      expect(slot.weekday, 2);
      expect(slot.startSection, 9);
      expect(slot.endSection, 10);
      expect(slot.location, '(海甸)3-308');
      expect(slot.weekRanges, hasLength(1));
      expect(slot.weekRanges.single.start, 10);
      expect(slot.weekRanges.single.end, 11);
    });

    test('merges course blocks sharing the same notice id across slots', () {
      final result = UndergraduateScheduleParser.parseHtml(_mergedHtml);

      expect(result.courses, hasLength(1));
      final course = result.courses.single;
      expect(course.id, '202420252012135');
      // Metadata from dataTables2 must be preserved on the merged course.
      expect(course.name, '形势与政策8');
      expect(course.code, 'Q00012');
      expect(course.className, '2021-1班');
      expect(course.teacher, '郎筱宇');

      expect(course.slots, hasLength(2));
      final slotsByWeekday = {
        for (final slot in course.slots) slot.weekday: slot,
      };
      expect(slotsByWeekday.keys, containsAll(<int>[2, 4]));
      expect(slotsByWeekday[2]?.startSection, 9);
      expect(slotsByWeekday[2]?.endSection, 10);
      expect(slotsByWeekday[2]?.location, '(海甸)3-308');
      expect(slotsByWeekday[4]?.startSection, 5);
      expect(slotsByWeekday[4]?.endSection, 6);
      expect(slotsByWeekday[4]?.location, '(海甸)3-310');
    });
  });
}

const _sampleHtml = '''
<!doctype html>
<html>
<head><title>学期理论课表</title></head>
<body>
<form id="Form1" name="Form1" method="post">
  <select id="zc" name="zc">
    <option value="">(全部)</option>
    <option value="10">第10周</option>
  </select>
  <select id="xnxq01id" name="xnxq01id">
    <option value="2025-2026-2">2025-2026-2</option>
    <option value="2024-2025-2" selected="selected">2024-2025-2</option>
    <option value="2024-2025-1">2024-2025-1</option>
  </select>
  <select id="kbjcmsid" name="kbjcmsid">
    <option value="A4128A219A4D46158718C8ABF108B120">校区总时间</option>
  </select>
</form>
<table id="timetable">
  <tr>
    <th>&nbsp;</th>
    <th>星期一</th>
    <th>星期二</th>
    <th>星期三</th>
    <th>星期四</th>
    <th>星期五</th>
    <th>星期六</th>
    <th>星期日</th>
  </tr>
  <tr>
    <th>1、2节&nbsp;<br>(01,02小节)<br>07:40-09:20</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>3、4节&nbsp;<br>(03,04小节)<br>09:45-11:25</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>5、6节&nbsp;<br>(05,06小节)<br>14:30-16:10</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>7、8节&nbsp;<br>(07,08小节)<br>16:35-18:15</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>9、10、11节&nbsp;<br>(09,10,11小节)<br>19:20-21:55</th>
    <td></td>
    <td>
      <div id="E7649DD82E0C46BC897A0A15D1157426-2-2" style="position: relative;" class="kbcontent">
        <font>形势与政策8</font><br>
        <font title="教师">郎筱宇()</font><br>
        <font title="周次(节次)">10-11(周)[09-10节]</font><br>
        <font title="教学楼" name="jxlmc" style="display:none;">【海甸3号教学楼（致远楼C座）】</font>
        <font title="教室">(海甸)3-308</font><br>
        <font title="通知单编号">通知单编号：202420252012135</font>
      </div>
    </td>
    <td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>中午节次(一)&nbsp;<br>(12,13小节)<br>11:35-13:05</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>中午节次(二)&nbsp;<br>(14,15小节)<br>13:05-14:20</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
</table>
<table id="dataTables2">
  <tr><th colspan="15"><b>有课表课程</b></th></tr>
  <tr>
    <th>序号</th><th>上课班级</th><th>课程编号</th><th>课程名称</th><th>授课教师</th>
    <th>排课人数</th><th>选课人数</th><th>课程性质</th><th>课程属性</th><th>网课群号</th><th>网课链接网址</th><th>二维码</th>
  </tr>
  <tr>
    <td>1</td><td>2021-1班</td><td>Q00012</td><td>形势与政策8</td><td>郎筱宇</td>
    <td>100</td><td>100</td><td>公共基础必修课</td><td>必修</td><td></td><td></td><td>二维码</td>
  </tr>
</table>
</body>
</html>
''';

const _mergedHtml = '''
<!doctype html>
<html>
<head><title>学期理论课表</title></head>
<body>
<form id="Form1" name="Form1" method="post">
  <select id="xnxq01id" name="xnxq01id">
    <option value="2024-2025-2" selected="selected">2024-2025-2</option>
  </select>
</form>
<table id="timetable">
  <tr>
    <th>&nbsp;</th>
    <th>星期一</th>
    <th>星期二</th>
    <th>星期三</th>
    <th>星期四</th>
    <th>星期五</th>
    <th>星期六</th>
    <th>星期日</th>
  </tr>
  <tr>
    <th>1、2节&nbsp;<br>(01,02小节)<br>07:40-09:20</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>3、4节&nbsp;<br>(03,04小节)<br>09:45-11:25</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>5、6节&nbsp;<br>(05,06小节)<br>14:30-16:10</th>
    <td></td><td></td><td></td>
    <td>
      <div id="merged-2" style="position: relative;" class="kbcontent">
        <font>形势与政策8</font><br>
        <font title="教师">郎筱宇()</font><br>
        <font title="周次(节次)">10-11(周)[05-06节]</font><br>
        <font title="教室">(海甸)3-310</font><br>
        <font title="通知单编号">通知单编号：202420252012135</font>
      </div>
    </td>
    <td></td><td></td><td></td>
  </tr>
  <tr>
    <th>7、8节&nbsp;<br>(07,08小节)<br>16:35-18:15</th>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>9、10、11节&nbsp;<br>(09,10,11小节)<br>19:20-21:55</th>
    <td></td>
    <td>
      <div id="merged-1" style="position: relative;" class="kbcontent">
        <font>形势与政策8</font><br>
        <font title="教师">郎筱宇()</font><br>
        <font title="周次(节次)">10-11(周)[09-10节]</font><br>
        <font title="教室">(海甸)3-308</font><br>
        <font title="通知单编号">通知单编号：202420252012135</font>
      </div>
    </td>
    <td></td><td></td><td></td><td></td><td></td>
  </tr>
</table>
<table id="dataTables2">
  <tr><th colspan="15"><b>有课表课程</b></th></tr>
  <tr>
    <th>序号</th><th>上课班级</th><th>课程编号</th><th>课程名称</th><th>授课教师</th>
    <th>排课人数</th><th>选课人数</th><th>课程性质</th><th>课程属性</th><th>网课群号</th><th>网课链接网址</th><th>二维码</th>
  </tr>
  <tr>
    <td>1</td><td>2021-1班</td><td>Q00012</td><td>形势与政策8</td><td>郎筱宇</td>
    <td>100</td><td>100</td><td>公共基础必修课</td><td>必修</td><td></td><td></td><td>二维码</td>
  </tr>
</table>
</body>
</html>
''';
