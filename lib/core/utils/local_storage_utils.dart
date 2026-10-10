import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized utility for local file path resolution, storage, and persistence.
/// Ensures local gallery avatars and banners survive APK upgrades, reinstalls,
/// and Android scoped storage sandbox path changes.
abstract final class LocalStorageUtils {
  static String? _cachedDocsPath;

  /// Retrieves and caches the application documents directory path.
  static Future<String> getDocsDirectoryPath() async {
    if (_cachedDocsPath != null && _cachedDocsPath!.isNotEmpty) {
      return _cachedDocsPath!;
    }
    if (kIsWeb) return '';
    try {
      final dir = await getApplicationDocumentsDirectory();
      _cachedDocsPath = dir.path;
      return dir.path;
    } catch (_) {
      return '';
    }
  }

  /// Extracts the base filename from an absolute or relative file path.
  /// E.g. `/data/user/0/com.seriolab.app/app_flutter/banner_123.jpg` -> `banner_123.jpg`
  static String extractFilename(String pathOrFilename) {
    final trimmed = pathOrFilename.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split('/').last.split(r'\').last;
  }

  /// Synchronously attempts to resolve a local image [File].
  /// 1. Tests raw path as-is if it exists.
  /// 2. If not, tests inside the cached documents directory using the relative filename.
  static File? resolveFile(String? pathOrFilename) {
    if (pathOrFilename == null || pathOrFilename.trim().isEmpty || kIsWeb) {
      return null;
    }

    final trimmed = pathOrFilename.trim();

    // Direct path check
    try {
      final directFile = File(trimmed);
      if (directFile.existsSync()) return directFile;
    } catch (_) {}

    // Relative lookup in documents directory
    final filename = extractFilename(trimmed);
    if (_cachedDocsPath != null && _cachedDocsPath!.isNotEmpty && filename.isNotEmpty) {
      try {
        final docsFile = File('$_cachedDocsPath/$filename');
        if (docsFile.existsSync()) return docsFile;
      } catch (_) {}
    }

    return File(trimmed);
  }

  /// Asynchronously resolves a local image [File], ensuring the documents
  /// directory path is looked up if not yet cached.
  static Future<File?> resolveFileAsync(String? pathOrFilename) async {
    if (pathOrFilename == null || pathOrFilename.trim().isEmpty || kIsWeb) {
      return null;
    }

    final trimmed = pathOrFilename.trim();

    // Check direct path
    try {
      final directFile = File(trimmed);
      if (directFile.existsSync()) return directFile;
    } catch (_) {}

    // Check in app documents directory
    final docsPath = await getDocsDirectoryPath();
    final filename = extractFilename(trimmed);
    if (docsPath.isNotEmpty && filename.isNotEmpty) {
      try {
        final candidate = File('$docsPath/$filename');
        if (candidate.existsSync()) return candidate;
      } catch (_) {}
    }

    return File(trimmed);
  }

  /// Copies an image file into the application documents directory using a
  /// clean relative filename, returning just the relative filename for database storage.
  static Future<String> copyToDocumentsDirectory(
    String sourcePath,
    String prefix,
  ) async {
    if (kIsWeb) return sourcePath;

    final docsPath = await getDocsDirectoryPath();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extIndex = sourcePath.lastIndexOf('.');
    final extension = (extIndex != -1 && extIndex < sourcePath.length - 1)
        ? sourcePath.substring(extIndex + 1)
        : 'jpg';
    final filename = '${prefix}_$timestamp.$extension';

    if (docsPath.isNotEmpty) {
      final targetFile = File('$docsPath/$filename');
      try {
        await File(sourcePath).copy(targetFile.path);
        return filename;
      } catch (_) {
        // Fallback to original path if copy fails
        return sourcePath;
      }
    }

    return sourcePath;
  }
}
