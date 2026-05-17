import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
       _isAndroidResolver =
           isAndroid ?? (() => AppPlatform.instance.isAndroid);

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
  Future<String?> load() async {
    final prefs = await _prefsLoader();
    final invalidated = prefs.getBool(invalidatedKey) ?? false;
    if (invalidated) {
      await _clearNative();
      await _secureStorage.delete(key: cookieSnapshotKey);
      await prefs.remove(cookieSnapshotKey);
      await prefs.remove(invalidatedKey);
      return null;
    }

    final native = await _readFromNative();
    if (native != null && native.isNotEmpty) {
      await _secureStorage.write(key: cookieSnapshotKey, value: native);
      await prefs.remove(cookieSnapshotKey);
      await prefs.remove(invalidatedKey);
      return native;
    }

    final secure = await _secureStorage.read(key: cookieSnapshotKey);
    if (secure != null && secure.isNotEmpty) {
      await _writeToNative(secure);
      await prefs.remove(cookieSnapshotKey);
      await prefs.remove(invalidatedKey);
      return secure;
    }

    final legacy = prefs.getString(cookieSnapshotKey);
    if (legacy != null && legacy.isNotEmpty) {
      await persist(legacy);
      await prefs.remove(cookieSnapshotKey);
      await prefs.remove(invalidatedKey);
      return legacy;
    }
    return null;
  }

  /// 写入 Cookie，同步落到 native + secure 两层。
  /// 同时清掉 SharedPreferences 中的旧值与失效标记。
  Future<void> persist(String cookie) async {
    await _writeToNative(cookie);
    await _secureStorage.write(key: cookieSnapshotKey, value: cookie);
    final prefs = await _prefsLoader();
    await prefs.remove(invalidatedKey);
  }

  /// 清空所有 Cookie 副本。
  Future<void> clear({bool strict = false}) async {
    await _clearNative(strict: strict);
    await _secureStorage.delete(key: cookieSnapshotKey);
    final prefs = await _prefsLoader();
    await prefs.remove(cookieSnapshotKey);
    await prefs.remove(invalidatedKey);
  }

  Future<bool> _writeToNative(String cookie) async {
    if (!_isAndroid) return false;
    try {
      await _nativeChannel.invokeMethod<void>('saveCookieSnapshot', {
        'cookie': cookie,
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> _readFromNative() async {
    if (!_isAndroid) return null;
    try {
      final value = await _nativeChannel.invokeMethod<String>(
        'loadCookieSnapshot',
      );
      if (value == null || value.isEmpty) return null;
      return value;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _clearNative({bool strict = false}) async {
    if (!_isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<void>('clearCookieSnapshot');
    } on MissingPluginException {
      if (strict) rethrow;
    } on PlatformException {
      if (strict) rethrow;
    }
  }
}
