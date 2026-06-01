import 'dart:convert';

class UndergraduateScheduleLoginScripts {
  static const targetUrl =
      'https://jxgl.hainanu.edu.cn/jsxsd/xskb/xskb_list.do';
  static const loginEntryUrl = 'https://jxgl.hainanu.edu.cn/jsxsd/';

  static String buildPageStateProbeScript({required String bridgeCall}) {
    return '''
      (function() {
        function post(status) {
          try {
            $bridgeCall('AUTOFILL_STATUS:' + status);
          } catch (_) {}
        }

        function text() {
          return (document.body ? (document.body.innerText || document.body.textContent || '') : '').trim();
        }

        var bodyText = text();
        var rawText = bodyText.replace(/\\s+/g, '');
        var normalizedLoginResponse = rawText.replace(/[\\{\\}\\[\\]"':,]/g, '');
        var loginFailureKeywords = [
          '\\u9a8c\\u8bc1\\u7801\\u9519\\u8bef',
          '\\u9a8c\\u8bc1\\u7801\\u4e0d\\u6b63\\u786e',
          '\\u9a8c\\u8bc1\\u7801\\u4e0d\\u80fd\\u4e3a\\u7a7a',
          '\\u7528\\u6237\\u540d\\u5bc6\\u7801\\u6709\\u8bef',
          '\\u7528\\u6237\\u540d\\u6216\\u5bc6\\u7801\\u9519\\u8bef',
          '\\u8d26\\u53f7\\u6216\\u5bc6\\u7801\\u9519\\u8bef',
          '\\u5bc6\\u7801\\u9519\\u8bef'
        ];

        function findLoginFailureText() {
          for (var i = 0; i < loginFailureKeywords.length; i++) {
            if (rawText.indexOf(loginFailureKeywords[i]) >= 0) {
              return loginFailureKeywords[i];
            }
          }
          if (normalizedLoginResponse.indexOf('flag0') >= 0) {
            return '\\u767b\\u5f55\\u5931\\u8d25\\uff0c\\u8bf7\\u91cd\\u65b0\\u8f93\\u5165\\u9a8c\\u8bc1\\u7801';
          }
          return '';
        }

        var loginFailureText = findLoginFailureText();
        if (loginFailureText) {
          $bridgeCall('LOGIN_ERROR:' + loginFailureText);
          return;
        }

        if (rawText.indexOf('\\u9875\\u9762\\u672a\\u627e\\u5230') >= 0 ||
            rawText.toLowerCase().indexOf('404') >= 0) {
          post('UNDERGRAD_NOT_FOUND');
          return;
        }

        var hasSchedule =
            !!document.querySelector('#xnxq01id') &&
            !!document.querySelector('#timetable');
        if (hasSchedule) {
          post('UNDERGRAD_SCHEDULE_READY');
          return;
        }

        var hasLoginForm =
            !!document.querySelector('#loginForm') &&
            !!document.querySelector('#userAccount') &&
            !!document.querySelector('#userPassword') &&
            !!document.querySelector('#RANDOMCODE');
        if (hasLoginForm) {
          post('UNDERGRAD_LOGIN_PAGE');
          return;
        }

        if (rawText.indexOf('"flag1"') >= 0 ||
            rawText.indexOf('flag1') >= 0 ||
            normalizedLoginResponse.indexOf('flag1') >= 0) {
          post('UNDERGRAD_LOGIN_RESPONSE');
          return;
        }

        if (document.querySelector('#Top1_divLoginName') ||
            location.pathname.toLowerCase().indexOf('/jsxsd/framework/xsmain') >= 0) {
          post('UNDERGRAD_HOME_READY');
          return;
        }

        post('UNDERGRAD_UNKNOWN_PAGE');
      })();
    ''';
  }

  static String buildDetectSemesterScript({
    required String bridgeCall,
    required String requestId,
  }) {
    final requestIdLiteral = jsonEncode(requestId);
    return '''
      (function() {
        var requestId = $requestIdLiteral;

        function normalize(value) {
          return (value || '').toString().trim();
        }

        function normalizeSemester(value) {
          var raw = normalize(value);
          var legacy = raw.match(/^(20\\d{2})([12])\$/);
          if (legacy) return legacy[1] + legacy[2];
          var match = raw.match(/^(20\\d{2})-20\\d{2}-([12])\$/);
          return match ? match[1] + match[2] : '';
        }

        function postSemester(value) {
          $bridgeCall('SEMESTER:' + requestId + ':' + (value || ''));
        }

        function postSemesterOptions(items) {
          try {
            $bridgeCall('SEMESTER_OPTIONS:' + requestId + ':' + JSON.stringify(items || []));
          } catch (_) {}
        }

        var select = document.querySelector('#xnxq01id');
        var seen = {};
        var options = [];
        if (select) {
          Array.prototype.slice.call(select.options || []).forEach(function(option) {
            var value = normalize(option.value || option.text || option.label);
            var code = normalizeSemester(value);
            if (!code || seen[code]) return;
            seen[code] = true;
            options.push({ code: code, name: normalize(option.text || value) });
          });
        }

        postSemesterOptions(options);

        var selectedCode = '';
        if (select) {
          selectedCode = normalizeSemester(select.value);
          if (!selectedCode && select.selectedIndex >= 0) {
            selectedCode = normalizeSemester(select.options[select.selectedIndex].value);
          }
        }
        if (!selectedCode && options.length > 0) {
          selectedCode = options[0].code;
        }
        postSemester(selectedCode);
      })();
    ''';
  }

