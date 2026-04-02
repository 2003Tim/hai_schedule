import 'package:flutter/foundation.dart';

import '../models/login_fetch_models.dart';

class LoginFetchBridgeHandler {
  static const _autofillStatusPrefix = 'AUTOFILL_STATUS:';
  static const _autofillResultPrefix = 'AUTOFILL_RESULT:';
  static const _semesterPrefix = 'SEMESTER:';
  static const _semesterSwitchedPrefix = 'SEMESTER_SWITCHED:';
  static const _semesterSwitchErrorPrefix = 'SEMESTER_SWITCH_ERR:';
  static const _chunkStartPrefix = 'CHUNK_START:';
  static const _chunkDataPrefix = 'CHUNK_DATA:';
  static const _scheduleErrorPrefix = 'SCHEDULE_ERR:';

  static void handle({
    required String message,
    required LoginFetchChunkState chunkState,
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onSemesterDetected,
    required ValueChanged<String> onSemesterSwitched,
    required ValueChanged<String> onPayloadReady,
    required ValueChanged<String> onError,
    ValueChanged<String>? onAutofillStatus,
    ValueChanged<LoginAutofillResult>? onAutofillResult,
  }) {
    if (message.startsWith(_autofillStatusPrefix)) {
      onAutofillStatus?.call(
        message.substring(_autofillStatusPrefix.length).trim(),
      );
      return;
    }

    if (message.startsWith(_autofillResultPrefix)) {
      final result = _parseAutofillResult(
        message.substring(_autofillResultPrefix.length),
      );
      if (result != null) {
        onAutofillResult?.call(result);
      }
      return;
    }

    if (message.startsWith(_semesterPrefix)) {
      onSemesterDetected(message.substring(_semesterPrefix.length).trim());
      return;
    }

    if (message.startsWith(_semesterSwitchedPrefix)) {
      onSemesterSwitched(
        message.substring(_semesterSwitchedPrefix.length).trim(),
      );
      return;
    }

    if (message.startsWith(_semesterSwitchErrorPrefix)) {
      onError(
        '\u5207\u6362\u5b66\u671f\u5931\u8d25: '
        '${message.substring(_semesterSwitchErrorPrefix.length).trim()}',
      );
      return;
    }

    if (message.startsWith(_chunkStartPrefix)) {
      final parts = message.substring(_chunkStartPrefix.length).split(':');
      final totalChunks = parts.isNotEmpty ? int.tryParse(parts.first) ?? 0 : 0;
      chunkState.begin(totalChunks);
      onStatus('\u63a5\u6536\u6570\u636e 0/${chunkState.expectedChunks} ...');
      return;
    }

    if (message.startsWith(_chunkDataPrefix)) {
      final firstColon = message.indexOf(':', _chunkDataPrefix.length);
      if (firstColon < 0) return;

      chunkState.appendChunk(message.substring(firstColon + 1));
      if (chunkState.receivedChunks % 3 == 0 ||
          chunkState.receivedChunks == chunkState.expectedChunks) {
        onStatus(
          '\u63a5\u6536\u6570\u636e '
          '${chunkState.receivedChunks}/${chunkState.expectedChunks} ...',
        );
      }
      return;
    }

    if (message == 'CHUNK_END') {
      onPayloadReady(chunkState.takePayload());
      return;
    }

    if (message.startsWith(_scheduleErrorPrefix)) {
      onError(message.substring(_scheduleErrorPrefix.length));
    }
  }

  static LoginAutofillResult? _parseAutofillResult(String payload) {
    final parts = payload.split(':');
    if (parts.length < 4) return null;
    return LoginAutofillResult(
      usernameFilled: parts[0] == '1',
      passwordFilled: parts[1] == '1',
      submitted: parts[2] == '1',
      verificationRequired: parts[3] == '1',
    );
  }
}
