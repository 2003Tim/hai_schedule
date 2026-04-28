/// 描述对自动同步状态记录的局部更新意图。
///
/// 字段为 null 表示"不修改"，clearXxx 为 true 表示"显式清除"。
/// 这样上层可以用 `AutoSyncStatusPatch(state: 'success', clearError: true)`
/// 这种带语义的写法替代之前 14 个并列可选参数 + 多个 clearXxx 布尔的调用样式。
class AutoSyncStatusPatch {
  const AutoSyncStatusPatch({
    this.state,
    this.message,
    this.source,
    this.diffSummary,
    this.error,
    this.cookieSnapshot,
    this.semesterCode,
    this.lastFetchTime,
    this.lastAttemptTime,
    this.nextSyncTime,
    this.clearError = false,
    this.clearDiffSummary = false,
    this.clearNextSyncTime = false,
  });

  final String? state;
  final String? message;
  final String? source;
  final String? diffSummary;
  final String? error;
  final String? cookieSnapshot;
  final String? semesterCode;
  final DateTime? lastFetchTime;
  final DateTime? lastAttemptTime;
  final DateTime? nextSyncTime;
  final bool clearError;
  final bool clearDiffSummary;
  final bool clearNextSyncTime;

  /// 是否包含任意需要持久化的修改。
  bool get hasAnyChange =>
      state != null ||
      message != null ||
      source != null ||
      diffSummary != null ||
      error != null ||
      cookieSnapshot != null ||
      semesterCode != null ||
      lastFetchTime != null ||
      lastAttemptTime != null ||
      nextSyncTime != null ||
      clearError ||
      clearDiffSummary ||
      clearNextSyncTime;
}
