import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemeBackgroundStore {
  const ThemeBackgroundStore._();

  static Future<String> copyCustomBackground(String imagePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${appDir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final ext = normalizeImageExtension(imagePath);
    final destPath =
        '${bgDir.path}/custom_bg_${DateTime.now().microsecondsSinceEpoch}.$ext';

    await File(imagePath).copy(destPath);
    return destPath;
  }

  static Future<String> importCustomBackgroundBytes(
    List<int> bytes, {
    String? sourceName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${appDir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final ext = normalizeImageExtension(sourceName ?? 'custom_bg.jpg');
    final destPath =
        '${bgDir.path}/custom_bg_${DateTime.now().microsecondsSinceEpoch}.$ext';

    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  static String normalizeImageExtension(String imagePath) {
    final dotIndex = imagePath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == imagePath.length - 1) return 'jpg';

    final extension = imagePath
        .substring(dotIndex + 1)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (extension.isEmpty || extension.length > 8) return 'jpg';
    return extension;
  }

  static Future<void> cleanupBackground(String? imagePath) async {
    await _evictBackgroundImage(imagePath);
    await _deleteBackgroundFile(imagePath);
  }

  static Future<void> _evictBackgroundImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      await FileImage(File(imagePath)).evict();
    } catch (_) {
      // Best effort only. If eviction fails, the new unique file path still
      // forces Flutter to load the replacement image.
    }
  }

  static Future<void> _deleteBackgroundFile(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final file = File(imagePath);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {
      // Ignore cleanup failures to avoid blocking theme updates.
    }
  }
}
