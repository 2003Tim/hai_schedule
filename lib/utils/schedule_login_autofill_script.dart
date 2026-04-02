import 'dart:convert';

class ScheduleLoginAutofillScript {
  static String build({
    required String username,
    required String password,
    String? bridgeCall,
    bool autoSubmit = true,
  }) {
    final usernameLiteral = jsonEncode(username);
    final passwordLiteral = jsonEncode(password);
    final hasBridge = bridgeCall != null ? 'true' : 'false';
    final bridgePoster = bridgeCall == null ? '' : '$bridgeCall(message);';
    final autoSubmitLiteral = autoSubmit ? 'true' : 'false';

    return [
      _partOne(hasBridge: hasBridge, bridgePoster: bridgePoster),
      _partTwo(),
      _partThree(),
      _partFour(
        usernameLiteral: usernameLiteral,
        passwordLiteral: passwordLiteral,
        autoSubmitLiteral: autoSubmitLiteral,
      ),
    ].join();
  }

  static String _partOne({
    required String hasBridge,
    required String bridgePoster,
  }) {
    return '''
      (function() {
        var runtime = window.__haiScheduleAutofillState = window.__haiScheduleAutofillState || {
          locationKey: '',
          switchRequestedAt: 0,
          submittedAt: 0
        };

        function post(message) {
          if (!$hasBridge) return;
          try {
            $bridgePoster
          } catch (_) {}
        }

        function now() {
          return Date.now ? Date.now() : new Date().getTime();
        }

        function normalize(value) {
          return (value || '').toString().trim().toLowerCase();
        }

        function visible(node) {
          if (!node) return false;
          if (node.disabled) return false;
          var style = window.getComputedStyle(node);
          if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
            return false;
          }
          if (node.type && normalize(node.type) === 'hidden') {
            return false;
          }
          var rect = node.getBoundingClientRect ? node.getBoundingClientRect() : null;
          if (!rect) return true;
          return rect.width > 0 || rect.height > 0;
        }

        function pick(selectors, allowHidden) {
          for (var i = 0; i < selectors.length; i++) {
            var node = document.querySelector(selectors[i]);
            if (node && (allowHidden || visible(node))) {
              return node;
            }
          }
          return null;
        }

        function textOf(node) {
          if (!node) return '';
          return normalize([
            node.id,
            node.name,
            node.type,
            node.value,
            node.placeholder,
            node.innerText,
            node.textContent,
            node.getAttribute ? node.getAttribute('title') : '',
            node.getAttribute ? node.getAttribute('aria-label') : '',
          ].join(' '));
        }

        function containsKeyword(value, keywords) {
          var text = normalize(value);
          for (var i = 0; i < keywords.length; i++) {
            if (text.indexOf(normalize(keywords[i])) >= 0) {
              return true;
            }
          }
          return false;
        }

        function postResult(usernameFilled, passwordFilled, submitted, verificationRequired) {
          post(
            'AUTOFILL_RESULT:' +
                (usernameFilled ? '1' : '0') + ':' +
                (passwordFilled ? '1' : '0') + ':' +
                (submitted ? '1' : '0') + ':' +
                (verificationRequired ? '1' : '0')
          );
        }

        function isRecent(timestamp, ms) {
          return timestamp > 0 && (now() - timestamp) < ms;
        }

        var locationKey = '';
        try {
          locationKey = window.location ? (window.location.pathname + window.location.search) : '';
        } catch (_) {}
        if (runtime.locationKey !== locationKey) {
          runtime.locationKey = locationKey;
          runtime.switchRequestedAt = 0;
          runtime.submittedAt = 0;
        }

        function setNativeValue(node, value) {
          if (!node) return false;
          var prototype = node.tagName === 'TEXTAREA'
              ? window.HTMLTextAreaElement.prototype
              : window.HTMLInputElement.prototype;
          var descriptor = Object.getOwnPropertyDescriptor(prototype, 'value');
          if (descriptor && descriptor.set) {
            descriptor.set.call(node, value);
          } else {
            node.value = value;
          }
          return true;
        }

        function applyValue(node, value) {
          if (!node) return false;
          if (normalize(node.value) === normalize(value)) {
            return true;
          }
          try {
            node.focus();
          } catch (_) {}
          setNativeValue(node, value);
          try {
            node.dispatchEvent(new InputEvent('input', { bubbles: true, data: value }));
          } catch (_) {
            node.dispatchEvent(new Event('input', { bubbles: true }));
          }
          ['change', 'keyup', 'blur'].forEach(function(eventName) {
            try {
              node.dispatchEvent(new Event(eventName, { bubbles: true }));
            } catch (_) {}
          });
          return normalize(node.value) === normalize(value);
        }

        function setNativeChecked(node, checked) {
          if (!node) return false;
          var descriptor = Object.getOwnPropertyDescriptor(
            window.HTMLInputElement.prototype,
            'checked'
          );
          if (descriptor && descriptor.set) {
            descriptor.set.call(node, checked);
          } else {
            node.checked = checked;
          }
          return !!node.checked === !!checked;
        }

        function triggerClick(node) {
          if (!node) return false;
          ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function(eventName) {
            try {
              node.dispatchEvent(
                new MouseEvent(eventName, {
                  bubbles: true,
                  cancelable: true,
                  view: window
                })
              );
            } catch (_) {
              try {
                node.dispatchEvent(new Event(eventName, { bubbles: true, cancelable: true }));
              } catch (_) {}
            }
          });
          try {
            node.click();
          } catch (_) {}
          return true;
        }
    ''';
  }