  static String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) {
    final semesterLiteral = jsonEncode(_toUndergraduateSemester(semester));
    final requestIdLiteral = jsonEncode(requestId);
    return '''
      (function() {
        var requestId = $requestIdLiteral;

        function normalize(value) {
          return (value || '').toString().trim();
        }

        function post(prefix, payload) {
          $bridgeCall(prefix + requestId + ':' + payload);
        }

        function postPayload(text) {
          var chunkSize = 400;
          var total = Math.ceil(text.length / chunkSize);
          post('CHUNK_START:', total + ':' + text.length);
          for (var i = 0; i < total; i++) {
            var chunk = text.substring(i * chunkSize, Math.min((i + 1) * chunkSize, text.length));
            post('CHUNK_DATA:', i + ':' + chunk);
          }
          $bridgeCall('CHUNK_END:' + requestId);
        }

        function buildUrl(semesterValue) {
          var timeModeSelect = document.querySelector('#kbjcmsid');
          var timeMode = timeModeSelect ? normalize(timeModeSelect.value) : '';
          var params = [
            'xnxq01id=' + encodeURIComponent(semesterValue),
            'zc=',
            'kbjcmsid=' + encodeURIComponent(timeMode),
            'sfFD=1',
            'wkbkc=1',
            'xstzd=1',
            'xswk=1'
          ].join('&');
          return '/jsxsd/xskb/xskb_list.do?' + params;
        }

        var semesterValue = $semesterLiteral;
        var xhr = new XMLHttpRequest();
        xhr.open('GET', buildUrl(semesterValue), true);
        xhr.withCredentials = true;
        xhr.onreadystatechange = function() {
          if (xhr.readyState !== 4) return;
          if (xhr.status !== 200) {
            post('SCHEDULE_ERR:', 'HTTP ' + xhr.status);
            return;
          }
          postPayload(xhr.responseText || '');
        };
        xhr.onerror = function() {
          post('SCHEDULE_ERR:', '\\u7f51\\u7edc\\u9519\\u8bef');
        };
        xhr.send();
      })();
    ''';
  }

  static String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) {
    final requestedSemesterLiteral = jsonEncode(semester);
    final semesterLiteral = jsonEncode(_toUndergraduateSemester(semester));
    final requestIdLiteral = jsonEncode(requestId);
    return '''
      (function() {
        var requestId = $requestIdLiteral;

        function normalize(value) {
          return (value || '').toString().trim();
        }

        var target = $semesterLiteral;
        var select = document.querySelector('#xnxq01id');
        if (!select) {
          $bridgeCall('SEMESTER_SWITCH_ERR:' + requestId + ':' + target);
          return;
        }

        var matched = Array.prototype.slice.call(select.options || []).some(function(option) {
          return normalize(option.value) === target;
        });
        if (!matched) {
          $bridgeCall('SEMESTER_SWITCH_ERR:' + requestId + ':' + target);
          return;
        }

        select.value = target;
        select.setAttribute('value', target);
        Array.prototype.slice.call(select.options || []).forEach(function(option) {
          var selected = normalize(option.value) === target;
          option.selected = selected;
          if (selected) {
            option.setAttribute('selected', 'selected');
          } else {
            option.removeAttribute('selected');
          }
        });
        $bridgeCall('SEMESTER_SWITCHED:' + requestId + ':' + $requestedSemesterLiteral);
      })();
    ''';
  }

  static String _toUndergraduateSemester(String semester) {
    final normalized = semester.trim();
    if (RegExp(r'^20\d{2}-20\d{2}-[12]$').hasMatch(normalized)) {
      return normalized;
    }
    final match = RegExp(r'^(20\d{2})([12])$').firstMatch(normalized);
    if (match == null) return normalized;
    final startYear = int.parse(match.group(1)!);
    return '${match.group(1)}-${startYear + 1}-${match.group(2)}';
  }
}
