import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/utils/app_platform.dart';
import 'package:hai_schedule/utils/app_storage_schema.dart';

/// 海大门户 Cookie 三层备份链。
///
/// 不同设备 / 不同 ROM / 不同 secure-storage 版本的可靠性差异较大，应用历史
/// 上踩过 secure storage 在某些机型上回读返回 null 的坑，所以保留三个并行
/// 持久化层并逐层回填：
///   1. 优先：Android Keystore（通过原生通道）；
///   2. 其次：[FlutterSecureStorage]；
///   3. 最后：[SharedPreferences]（旧版本明文存储，仅用于迁移）。
///
/// [load] 每次读取时会把数据"上提"到优先层，让后续读取更快、更稳。
/// [persist] 写入会同步落到 native + secure 两层，并清掉 prefs 旧值。
class CookieSnapshotStore {
  CookieSnapshotStore({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? prefsLoader,
    bool Function()? isAndroid,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _prefsLoader = prefsLoader ?? SharedPreferences.getInstance,
       _isAndroidResolver = isAndroid ?? (() => AppPlatform.instance.isAndroid);

  static const _nativeChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );

  /// 与 [AppStorageSchema] 共享 key，保证 SharedPreferences / SecureStorage
  /// 三层之间能互相迁移读取，不会出现"写入 A 读取 B"的不一致。
  static const String cookieSnapshotKey = AppStorageSchema.cookieSnapshotKey;
  static const String invalidatedKey =
      AppStorageSchema.cookieSnapshotInvalidatedKey;

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _prefsLoader;
  final bool Function() _isAndroidResolver;

  bool get _isAndroid => _isAndroidResolver();

  /// 读取 Cookie，按优先级回填到上一层。失效标记若为 true 则一次性清空所有
  /// 副本并返回 null。
  Future<String?> load({
    ScheduleSource source = ScheduleSource.graduate,
  }) async {
    final prefs = await _prefsLoader();
    final cookieKey = _keyForSource(cookieSnapshotKey, source);
    final invalidatedKeyForSource = _keyForSource(invalidatedKey, source);
    final invalidated = prefs.getBool(invalidatedKeyForSource) ?? false;
    if (invalidated) {
      await _clearNative(source: source);
      await _secureStorage.delete(key: cookieKey);
      await prefs.remove(cookieKey);
      await prefs.remove(invalidatedKeyForSource);
      return null;
    }

    final native = await _readFromNative(source: source);
    if (native != null && native.isNotEmpty) {
      await _secureStorage.write(key: cookieKey, value: native);
      await prefs.remove(cookieKey);
      await prefs.remove(invalidatedKeyForSource);
      return native;
    }

    final secure = await _secureStorage.read(key: cookieKey);
    if (secure != null && secure.isNotEmpty) {
      await _writeToNative(secure, source: source);
      await prefs.remove(cookieKey);
      await prefs.remove(invalidatedKeyForSource);
      return secure;
    }

    final legacy = prefs.getString(cookieKey);
    if (legacy != null && legacy.isNotEmpty) {
      await persist(legacy, source: source);
      await prefs.remove(cookieKey);
      await prefs.remove(invalidatedKeyForSource);
      return legacy;
    }
    return null;
  }

  /// 写入 Cookie，同步落到 native + secure 两层。
  /// 同时清掉 SharedPreferences 中的旧值与失效标记。
  Future<void> persist(
    String cookie, {
    ScheduleSource source = ScheduleSource.graduate,
  }) async {
    final cookieKey = _keyForSource(cookieSnapshotKey, source);
    await _writeToNative(cookie, source: source);
    await _secureStorage.write(key: cookieKey, value: cookie);
    final prefs = await _prefsLoader();
    await prefs.remove(_keyForSource(invalidatedKey, source));
  }

  /// 清空所有 Cookie 副本。
  Future<void> clear({
    bool strict = false,
    ScheduleSource source = ScheduleSource.graduate,
  }) async {
    final cookieKey = _keyForSource(cookieSnapshotKey, source);
    final invalidatedKeyForSource = _keyForSource(invalidatedKey, source);
    // #C11: in strict mode _clearNative may rethrow on PlatformException.
    // We must still wipe the Dart-side layers (secure storage, prefs
    // invalidate key) so that a subsequent load() does not return the
    // stale cookie. Use try/finally for the native call, then let the
    // Dart-side cleanup run unconditionally. The native error is
    // re-raised at the end for callers that want to log it.
    Object? nativeError;
    StackTrace? nativeStack;
    try {
      await _clearNative(strict: strict, source: source);
    } catch (e, st) {
      nativeError = e;
      nativeStack = st;
    }
    try {
      await _secureStorage.delete(key: cookieKey);
      final prefs = await _prefsLoader();
      await prefs.remove(cookieKey);
      await prefs.remove(invalidatedKeyForSource);
    } catch (_) {
      // Best-effort: if Dart-side cleanup itself fails, the native
      // error (if any) is still the more important signal.
    }
    if (nativeError != null) {
      // ignore: only_throw_errors
      Error.throwWithStackTrace(nativeError, nativeStack ?? StackTrace.current);
    }
  }

  static String _keyForSource(String key, ScheduleSource source) =>
      source.isGraduate ? key : '${source.value}.$key';

  Future<bool> _writeToNative(
    String cookie, {
    required ScheduleSource source,
  }) async {
    if (!_isAndroid) return false;
    try {
      await _nativeChannel.invokeMethod<void>('saveCookieSnapshot', {
        'cookie': cookie,
        'source': source.value,
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> _readFromNative({required ScheduleSource source}) async {
    if (!_isAndroid) return null;
    try {
      final value = await _nativeChannel.invokeMethod<String>(
        'loadCookieSnapshot',
        {'source': source.value},
      );
      if (value == null || value.isEmpty) return null;
      return value;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _clearNative({
    bool strict = false,
    required ScheduleSource source,
  }) async {
    if (!_isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<void>('clearCookieSnapshot', {
        'source': source.value,
      });
    } on MissingPluginException {
      if (strict) rethrow;
    } on PlatformException {
      if (strict) rethrow;
    }
  }
}
