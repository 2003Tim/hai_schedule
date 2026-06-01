import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/utils/app_logger.dart';
import 'package:hai_schedule/utils/app_platform.dart';

class SavedPortalCredential {
  final String username;
  final String password;

  const SavedPortalCredential({required this.username, required this.password});

  String get maskedUsername {
    if (username.length <= 4) return username;
    return '${username.substring(0, 2)}***${username.substring(username.length - 2)}';
  }
}

class AuthCredentialsService {
  AuthCredentialsService._();

  static final AuthCredentialsService instance = AuthCredentialsService._();
  @visibleForTesting
  static bool? debugForceAndroid;

  static const _storage = FlutterSecureStorage();
  static const _nativeChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );
  static const _usernameKey = 'portal_username';
  static const _passwordKey = 'portal_password';

  static bool get _isAndroid =>
      debugForceAndroid ?? AppPlatform.instance.isAndroid;

  static String _keyForSource(String key, ScheduleSource source) =>
      source.isGraduate ? key : '${source.value}.$key';

  Future<SavedPortalCredential?> load({
    ScheduleSource source = ScheduleSource.graduate,
  }) async {
    final usernameKey = _keyForSource(_usernameKey, source);
    final passwordKey = _keyForSource(_passwordKey, source);
    final username = await _storage.read(key: usernameKey);
    final password = await _storage.read(key: passwordKey);
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      final native = await _loadFromNative(source: source);
      if (native == null) {
        return null;
      }
      await _storage.write(key: usernameKey, value: native.username);
      await _storage.write(key: passwordKey, value: native.password);
      return native;
    }
    if (_isAndroid) {
      try {
        await _nativeChannel.invokeMethod('saveCredential', {
          'username': username,
          'password': password,
          'source': source.value,
        });
      } catch (e) {
        AppLogger.warn('AuthCredentials', 'Native 凭据镜像同步失败（不影响功能）', e);
      }
    }
    return SavedPortalCredential(username: username, password: password);
  }

  Future<void> save({
    required String username,
    required String password,
    ScheduleSource source = ScheduleSource.graduate,
  }) async {
    await _storage.write(
      key: _keyForSource(_usernameKey, source),
      value: username,
    );
    await _storage.write(
      key: _keyForSource(_passwordKey, source),
      value: password,
    );
    if (_isAndroid) {
      try {
        await _nativeChannel.invokeMethod('saveCredential', {
          'username': username,
          'password': password,
          'source': source.value,
        });
      } catch (e) {
        AppLogger.warn('AuthCredentials', 'Native 凭据镜像写入失败（不影响功能）', e);
      }
    }
    await AppStorage.instance.clearSyncInvalidationFlag();
  }

  Future<void> clear({
    bool strict = false,
    ScheduleSource source = ScheduleSource.graduate,
  }) async {
    if (_isAndroid) {
      if (strict) {
        await _nativeChannel.invokeMethod<void>('clearCredential', {
          'source': source.value,
        });
      } else {
        try {
          await _nativeChannel.invokeMethod('clearCredential', {
            'source': source.value,
          });
        } catch (e) {
          AppLogger.warn('AuthCredentials', 'Native 凭据镜像清除失败（不影响功能）', e);
        }
      }
    }
    await _storage.delete(key: _keyForSource(_usernameKey, source));
    await _storage.delete(key: _keyForSource(_passwordKey, source));
  }

  Future<SavedPortalCredential?> _loadFromNative({
    required ScheduleSource source,
  }) async {
    if (!_isAndroid) return null;
    try {
      final raw = await _nativeChannel.invokeMapMethod<String, dynamic>(
        'loadCredential',
        {'source': source.value},
      );
      final username = raw?['username']?.toString() ?? '';
      final password = raw?['password']?.toString() ?? '';
      if (username.isEmpty || password.isEmpty) {
        return null;
      }
      return SavedPortalCredential(username: username, password: password);
    } catch (e) {
      AppLogger.warn('AuthCredentials', 'Native 凭据回读失败（不影响功能）', e);
      return null;
    }
  }
}
