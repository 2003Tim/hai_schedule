import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/services/schedule_login_fetch_service.dart';
import 'package:hai_schedule/utils/login_fetch_payload_parser.dart';

void main() {
  group('ScheduleLoginFetchService source routing', () {
    test('keeps graduate defaults unchanged', () {
      final service = ScheduleLoginFetchService();

      expect(service.source, ScheduleSource.graduate);
      expect(
        service.resolvedTargetUrl,
        'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do',
      );
      expect(
        service.shouldAutoFetch(
          'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do',
        ),
        isTrue,
      );
    });

    test('uses undergraduate target and HTML fetch script', () {
      final service = ScheduleLoginFetchService(
        source: ScheduleSource.undergraduate,
      );

      expect(
        service.resolvedTargetUrl,
        'https://jxgl.hainanu.edu.cn/jsxsd/xskb/xskb_list.do',
      );
      expect(service.resolvedInitialUrl, 'https://jxgl.hainanu.edu.cn/jsxsd/');
      expect(
        service.resolvedLoginEntryUrl,
        'https://jxgl.hainanu.edu.cn/jsxsd/',
      );
      expect(service.shouldAutoFetch(service.resolvedTargetUrl), isTrue);
      expect(service.isLoginUrl(service.resolvedTargetUrl), isFalse);

      final script = service.buildFetchScheduleScript(
        bridgeCall: 'FlutterBridge.postMessage',
        semester: '20242',
        requestId: 'req-benke',
      );

      expect(script, contains('FlutterBridge.postMessage'));
      expect(script, contains('req-benke'));
      expect(script, contains('/jsxsd/xskb/xskb_list.do'));
      expect(script, contains('2024-2025-2'));
      expect(script, contains('CHUNK_START:'));
      expect(script, contains('CHUNK_END:'));
      expect(script, isNot(contains('xsjxrwcx.do')));
    });

    test(
      'undergraduate fetch script preserves current time mode parameter',
      () {
        final service = ScheduleLoginFetchService(
          source: ScheduleSource.undergraduate,
        );

        final script = service.buildFetchScheduleScript(
          bridgeCall: 'FlutterBridge.postMessage',
          semester: '20211',
          requestId: 'req-old-benke',
        );

        expect(script, contains("querySelector('#kbjcmsid')"));
        expect(script, contains('2021-2022-1'));
        expect(script, contains('kbjcmsid='));
        expect(script, contains("'kbjcmsid=' + encodeURIComponent(timeMode)"));
        expect(script, isNot(contains("'kbjcmsid=',")));
      },
    );

    test('undergraduate switch script does not submit the portal form', () {
      final service = ScheduleLoginFetchService(
        source: ScheduleSource.undergraduate,
      );

      final script = service.buildSwitchSemesterScript(
        bridgeCall: 'FlutterBridge.postMessage',
        semester: '20211',
        requestId: 'req-switch-old-benke',
      );

      expect(script, contains("querySelector('#xnxq01id')"));
      expect(script, contains('2021-2022-1'));
      expect(script, contains('SEMESTER_SWITCHED:'));
      expect(script, contains('SEMESTER_SWITCH_ERR:'));
      expect(script, isNot(contains('dispatchEvent')));
      expect(script, isNot(contains('Form1')));
      expect(script, isNot(contains('submit()')));
    });

    test('probes undergraduate DOM before treating target URL as schedule', () {
      final service = ScheduleLoginFetchService(
        source: ScheduleSource.undergraduate,
      );

      expect(service.shouldProbePageState(service.resolvedTargetUrl), isTrue);
      expect(
        service.shouldProbePageState(
          'https://jxgl.hainanu.edu.cn/jsxsd/xk/LoginToXkLdap',
        ),
        isTrue,
      );

      final script = service.buildPageStateProbeScript(
        bridgeCall: 'FlutterBridge.postMessage',
      );

      expect(script, contains('UNDERGRAD_SCHEDULE_READY'));
      expect(script, contains('UNDERGRAD_LOGIN_PAGE'));
      expect(script, contains('UNDERGRAD_LOGIN_RESPONSE'));
      expect(script, contains('UNDERGRAD_HOME_READY'));
      expect(script, contains('UNDERGRAD_NOT_FOUND'));
      expect(script, contains('#xnxq01id'));
      expect(script, contains('#timetable'));
      expect(script, contains('#loginForm'));
      expect(script, contains('#userAccount'));
      expect(script, contains('#RANDOMCODE'));
      expect(script, contains('\\u9875\\u9762\\u672a\\u627e\\u5230'));
      expect(script, contains('flag1'));
      expect(script, contains('normalizedLoginResponse.indexOf'));
    });

    test(
      'keeps undergraduate saved credential fill manual because captcha is required',
      () {
        final service = ScheduleLoginFetchService(
          source: ScheduleSource.undergraduate,
        );

        final script = service.buildFillCredentialScript(
          username: 'under-user',
          password: 'under-pass',
          bridgeCall: 'FlutterBridge.postMessage',
          autoSubmit: true,
        );

        expect(script, contains('FlutterBridge.postMessage'));
        expect(script, contains('attempt(false);'));
        expect(script, isNot(contains('attempt(true);')));
      },
    );

    test('observes undergraduate manual login submit controls', () {
      final service = ScheduleLoginFetchService(
        source: ScheduleSource.undergraduate,
      );

      final script = service.buildManualLoginObserverScript(
        bridgeCall: 'FlutterBridge.postMessage',
      );

      expect(script, contains('FlutterBridge.postMessage'));
      expect(script, contains('MANUAL_LOGIN_SUBMITTED'));
      expect(script, contains('#btn-login'));
      expect(script, contains('#userAccount'));
      expect(script, contains('#userPassword'));
      expect(script, contains('#RANDOMCODE'));
    });

    test('upgrades undergraduate cleartext portal redirects to https', () {
      final service = ScheduleLoginFetchService(
        source: ScheduleSource.undergraduate,
      );

      // Cleartext portal redirects are upgraded to https.
      expect(
        service.normalizeNavigationUrl(
          'http://jxgl.hainanu.edu.cn/jsxsd/framework/xsMainV.html',
        ),
        'https://jxgl.hainanu.edu.cn/jsxsd/framework/xsMainV.html',
      );
      // Already-https allow-listed hosts are normalised unchanged
      // (#S2: previously the graduate path returned null unconditionally,
      // now every source uses the same allow-list).
      expect(
        service.normalizeNavigationUrl(
          'https://jxgl.hainanu.edu.cn/jsxsd/framework/xsMainV.html',
        ),
        'https://jxgl.hainanu.edu.cn/jsxsd/framework/xsMainV.html',
      );
      expect(
        service.normalizeNavigationUrl(
          'http://example.com/jsxsd/framework/xsMainV.html',
        ),
        isNull,
      );
      // Default (graduate) service also accepts allow-listed hosts now
      // (#S2). A jxgl URL is upgraded to https unconditionally.
      expect(
        ScheduleLoginFetchService().normalizeNavigationUrl(
          'http://jxgl.hainanu.edu.cn/jsxsd/framework/xsMainV.html',
        ),
        'https://jxgl.hainanu.edu.cn/jsxsd/framework/xsMainV.html',
      );
      // Hosts outside the allow-list remain rejected for every source.
      expect(
        ScheduleLoginFetchService().normalizeNavigationUrl(
          'http://attacker.example.com/foo',
        ),
        isNull,
      );
    });
  });

  group('LoginFetchPayloadParser source routing', () {
    test('parses undergraduate HTML payload', () {
      final courses = LoginFetchPayloadParser.parseCourses(
        _undergraduateHtml,
        source: ScheduleSource.undergraduate,
      );

      expect(courses, hasLength(1));
      expect(courses.single.name, '形势与政策8');
      expect(courses.single.slots.single.weekday, 2);
    });
  });
}

const _undergraduateHtml = '''
<html>
<body>
<select id="xnxq01id"><option selected value="2024-2025-2">2024-2025-2</option></select>
<table id="timetable">
  <tr><th></th><th>星期一</th><th>星期二</th></tr>
  <tr><th>9、10、11节<br>(09,10,11小节)<br>19:20-21:55</th><td></td><td>
    <div class="kbcontent">
      <font>形势与政策8</font><font title="教师">郎筱宇()</font>
      <font title="周次(节次)">10-11(周)[09-10节]</font>
      <font title="教室">(海甸)3-308</font>
      <font title="通知单编号">通知单编号：202420252012135</font>
    </div>
  </td></tr>
</table>
</body>
</html>
''';