  static String _partTwo() {
    return '''
        function findQrImage() {
          return pick([
            'img#qr_img[src*="/authserver/qrCode/getCode"]',
            'img#qr_img'
          ], false);
        }

        function findSwitchToPasswordTrigger() {
          return pick([
            'img.login-type-btn[src*="/authserver/newhainanuaz/static/web/images/pc.png"]',
            'img.login-type-btn[src*="pc.png"]',
            '.login-type-btn'
          ], false);
        }

        function findUsernameNode() {
          var direct = pick([
            'input#username[name="username"]',
            'input#username',
            'input[name="username"]',
            'input[autocomplete="username"]',
            'input[name*="user"]',
            'input[id*="user"]'
          ], false);
          if (direct) return direct;

          var inputs = Array.prototype.slice.call(document.querySelectorAll('input'));
          for (var i = 0; i < inputs.length; i++) {
            var node = inputs[i];
            if (!visible(node)) continue;
            if (normalize(node.type) === 'password') continue;
            if (containsKeyword(textOf(node), [
              '\\u5b66\\u53f7',
              '\\u5de5\\u53f7',
              'username',
              'account',
              '\\u8d26\\u53f7'
            ])) {
              return node;
            }
          }
          return null;
        }

        function findPasswordNode() {
          var usernameNode = findUsernameNode();
          if (usernameNode) {
            var form = usernameNode.form || usernameNode.closest('form');
            if (form) {
              var scoped = form.querySelector(
                'input#password[name="passwordText"], #password[name="passwordText"], #password, input#password, input[name="password"], input[name="passwordText"], input[type="password"], input[name*="pass"], input[id*="pass"], input[name*="pwd"], input[id*="pwd"]'
              );
              if (scoped && visible(scoped)) {
                return scoped;
              }
            }
          }

          var direct = pick([
            'input#password[name="passwordText"]',
            '#password[name="passwordText"]',
            '#password',
            'input#password',
            'input[name="password"]',
            'input[name="passwordText"]',
            'input[autocomplete="current-password"]',
            'input[name*="pass"]',
            'input[id*="pass"]',
            'input[name*="pwd"]',
            'input[id*="pwd"]',
            'input[type="password"]',
          ], false);
          if (direct) return direct;

          var inputs = Array.prototype.slice.call(document.querySelectorAll('input'));
          for (var i = 0; i < inputs.length; i++) {
            var node = inputs[i];
            if (!visible(node)) continue;
            if (containsKeyword(textOf(node), ['password', 'pass', 'pwd', '\\u5bc6\\u7801'])) {
              return node;
            }
          }
          return null;
        }

        function findTrustCheckbox() {
          var exact = pick([
            'input#rememberMe[name="rememberMe"]',
            'input#rememberMe',
            'input[name="rememberMe"]'
          ], false);
          if (exact) {
            return exact;
          }

          var boxes = Array.prototype.slice.call(
            document.querySelectorAll('input[type="checkbox"]')
          );
          for (var i = 0; i < boxes.length; i++) {
            var node = boxes[i];
            var combinedText = textOf(node) + ' ' + textOf(node.parentElement) + ' ' +
                textOf(node.closest ? node.closest('label') : null);
            if (containsKeyword(combinedText, [
              '7\\u5929',
              '\\u4e03\\u5929',
              '7\\u65e5',
              '\\u4e03\\u65e5',
              '\\u8bb0\\u4f4f',
              '\\u514d\\u767b\\u5f55',
              'remember',
              'trust'
            ])) {
              return node;
            }
          }
          return null;
        }

        function enableTrustOption() {
          var checkbox = findTrustCheckbox();
          if (checkbox) {
            if (!checkbox.checked) {
              triggerClick(checkbox);
              if (!checkbox.checked) {
                setNativeChecked(checkbox, true);
              }
              ['input', 'change'].forEach(function(eventName) {
                try {
                  checkbox.dispatchEvent(new Event(eventName, { bubbles: true }));
                } catch (_) {}
              });
            }
            return !!checkbox.checked;
          }

          var labels = Array.prototype.slice.call(
            document.querySelectorAll('label, span, div, a')
          );
          for (var i = 0; i < labels.length; i++) {
            var node = labels[i];
            if (!visible(node)) continue;
            if (!containsKeyword(textOf(node), [
              '7\\u5929',
              '\\u4e03\\u5929',
              '7\\u65e5',
              '\\u4e03\\u65e5',
              '\\u8bb0\\u4f4f',
              '\\u514d\\u767b\\u5f55',
              'remember',
              'trust'
            ])) {
              continue;
            }
            triggerClick(node);
            var retried = findTrustCheckbox();
            return retried ? !!retried.checked : true;
          }
          return false;
        }

        function hasTrustOptionHint() {
          if (findTrustCheckbox()) {
            return true;
          }

          var labels = Array.prototype.slice.call(
            document.querySelectorAll('label, span, div, a')
          );
          for (var i = 0; i < labels.length; i++) {
            var node = labels[i];
            if (!visible(node)) continue;
            if (containsKeyword(textOf(node), [
              '7\\u5929',
              '\\u4e03\\u5929',
              '7\\u65e5',
              '\\u4e03\\u65e5',
              '\\u8bb0\\u4f4f',
              '\\u514d\\u767b\\u5f55',
              'remember',
              'trust'
            ])) {
              return true;
            }
          }
          return false;
        }
    ''';
  }

