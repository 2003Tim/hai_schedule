import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class SecureStorageMock {
  SecureStorageMock._();

  static const MethodChannel channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  static final Map<String, String> _store = <String, String>{};

  static void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handleMethodCall);
  }

  static void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    _store.clear();
  }

  static void clear() {
    _store.clear();
  }

  static String? read(String key) {
    return _store[key];
  }

  static Future<Object?> _handleMethodCall(MethodCall call) async {
    final arguments =
        call.arguments is Map
            ? Map<String, dynamic>.from(call.arguments as Map)
            : const <String, dynamic>{};
    final key = arguments['key']?.toString() ?? '';

    switch (call.method) {
      case 'write':
        final value = arguments['value'];
        if (value == null) {
          _store.remove(key);
        } else {
          _store[key] = value.toString();
        }
        return null;
      case 'read':
        return _store[key];
      case 'delete':
        _store.remove(key);
        return null;
      case 'deleteAll':
        _store.clear();
        return null;
      case 'readAll':
        return Map<String, String>.from(_store);
      case 'containsKey':
        return _store.containsKey(key);
      default:
        return null;
    }
  }
}
