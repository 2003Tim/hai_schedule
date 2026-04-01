import 'package:flutter/foundation.dart';

/// 统一日志工具。
///
/// 封装 [debugPrint]，在 debug 构建中输出带前缀的日志，
/// release 构建中自动被编译器优化掉（debugPrint 本身在 release 下是 no-op）。
class AppLogger {
  AppLogger._();

  /// 记录调试级别信息。
  static void debug(String tag, String message) {
    debugPrint('[$tag] $message');
  }

  /// 记录警告——通常用于可容忍的非致命错误（如最佳努力操作失败）。
  static void warn(String tag, String message, [Object? error]) {
    if (error != null) {
      debugPrint('[$tag] WARN $message: $error');
    } else {
      debugPrint('[$tag] WARN $message');
    }
  }

  /// 记录错误——携带异常对象和堆栈。
  static void error(String tag, String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$tag] ERROR $message: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
