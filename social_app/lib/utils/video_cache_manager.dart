import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VideoCacheManager {
  // ⭐ TĂNG: 20 file video (thay vì 5)
  static const int _maxCacheCount = 20;
  
  static const String _cacheDirName = 'video_cache';
  
  // ⭐ TĂNG: 500 MB (thay vì 100 MB)
  static const int _maxCacheSizeMB = 500;

  // ============================================
  // LẤY THƯ MỤC CACHE
  // ============================================
  static Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // ============================================
  // CHUYỂN URL → TÊN FILE (md5 hash)
  // ============================================
  static String _urlToFileName(String url) {
    final bytes = utf8.encode(url);
    final hash = md5.convert(bytes).toString();
    return '$hash.mp4';
  }

  // ============================================
  // LẤY FILE ĐÃ CACHE (nếu có)
  // ============================================
  static Future<File?> getCachedFile(String url) async {
    try {
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${_urlToFileName(url)}');
      if (await file.exists() && await file.length() > 0) {
        try {
          await file.setLastAccessed(DateTime.now());
        } catch (_) {}
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Lỗi get cache file: $e');
      return null;
    }
  }

  // ⭐ KIỂM TRA FILE CÓ SẴN KHÔNG (không touch last accessed)
  static Future<bool> hasCachedFile(String url) async {
    try {
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${_urlToFileName(url)}');
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  // ============================================
  // DOWNLOAD + LƯU VÀO CACHE
  // ============================================
  static Future<File?> downloadAndCache(
    String url, {
    Function(double)? onProgress,
  }) async {
    try {
      final cacheDir = await _getCacheDir();
      final targetFile = File('${cacheDir.path}/${_urlToFileName(url)}');

      if (await targetFile.exists() && await targetFile.length() > 0) {
        return targetFile;
      }

      debugPrint('⬇️ Đang tải video: ${url.substring(0, 50)}...');
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        debugPrint('❌ Download thất bại: ${response.statusCode}');
        client.close();
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final sink = targetFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (onProgress != null && contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }
      await sink.close();
      client.close();

      if (await targetFile.length() == 0) {
        await targetFile.delete();
        return null;
      }

      final sizeMB =
          (await targetFile.length() / 1024 / 1024).toStringAsFixed(2);
      debugPrint('✅ Đã cache video: $sizeMB MB');

      await _cleanup();
      return targetFile;
    } catch (e) {
      debugPrint('❌ Lỗi download video: $e');
      return null;
    }
  }

  // ============================================
  // DỌN DẸP FILE CŨ (LRU)
  // ============================================
  static Future<void> _cleanup() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = <File>[];
      await for (final f in cacheDir.list()) {
        if (f is File && f.path.endsWith('.mp4')) {
          files.add(f);
        }
      }

      final withStats = await Future.wait(
        files.map((f) async {
          final stat = await f.stat();
          return MapEntry(f, stat.accessed);
        }),
      );
      withStats.sort((a, b) => a.value.compareTo(b.value));

      // Xóa nếu quá nhiều file
      if (withStats.length > _maxCacheCount) {
        final toDelete = withStats.take(withStats.length - _maxCacheCount);
        for (final entry in toDelete) {
          try {
            await entry.key.delete();
            debugPrint('🗑️ Xóa cache cũ: ${entry.key.path.split('/').last}');
          } catch (e) {
            debugPrint('Lỗi xóa: $e');
          }
        }
      }

      // Xóa nếu tổng size > 500 MB
      int totalSize = 0;
      for (final entry in withStats) {
        totalSize += await entry.key.length();
      }
      if (totalSize > _maxCacheSizeMB * 1024 * 1024) {
        for (final entry in withStats) {
          if (totalSize <= _maxCacheSizeMB * 1024 * 1024) break;
          try {
            final size = await entry.key.length();
            await entry.key.delete();
            totalSize -= size;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi cleanup: $e');
    }
  }

  // ============================================
  // XÓA TOÀN BỘ
  // ============================================
  static Future<void> clearAll() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('✅ Đã xóa toàn bộ video cache');
      }
    } catch (e) {
      debugPrint('❌ Lỗi xóa cache video: $e');
    }
  }

  // ============================================
  // ĐO DUNG LƯỢNG CACHE
  // ============================================
  static Future<String> getCacheSizeFormatted() async {
    try {
      final cacheDir = await _getCacheDir();
      if (!await cacheDir.exists()) return '0 MB';
      int total = 0;
      await for (final f in cacheDir.list()) {
        if (f is File) total += await f.length();
      }
      return '${(total / 1024 / 1024).toStringAsFixed(1)} MB';
    } catch (e) {
      return '0 MB';
    }
  }
}