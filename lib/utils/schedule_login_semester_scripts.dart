import 'dart:convert';

class ScheduleLoginSemesterScripts {
  static const apiUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';

  static String buildDetectSemesterScript({
    required String bridgeCall,
    required String requestId,
  }) {
    final requestIdLiteral = jsonEncode(requestId);
    return '''
      (function() {
        var semester = '';
        var requestId = $requestIdLiteral;

        function postSemester(value) {
          $bridgeCall('SEMESTER:' + requestId + ':' + (value || ''));
        }

        var selects = document.querySelectorAll('select');
        for (var i = 0; i < selects.length; i++) {
          var val = selects[i].value;
          if (val && /^\\d{4,5}\$/.test(val)) {
            semester = val;
            break;
          }
        }

        if (!semester) {
          var text = document.body.innerText || '';
          var m = text.match(/(20\\d{2})-(20\\d{2})\\u5b66\\u5e74\\s*\\u7b2c?([\\u4e00\\u4e8c12])\\u5b66\\u671f/);
          if (m) {
            semester = m[1] + ((m[3] === '\\u4e00' || m[3] === '1') ? '1' : '2');
          }
        }

        if (!semester) {
          var html = document.documentElement.innerHTML || '';
          var semesterMatch = html.match(/XNXQDM['"":\\s=]+(20\\d{3})/);
          if (semesterMatch) {
            semester = semesterMatch[1];
          }
        }

        if (!semester) {
          var now = new Date();
          var year = now.getFullYear();
          var month = now.getMonth() + 1;
          if (month >= 8 || month <= 1) {
            semester = (month >= 8 ? year : year - 1) + '1';
          } else {
            semester = (year - 1) + '2';
          }
        }

        postSemester(semester);
      })();
    ''';
  }

  static String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) {
    final semesterLiteral = jsonEncode(semester);
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

        function trySwitchSemester(value) {
          var normalized = normalize(value);
          var matched = false;
          var selects = Array.prototype.slice.call(document.querySelectorAll('select'));

          selects.forEach(function(select) {
            var options = Array.prototype.slice.call(select.options || []);
            var hasMatch = options.some(function(option) {
              return normalize(option.value) === normalized;
            });
            if (!hasMatch) return;

            select.value = normalized;
            select.setAttribute('value', normalized);
            ['input', 'change', 'blur'].forEach(function(eventName) {
              select.dispatchEvent(new Event(eventName, { bubbles: true }));
            });
            matched = true;
          });

          var inputs = Array.prototype.slice.call(
            document.querySelectorAll('input[name*=XNXQDM], input[id*=XNXQDM], input[value]')
          );
          inputs.forEach(function(input) {
            var current = normalize(input.value);
            if (current === normalized || /^(20\\d{3})\$/.test(current)) {
              input.value = normalized;
              matched = true;
            }
          });

          return matched;
        }

        function fetchSchedule() {
          var pageSize = 100;
          var maxPages = 20;

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

          function extractRows(root) {
            if (!root || typeof root !== 'object' || !root.datas) {
              return null;
            }
            var dataKeys = Object.keys(root.datas);
            for (var i = 0; i < dataKeys.length; i++) {
              var child = root.datas[dataKeys[i]];
              if (child && Array.isArray(child.rows)) {
                return child.rows;
              }
            }
            return null;
          }

          function mergeRows(targetRoot, pageRoot) {
            var targetRows = extractRows(targetRoot);
            var pageRows = extractRows(pageRoot);
            if (!targetRows || !pageRows) {
              return;
            }
            for (var i = 0; i < pageRows.length; i++) {
              targetRows.push(pageRows[i]);
            }
          }

          function fetchPage(pageNumber, aggregate) {
            var timestamp = Date.now();
            var xhr = new XMLHttpRequest();
            xhr.open('POST', '$apiUrl?_=' + timestamp, true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            xhr.withCredentials = true;
            xhr.onreadystatechange = function() {
              if (xhr.readyState !== 4) return;
              if (xhr.status !== 200) {
                post('SCHEDULE_ERR:', 'HTTP ' + xhr.status);
                return;
              }

              try {
                var pageRoot = JSON.parse(xhr.responseText);
                if (String(pageRoot.code || '') !== '0') {
                  if (pageNumber === 1) {
                    postPayload(xhr.responseText);
                  } else {
                    post('SCHEDULE_ERR:', '\\u5206\\u9875\\u63a5\\u53e3\\u5f02\\u5e38 code=' + pageRoot.code);
                  }
                  return;
                }

                var nextAggregate = aggregate || pageRoot;
                if (aggregate) {
                  mergeRows(nextAggregate, pageRoot);
                }

                var pageRows = extractRows(pageRoot) || [];
                if (pageRows.length >= pageSize && pageNumber >= maxPages) {
                  post('SCHEDULE_ERR:', '\\u5206\\u9875\\u8d85\\u51fa\\u5b89\\u5168\\u4e0a\\u9650');
                  return;
                }
                if (pageRows.length >= pageSize && pageNumber < maxPages) {
                  fetchPage(pageNumber + 1, nextAggregate);
                  return;
                }

                postPayload(JSON.stringify(nextAggregate));
              } catch (err) {
                post(
                  'SCHEDULE_ERR:',
                  '\\u89e3\\u6790\\u5931\\u8d25 ' + (err && err.message ? err.message : err)
                );
              }
            };
            xhr.onerror = function() {
              post('SCHEDULE_ERR:', '\\u7f51\\u7edc\\u9519\\u8bef');
            };
            xhr.send(
              'XNXQDM=' +
                  encodeURIComponent($semesterLiteral) +
                  '&XH=' +
                  encodeURIComponent('') +
                  '&pageNumber=' +
                  pageNumber +
                  '&pageSize=' +
                  pageSize
            );
          }

          fetchPage(1, null);
        }

        trySwitchSemester($semesterLiteral);
        setTimeout(fetchSchedule, 350);
      })();
    ''';
  }

  static String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) {
    final semesterLiteral = jsonEncode(semester);
    final requestIdLiteral = jsonEncode(requestId);
    return '''
      (function() {
        function normalize(value) {
          return (value || '').toString().trim();
        }

        var target = normalize($semesterLiteral);
        var requestId = $requestIdLiteral;
        var switched = false;

        var selects = Array.prototype.slice.call(document.querySelectorAll('select'));
        selects.forEach(function(select) {
          var options = Array.prototype.slice.call(select.options || []);
          var hasMatch = options.some(function(option) {
            return normalize(option.value) === target;
          });
          if (!hasMatch) return;

          select.value = target;
          select.setAttribute('value', target);
          ['input', 'change', 'blur'].forEach(function(eventName) {
            select.dispatchEvent(new Event(eventName, { bubbles: true }));
          });
          switched = true;
        });

        var hiddenFields = Array.prototype.slice.call(
          document.querySelectorAll('input[name*=XNXQDM], input[id*=XNXQDM]')
        );
        hiddenFields.forEach(function(field) {
          field.value = target;
          switched = true;
        });

        if (!switched) {
          $bridgeCall('SEMESTER_SWITCH_ERR:' + requestId + ':' + target);
          return;
        }

        setTimeout(function() {
          $bridgeCall('SEMESTER_SWITCHED:' + requestId + ':' + target);
        }, 600);
      })();
    ''';
  }
}
