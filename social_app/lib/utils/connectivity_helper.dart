import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  /// Kiểm tra có mạng không
  static Future<bool> hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (e) {
      debugPrint('Lỗi check connectivity: $e');
      return false;
    }
  }

  /// Lắng nghe thay đổi mạng (có thể dùng sau)
  static Stream<List<ConnectivityResult>> onConnectivityChanged() {
    return Connectivity().onConnectivityChanged;
  }
}