import 'package:flutter/foundation.dart';

import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/catalog_parsing_exception.dart';
import 'package:hai_schedule/services/semester_catalog_parser.dart';

class LoginFetchBridgeHandler {
  static const _loginErrorPrefix = 'LOGIN_ERROR:';
  static const _autofillStatusPrefix = 'AUTOFILL_STATUS:';
  static const _autofillResultPrefix = 'AUTOFILL_RESULT:';
  static const _semesterPrefix = 'SEMESTER:';
  static const _semesterOptionsPrefix = 'SEMESTER_OPTIONS:';
  static const _semesterSwitchedPrefix = 'SEMESTER_SWITCHED:';
  static const _semesterSwitchErrorPrefix = 'SEMESTER_SWITCH_ERR:';
  static const _chunkStartPrefix = 'CHUNK_START:';
  static const _chunkDataPrefix = 'CHUNK_DATA:';
  static const _chunkEndPrefix = 'CHUNK_END:';
  static const _scheduleErrorPrefix = 'SCHEDULE_ERR:';

  /// 允许的消息前缀集合，用于快速过滤非预期消息
  static const _knownPrefixes = [
    _loginErrorPrefix,
    _autofillStatusPrefix,
    _autofillResultPrefix,
    _semesterPrefix,
    _semesterOptionsPrefix,
    _semesterSwitchedPrefix,
    _semesterSwitchErrorPrefix,
    _chunkStartPrefix,
    _chunkDataPrefix,
    _chunkEndPrefix,
    _scheduleErrorPrefix,
  ];

  /// 单条消息最大长度（4 MB），防止异常大数据注入
  static const _maxMessageLength = 4 * 1024 * 1024;

  static void handle({
    required String message,
    required LoginFetchChunkState chunkState,
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onSemesterDetected,
    required ValueChanged<List<SemesterOption>> onSemesterOptions,
    required ValueChanged<String> onSemesterSwitched,
    required ValueChanged<String> onPayloadReady,
    required ValueChanged<String> onError,
    ValueChanged<String>? onLoginError,
    ValueChanged<String>? onAutofillStatus,
    ValueChanged<LoginAutofillResult>? onAutofillResult,
  }) {
    // 丢弃超长消息，防止异常大数据注入
    if (message.length > _maxMessageLength) return;
    // 丢弃不匹配任何已知前缀的消息，过滤页面其他脚本产生的噪声
    if (!_knownPrefixes.any(message.startsWith)) return;

    if (message.startsWith(_loginErrorPrefix)) {
      onLoginError?.call(message.substring(_loginErrorPrefix.length).trim());
      return;
    }

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

    final semester = _parseRequestMessage(message, _semesterPrefix);
    if (semester != null) {
      if (!_matchesActiveRequest(chunkState, semester.$1)) return;
      onSemesterDetected(semester.$2.trim());
      return;
    }

    final semesterOptions = _parseRequestMessage(
      message,
      _semesterOptionsPrefix,
    );
    if (semesterOptions != null) {
      if (!_matchesActiveRequest(chunkState, semesterOptions.$1)) return;
      try {
        onSemesterOptions(
          SemesterCatalogParser.parseBridgePayload(semesterOptions.$2),
        );
      } on CatalogParsingException catch (e) {
        onError(e.message);
      } on FormatException {
        onError('学期目录格式无效，请重试');
      }
      return;
    }

    final switched = _parseRequestMessage(message, _semesterSwitchedPrefix);
    if (switched != null) {
      if (!_matchesActiveRequest(chunkState, switched.$1)) return;
      onSemesterSwitched(switched.$2.trim());
      return;
    }

    final switchError = _parseRequestMessage(
      message,
      _semesterSwitchErrorPrefix,
    );
    if (switchError != null) {
      if (!_matchesActiveRequest(chunkState, switchError.$1)) return;
      onError('切换学期失败: ${switchError.$2.trim()}');
      return;
    }

    if (message.startsWith(_chunkStartPrefix)) {
      final payload = message.substring(_chunkStartPrefix.length);
      final parts = payload.split(':');
      if (parts.length < 3) return;
      final requestId = parts[0];
      if (!_matchesActiveRequest(chunkState, requestId)) return;
      final totalChunks = int.tryParse(parts[1]) ?? 0;
      if (totalChunks <= 0) {
        onError('课表数据分片无效，请重试');
        return;
      }
      chunkState.begin(requestId: requestId, totalChunks: totalChunks);
      onStatus('接收数据 0/${chunkState.expectedChunks} ...');
      return;
    }

    if (message.startsWith(_chunkDataPrefix)) {
      final payload = message.substring(_chunkDataPrefix.length);
      final firstColon = payload.indexOf(':');
      final secondColon = payload.indexOf(':', firstColon + 1);
      if (firstColon <= 0 || secondColon <= firstColon) return;

      final requestId = payload.substring(0, firstColon);
      if (!_matchesActiveRequest(chunkState, requestId)) return;

      final chunkIndex = int.tryParse(
        payload.substring(firstColon + 1, secondColon),
      );
      final chunk = payload.substring(secondColon + 1);
      if (chunkIndex == null ||
          !chunkState.appendChunk(index: chunkIndex, chunk: chunk)) {
        onError('课表数据分片索引异常，请重试');
        return;
      }
      if (chunkState.receivedChunks % 3 == 0 ||
          chunkState.receivedChunks == chunkState.expectedChunks) {
        onStatus(
          '接收数据 ${chunkState.receivedChunks}/${chunkState.expectedChunks} ...',
        );
      }
      return;
    }

    if (message.startsWith(_chunkEndPrefix)) {
      final requestId = message.substring(_chunkEndPrefix.length).trim();
      if (!_matchesActiveRequest(chunkState, requestId)) return;
      if (!chunkState.isComplete) {
        onError('课表数据分片不完整，请重试');
        return;
      }
      onPayloadReady(chunkState.takePayload());
      return;
    }

    final scheduleError = _parseRequestMessage(message, _scheduleErrorPrefix);
    if (scheduleError != null) {
      if (!_matchesActiveRequest(chunkState, scheduleError.$1)) return;
      onError(scheduleError.$2);
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

  static (String, String)? _parseRequestMessage(String message, String prefix) {
    if (!message.startsWith(prefix)) return null;
    final payload = message.substring(prefix.length);
    final separator = payload.indexOf(':');
    if (separator <= 0) return null;
    return (payload.substring(0, separator), payload.substring(separator + 1));
  }

  static bool _matchesActiveRequest(
    LoginFetchChunkState chunkState,
    String requestId,
  ) {
    final active = chunkState.activeRequestId;
    return active != null && active == requestId;
  }
}
