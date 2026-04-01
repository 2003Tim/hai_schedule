import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/app_logger.dart';

class SavedPortalCredential {
  final String username;
  final String password;

  const SavedPortalCredential({
    required this.username,
    required this.password,
  });

  String get maskedUsername {
    if (username.length <= 4) return username;
    return '${username.substring(0, 2)}***${username.substring(username.length - 2)}';
  }
}

class AuthCredentialsService {
  AuthCredentialsService._();

  static final AuthCredentialsService instance = AuthCredentialsService._();

  static const _storage = FlutterSecureStorage();
  static const _nativeChannel = MethodChannel('hai_schedule/native_credentials');
  static const _usernameKey = 'portal_username';
  static const _passwordKey = 'portal_password';

  Future<SavedPortalCredential?> load() async {
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('saveCredential', {
          'username': username,
          'password': password,
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
  }) async {
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('saveCredential', {
          'username': username,
          'password': password,
        });
      } catch (e) {
        AppLogger.warn('AuthCredentials', 'Native 凭据镜像写入失败（不影响功能）', e);
      }
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('clearCredential');
      } catch (e) {
        AppLogger.warn('AuthCredentials', 'Native 凭据镜像清除失败（不影响功能）', e);
      }
    }
  }
}