  static String _partThree() {
    return '''
        function findSubmitButton() {
          var direct = pick([
            'a#login_submit[title="\\u767b\\u5f55"]',
            'a#login_submit.login-btn',
            '#login_submit',
            'button[type="submit"]',
            'input[type="submit"]',
            'button[id*="login"]',
            'a[id*="login"]',
            'button[class*="login"]',
            'input[id*="login"]',
            'input[class*="login"]',
            'a[class*="login"]'
          ], false);
          if (direct) {
            return direct;
          }

          var usernameNode = findUsernameNode();
          var passwordNode = findPasswordNode();
          var scopedRoot = passwordNode
              ? (passwordNode.form || passwordNode.closest('form') || passwordNode.parentElement)
              : (usernameNode ? (usernameNode.form || usernameNode.closest('form') || usernameNode.parentElement) : null);
          if (scopedRoot) {
            var scopedCandidates = Array.prototype.slice.call(
              scopedRoot.querySelectorAll('button[type="submit"], input[type="submit"], button, input[type="button"]')
            );
            for (var i = 0; i < scopedCandidates.length; i++) {
              var scopedNode = scopedCandidates[i];
              if (!visible(scopedNode)) continue;
              var scopedText = normalize(scopedNode.innerText || scopedNode.value || scopedNode.textContent);
              if (containsKeyword(scopedText, ['qr', 'scan', '\\u4e8c\\u7ef4\\u7801', '\\u626b\\u7801'])) {
                continue;
              }
              if (containsKeyword(scopedText, ['login', 'sign in', '\\u767b\\u5f55']) ||
                  normalize(scopedNode.type) === 'submit') {
                return scopedNode;
              }
            }
          }

          var buttons = Array.prototype.slice.call(
            document.querySelectorAll('button, input[type="button"], a')
          );
          for (var i = 0; i < buttons.length; i++) {
            var node = buttons[i];
            if (!visible(node)) continue;
            var text = normalize(node.innerText || node.value || node.textContent);
            if (containsKeyword(text, ['qr', 'scan', '\\u4e8c\\u7ef4\\u7801', '\\u626b\\u7801'])) {
              continue;
            }
            if (containsKeyword(text, ['login', 'sign in', '\\u767b\\u5f55'])) {
              return node;
            }
          }
          return null;
        }

        function isQrLoginView() {
          var qrImage = findQrImage();
          var usernameNode = findUsernameNode();
          return !!(qrImage && visible(qrImage) && !(usernameNode && visible(usernameNode)));
        }

        function isCredentialFormReady() {
          var usernameNode = findUsernameNode();
          var passwordNode = findPasswordNode();
          return !!(
            usernameNode &&
            passwordNode &&
            visible(usernameNode) &&
            visible(passwordNode)
          );
        }

        function hasVerificationStep() {
          var factorTitle = pick([
            'span.right-header-title'
          ], false);
          if (factorTitle && containsKeyword(textOf(factorTitle), ['\\u591a\\u56e0\\u5b50\\u8ba4\\u8bc1'])) {
            return true;
          }

          var exactMultiFactor = pick([
            'input#dynamicCode[name="dynamicCode"]',
            'input#dynamicCode',
            'button#getDynamicCode',
            'button#reAuthSubmitBtn'
          ], false);
          if (exactMultiFactor) {
            return true;
          }

          if (isCredentialFormReady()) {
            return false;
          }

          var usernameNode = findUsernameNode();
          var passwordNode = findPasswordNode();
          var inputs = Array.prototype.slice.call(
            document.querySelectorAll('input, textarea')
          );
          for (var i = 0; i < inputs.length; i++) {
            var node = inputs[i];
            if (!visible(node)) continue;
            if (node === usernameNode || node === passwordNode) continue;
            if (containsKeyword(textOf(node), [
              'captcha',
              'otp',
              'sms',
              'verify',
              'verification',
              '\\u9a8c\\u8bc1\\u7801',
              '\\u77ed\\u4fe1\\u9a8c\\u8bc1',
              '\\u6821\\u9a8c\\u7801',
              '\\u8bbe\\u5907\\u9a8c\\u8bc1',
              '\\u964c\\u751f\\u8bbe\\u5907'
            ])) {
              return true;
            }
          }

          var bodyText = normalize(document.body ? document.body.innerText : '');
          return containsKeyword(bodyText, [
            '\\u8bbe\\u5907\\u9a8c\\u8bc1',
            '\\u964c\\u751f\\u8bbe\\u5907',
            '\\u77ed\\u4fe1\\u9a8c\\u8bc1',
            '\\u77ed\\u4fe1\\u9a8c\\u8bc1\\u7801',
            '\\u8bf7\\u8f93\\u5165\\u9a8c\\u8bc1\\u7801',
            '\\u8bf7\\u8f93\\u5165\\u77ed\\u4fe1\\u9a8c\\u8bc1\\u7801',
            '\\u8bf7\\u8f93\\u5165\\u6821\\u9a8c\\u7801'
          ]);
        }

        function switchToPasswordLogin() {
          var trigger = findSwitchToPasswordTrigger();
          if (!trigger) return false;
          runtime.switchRequestedAt = now();
          return triggerClick(trigger);
        }

        function submitLogin() {
          var submitNode = findSubmitButton();
          if (submitNode) {
            return triggerClick(submitNode);
          }

          var passwordNode = findPasswordNode();
          var usernameNode = findUsernameNode();
          var form = passwordNode
              ? (passwordNode.form || passwordNode.closest('form'))
              : (usernameNode ? (usernameNode.form || usernameNode.closest('form')) : null);
          if (form) {
            if (typeof form.requestSubmit === 'function') {
              form.requestSubmit();
              return true;
            }
            if (typeof form.submit === 'function') {
              form.submit();
              return true;
            }
          }

          if (passwordNode) {
            try {
              passwordNode.dispatchEvent(
                new KeyboardEvent('keydown', {
                  key: 'Enter',
                  code: 'Enter',
                  bubbles: true,
                })
              );
              passwordNode.dispatchEvent(
                new KeyboardEvent('keyup', {
                  key: 'Enter',
                  code: 'Enter',
                  bubbles: true,
                })
              );
              return true;
            } catch (_) {}
          }
          return false;
        }
    ''';
  }

