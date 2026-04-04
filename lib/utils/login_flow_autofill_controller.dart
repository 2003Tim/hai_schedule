import 'dart:async';

import 'package:hai_schedule/models/login_fetch_coordinator_models.dart';

class LoginFlowAutofillController {
  static const int maxAttempts = 7;

  Timer? _timer;
  int _attemptCount = 0;
  bool _pendingAutofill = false;
  bool _loopActive = false;

  int get attemptCount => _attemptCount;
  bool get pendingAutofill => _pendingAutofill;
  bool get loopActive => _loopActive;

  bool get shouldAutoSubmit => _attemptCount >= 3;
  bool get hasRemainingRetries =>
      _pendingAutofill && _attemptCount < maxAttempts;

  void dispose() {
    _timer?.cancel();
  }

  void setPending(bool pending) {
    _pendingAutofill = pending;
  }

  void start(void Function() runAttempt) {
    if (_loopActive) return;
    _timer?.cancel();
    _attemptCount = 0;
    _pendingAutofill = true;
    _loopActive = true;
    runAttempt();
  }

  void stop({bool clearPending = false}) {
    _timer?.cancel();
    _loopActive = false;
    if (clearPending) {
      _pendingAutofill = false;
    }
  }

  int beginAttempt() {
    _attemptCount++;
    return _attemptCount;
  }

  void handleResolution(LoginAutofillStateResolution resolution) {
    if (resolution.stopAutofillLoop) {
      _timer?.cancel();
      _loopActive = false;
    }
    if (resolution.clearPendingAutofill) {
      _pendingAutofill = false;
    }
  }

  Duration nextRetryDelay() {
    return Duration(
      milliseconds:
          _attemptCount == 1
              ? 1100
              : _attemptCount < 4
              ? 1500
              : 1800,
    );
  }

  void scheduleNext(void Function() runAttempt) {
    _timer?.cancel();
    _timer = Timer(nextRetryDelay(), runAttempt);
  }

  bool exhaustPending() {
    _timer?.cancel();
    _loopActive = false;
    final hadPending = _pendingAutofill;
    _pendingAutofill = false;
    return hadPending;
  }
}
