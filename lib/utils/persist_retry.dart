import 'dart:async';

/// 一个通用的"写入后回读校验"重试小工具。
///
/// 解决 Android 上 [SharedPreferences] 写入后立刻读取偶发为旧值的问题：
///   * [write] 完成一次写入；
///   * [verify] 在 reload 后判断写入是否真正生效；
///   * 若不一致，按 [delay] 等待后重试，最多 [maxAttempts] 次；
///   * 全部失败抛出 [StateError]，错误信息使用 [description] 描述。
///
/// 示例：
/// ```dart
/// await PersistRetry.run(
///   description: '学期目录',
///   maxAttempts: 4,
///   delay: const Duration(milliseconds: 200),
///   write: () => prefs.setStringList(key, encoded),
///   verify: () async {
///     await prefs.reload();
///     return _sameStringList(prefs.getStringList(key), encoded);
///   },
/// );
/// ```
class PersistRetry {
  PersistRetry._();

  static Future<void> run({
    required String description,
    required Future<bool> Function() write,
    required Future<bool> Function() verify,
    int maxAttempts = 4,
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    assert(maxAttempts >= 1);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final didWrite = await write();
      if (!didWrite) {
        throw StateError('$description 保存失败');
      }
      if (await verify()) {
        return;
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    throw StateError('$description 落盘失败');
  }
}