  static String _partFour({
    required String usernameLiteral,
    required String passwordLiteral,
    required String autoSubmitLiteral,
  }) {
    return '''
        function attempt(autoSubmit) {
          if (hasVerificationStep()) {
            post('AUTOFILL_STATUS:VERIFICATION_REQUIRED');
            postResult(false, false, false, true);
            return;
          }

          var usernameNode = findUsernameNode();
          var passwordNode = findPasswordNode();

          if (!passwordNode && isQrLoginView()) {
            if (isRecent(runtime.switchRequestedAt, 2200)) {
              post('AUTOFILL_STATUS:WAITING_PASSWORD_FORM');
              return;
            }
            if (switchToPasswordLogin()) {
              post('AUTOFILL_STATUS:SWITCHING_TO_PASSWORD_LOGIN');
            } else {
              post('AUTOFILL_STATUS:QR_VIEW');
            }
            return;
          }

          if (!isCredentialFormReady()) {
            if (isRecent(runtime.switchRequestedAt, 2200)) {
              post('AUTOFILL_STATUS:WAITING_PASSWORD_FORM');
            } else {
              post('AUTOFILL_STATUS:WAITING_FORM');
            }
            return;
          }

          runtime.switchRequestedAt = 0;
          post('AUTOFILL_STATUS:FORM_READY');

          var usernameOk = applyValue(usernameNode, $usernameLiteral);
          var passwordOk = applyValue(passwordNode, $passwordLiteral);
          var trustEnabled = enableTrustOption();
          var trustExpected = hasTrustOptionHint();

          if (usernameOk || passwordOk) {
            postResult(usernameOk, passwordOk, false, false);
          }
          if (trustEnabled) {
            post('AUTOFILL_STATUS:TRUST_CHECKED');
          }
          if (usernameOk && passwordOk) {
            post('AUTOFILL_STATUS:CREDENTIALS_FILLED');
          } else if (usernameOk || passwordOk) {
            post('AUTOFILL_STATUS:PARTIAL_CREDENTIALS');
          }
          if (trustExpected && !trustEnabled) {
            post('AUTOFILL_STATUS:WAITING_TRUST_OPTION');
            return;
          }

          if (!autoSubmit || !usernameOk || !passwordOk) {
            return;
          }
          if (hasVerificationStep()) {
            post('AUTOFILL_STATUS:VERIFICATION_REQUIRED');
            postResult(false, false, false, true);
            return;
          }
          if (isRecent(runtime.submittedAt, 4000)) {
            post('AUTOFILL_STATUS:SUBMITTING');
            return;
          }

          var submitted = submitLogin();
          if (submitted) {
            runtime.submittedAt = now();
            post('AUTOFILL_STATUS:SUBMITTED');
            postResult(usernameOk, passwordOk, true, false);
          }
        }

        attempt($autoSubmitLiteral);
      })();
    ''';
  }
}
