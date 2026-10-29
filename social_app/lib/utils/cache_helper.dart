import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static String get _keyPosts => 'cache_posts_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';
  static String get _keyVideos => 'cache_videos_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';
  static String get _keyProfile => 'cache_profile_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';
  static String get _keyLastSync => 'cache_last_sync_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';
  static String get _keyFriends => 'cache_friends_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';           // ← MỚI
  static String get _keyNotifications => 'cache_notifications_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}'; // ← MỚI

  // ============================================
  // LƯU CACHE
  // ============================================
  static Future<void> savePosts(List<Map<String, dynamic>> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = posts.take(30).toList();
      await prefs.setString(_keyPosts, jsonEncode(limited));
      await prefs.setInt(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ Đã cache ${limited.length} bài viết');
    } catch (e) {
      debugPrint('❌ Lỗi lưu cache posts: $e');
    }
  }

  static Future<void> saveVideos(List<Map<String, dynamic>> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = videos.take(20).toList();
      await prefs.setString(_keyVideos, jsonEncode(limited));
      debugPrint('✅ Đã cache ${limited.length} video');
    } catch (e) {
      debugPrint('❌ Lỗi lưu cache videos: $e');
    }
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfile, jsonEncode(profile));
      debugPrint('✅ Đã cache profile');
    } catch (e) {
      debugPrint('❌ Lỗi lưu cache profile: $e');
    }
  }

  // ← MỚI
  static Future<void> saveFriends(List<Map<String, dynamic>> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = friends.take(50).toList();
      await prefs.setString(_keyFriends, jsonEncode(limited));
      debugPrint('✅ Đã cache ${limited.length} bạn bè');
    } catch (e) {
      debugPrint('❌ Lỗi lưu cache friends: $e');
    }
  }

  // ← MỚI
  static Future<void> saveNotifications(
      List<Map<String, dynamic>> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = notifications.take(50).toList();
      await prefs.setString(_keyNotifications, jsonEncode(limited));
      debugPrint('✅ Đã cache ${limited.length} thông báo');
    } catch (e) {
      debugPrint('❌ Lỗi lưu cache notifications: $e');
    }
  }

  // ============================================
  // ĐỌC CACHE
  // ============================================
  static Future<List<Map<String, dynamic>>> getPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyPosts);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map<Map<String, dynamic>>((i) => Map<String, dynamic>.from(i))
          .toList();
    } catch (e) {
      debugPrint('❌ Lỗi đọc cache posts: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyVideos);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map<Map<String, dynamic>>((i) => Map<String, dynamic>.from(i))
          .toList();
    } catch (e) {
      debugPrint('❌ Lỗi đọc cache videos: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyProfile);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('❌ Lỗi đọc cache profile: $e');
      return null;
    }
  }

  // ← MỚI
  static Future<List<Map<String, dynamic>>> getFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyFriends);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map<Map<String, dynamic>>((i) => Map<String, dynamic>.from(i))
          .toList();
    } catch (e) {
      debugPrint('❌ Lỗi đọc cache friends: $e');
      return [];
    }
  }

  // ← MỚI
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyNotifications);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .map<Map<String, dynamic>>((i) => Map<String, dynamic>.from(i))
          .toList();
    } catch (e) {
      debugPrint('❌ Lỗi đọc cache notifications: $e');
      return [];
    }
  }

  static Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastSync);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ============================================
  // XÓA CACHE KHI LOGOUT
  // ============================================
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPosts);
      await prefs.remove(_keyVideos);
      await prefs.remove(_keyProfile);
      await prefs.remove(_keyLastSync);
      await prefs.remove(_keyFriends);          // ← MỚI
      await prefs.remove(_keyNotifications);    // ← MỚI
      debugPrint('✅ Đã xóa toàn bộ cache');
    } catch (e) {
      debugPrint('❌ Lỗi xóa cache: $e');
    }
  }
}