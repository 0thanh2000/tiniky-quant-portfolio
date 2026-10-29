import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_links_service.dart';
import 'call_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'video_viewer_screen.dart';

class SessionShell extends StatefulWidget {
  final Widget child;
  const SessionShell({super.key, required this.child});
  @override State<SessionShell> createState() => _SessionShellState();
}
class _SessionShellState extends State<SessionShell> with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false, _foreground = true;
  RealtimeChannel? _channel;
  final _db = Supabase.instance.client;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    final me = _db.auth.currentUser?.id;
    _channel = _db.channel('incoming-calls:$me').onPostgresChanges(
      event: PostgresChangeEvent.insert, schema: 'public', table: 'app_calls',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'callee_id', value: me), callback: (_) => _check()).subscribe();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { _foreground = state == AppLifecycleState.resumed; if (_foreground) _check(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _timer?.cancel(); if (_channel != null) _db.removeChannel(_channel!); super.dispose(); }
  Future<void> _check() async {
    if (_checking || !_foreground || !mounted || CallScreen.active) return;
    _checking = true;
    try {
      final uri = AppLinksService.pending;
      if (uri != null) {
        AppLinksService.pending = null;
        final id = uri.pathSegments.first;
        if (uri.host == 'post') { unawaited(Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)))); }
        else if (uri.host == 'profile') { unawaited(Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)))); }
        else {
          final video = await _db.from('videos').select().eq('id', id).maybeSingle();
          if (video != null && mounted) unawaited(Navigator.push(context, MaterialPageRoute(builder: (_) => VideoViewerScreen(videos: [video], initialIndex: 0))));
        }
      }
      final me = _db.auth.currentUser?.id;
      if (me == null || !mounted) return;
      final calls = await _db.from('app_calls').select().eq('callee_id', me).eq('status', 'ringing')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String()).order('created_at', ascending: false).limit(1);
      if (calls.isEmpty || !mounted || CallScreen.active) return;
      final call = calls.first;
      final profile = await _db.from('profiles').select('username').eq('id', call['caller_id']).maybeSingle();
      if (!mounted || !_foreground || CallScreen.active) return;
      CallScreen.active = true;
      try { await Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(conversationId: call['conversation_id'].toString(),
        otherId: call['caller_id'].toString(), name: profile?['username'] ?? 'Người dùng', video: call['is_video'] == true, incoming: call))); }
      finally { CallScreen.active = false; }
    } catch (_) { /* Calls remain optional until their migration is installed. */ }
    finally { _checking = false; }
  }
  @override Widget build(BuildContext context) => widget.child;
}
