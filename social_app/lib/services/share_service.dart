import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
class ShareService {
  static Future<void> post(BuildContext context, Map<String, dynamic> post) => _share(context,
    'Bài viết trên Tiniky\n${_short(post['content']?.toString() ?? '')}\ntiniky://post/${post['id']}');
  static Future<void> video(BuildContext context, String id) => _share(context, 'Video trên Tiniky\ntiniky://video/$id');
  static Future<void> profile(BuildContext context, String id, String name) => _share(context,
    'Trang cá nhân của $name trên Tiniky\ntiniky://profile/$id');
  static String _short(String s) => s.length > 160 ? '${s.substring(0, 160)}…' : s;
  static Future<void> _share(BuildContext context, String text) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(text, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được bảng chia sẻ.')));
    }
  }
}
