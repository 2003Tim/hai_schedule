import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/schedule_login_fetch_service.dart';

void main() {
  group('ScheduleLoginFetchService', () {
    late ScheduleLoginFetchService service;

    setUp(() {
      service = ScheduleLoginFetchService();
    });

    test('identifies login and target urls correctly', () {
      expect(
        service.isLoginUrl('https://cas.example.edu/login?service=abc'),
        isTrue,
      );
      expect(
        service.shouldAutoFetch(
          'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do',
        ),
        isTrue,
      );
      expect(service.shouldAutoFetch('https://cas.example.edu/login'), isFalse);
    });

    test('builds detect semester script with platform bridge call', () {
      final script = service.buildDetectSemesterScript(
        'FlutterBridge.postMessage',
      );

      expect(script, contains('FlutterBridge.postMessage'));
      expect(script, contains("SEMESTER:"));
      expect(script, contains("querySelectorAll('select')"));
    });

    test('builds fetch schedule script with semester and bridge call', () {
      final script = service.buildFetchScheduleScript(
        bridgeCall: 'window.chrome.webview.postMessage',
        semester: '20252',
      );

      expect(script, contains('window.chrome.webview.postMessage'));
      expect(script, contains("querySelectorAll('select')"));
      expect(script, contains("select.value = normalized"));
      expect(
        script,
        contains(
          "https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do?_=",
        ),
      );
      expect(script, contains("XNXQDM="));
      expect(script, contains("&XH="));
      expect(script, contains("&pageNumber="));
      expect(script, contains("&pageSize="));
      expect(script, contains('fetchPage(1, null)'));
      expect(script, contains('CHUNK_START:'));
      expect(script, contains('SCHEDULE_ERR:HTTP'));
    });

    test('builds switch semester script with bridge call', () {
      final script = service.buildSwitchSemesterScript(
        bridgeCall: 'FlutterBridge.postMessage',
        semester: '20251',
      );

      expect(script, contains('FlutterBridge.postMessage'));
      expect(script, contains('SEMESTER_SWITCHED:'));
      expect(script, contains('SEMESTER_SWITCH_ERR:'));
      expect(script, contains("querySelectorAll('select')"));
    });

    test('assembles chunk messages into final payload', () {
      final chunkState = LoginFetchChunkState();
      final statuses = <String>[];
      final detectedSemesters = <String>[];
      final payloads = <String>[];
      final errors = <String>[];

      void handle(String message) {
        service.handleBridgeMessage(
          message: message,
          chunkState: chunkState,
          onStatus: statuses.add,
          onSemesterDetected: detectedSemesters.add,
          onSemesterSwitched: (_) {},
          onPayloadReady: payloads.add,
          onError: errors.add,
        );
      }

      handle('SEMESTER:20252');
      handle('CHUNK_START:2:8');
      handle('CHUNK_DATA:0:abcd');
      handle('CHUNK_DATA:1:1234');
      handle('CHUNK_END');

      expect(detectedSemesters, ['20252']);
      expect(chunkState.expectedChunks, 2);
      expect(chunkState.receivedChunks, 2);
      expect(statuses, isNotEmpty);
      expect(payloads.single, 'abcd1234');
      expect(errors, isEmpty);
    });

    test('forwards schedule error messages', () {
      final chunkState = LoginFetchChunkState();
      final errors = <String>[];

      service.handleBridgeMessage(
        message: 'SCHEDULE_ERR:HTTP 500',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: errors.add,
      );

      expect(errors, ['HTTP 500']);
    });

    test('builds diff summary for added removed and changed courses', () {
      final previous = [
        Course(
          id: '1',
          code: 'MATH001',
          name: '高等数学',
          className: '数学一班',
          teacher: '张老师',
          college: '理学院',
          credits: 4,
          totalHours: 64,
          semester: '20252',
          slots: [
            ScheduleSlot(
              courseId: '1',
              courseName: '高等数学',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              location: '教一-101',
              weekRanges: [WeekRange(start: 1, end: 16)],
            ),
          ],
        ),
        Course(
          id: '2',
          code: 'PHY001',
          name: '大学物理',
          className: '物理二班',
          teacher: '王老师',
          college: '理学院',
          credits: 3,
          totalHours: 48,
          semester: '20252',
          slots: [
            ScheduleSlot(
              courseId: '2',
              courseName: '大学物理',
              weekday: 3,
              startSection: 3,
              endSection: 4,
              location: '教二-201',
              weekRanges: [WeekRange(start: 1, end: 16)],
            ),
          ],
        ),
      ];

      final current = [
        Course(
          id: '1',
          code: 'MATH001',
          name: '高等数学',
          className: '数学一班',
          teacher: '张老师',
          college: '理学院',
          credits: 4,
          totalHours: 64,
          semester: '20252',
          slots: [
            ScheduleSlot(
              courseId: '1',
              courseName: '高等数学',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              location: '教一-102',
              weekRanges: [WeekRange(start: 1, end: 16)],
            ),
          ],
        ),
        Course(
          id: '3',
          code: 'CHEM001',
          name: '大学化学',
          className: '化学一班',
          teacher: '赵老师',
          college: '化工学院',
          credits: 2,
          totalHours: 32,
          semester: '20252',
          slots: [
            ScheduleSlot(
              courseId: '3',
              courseName: '大学化学',
              weekday: 5,
              startSection: 1,
              endSection: 2,
              location: '教三-301',
              weekRanges: [WeekRange(start: 1, end: 16)],
            ),
          ],
        ),
      ];

      final summary = AutoSyncService.buildCourseDiffSummary(previous, current);
      expect(summary, '新增 1 门，移除 1 门，调整 1 门');
    });
  });
}
