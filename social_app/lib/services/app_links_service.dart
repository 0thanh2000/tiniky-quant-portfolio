import 'dart:async';
import 'package:app_links/app_links.dart';
class AppLinksService {
  static final _links = AppLinks();
  static StreamSubscription<Uri>? _subscription;
  static Uri? pending;
  static String? _last;
  static DateTime? _lastAt;
  static Future<void> start() async {
    void queue(Uri uri) {
      if (uri.scheme != 'tiniky' || !['post', 'profile', 'video'].contains(uri.host) || uri.pathSegments.length != 1) return;
      if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(uri.pathSegments.first)) return;
      if (_last == uri.toString() && _lastAt != null && DateTime.now().difference(_lastAt!).inSeconds < 2) return;
      _last = uri.toString(); _lastAt = DateTime.now(); pending = uri;
    }
    _subscription ??= _links.uriLinkStream.listen(queue, onError: (_) {});
    try { final initial = await _links.getInitialLink(); if (initial != null) queue(initial); } catch (_) {}
  }
}
