import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_media.dart';
import '../services/media_service.dart';
import '../widgets/media_gallery.dart';
import '../widgets/message_composer.dart';
import '../widgets/verified_badge.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId, otherUserName, otherUserId;
  final bool otherUserVerified;
  final String? otherUserVerifiedType;
  const ChatScreen({super.key, required this.conversationId, required this.otherUserName,
    required this.otherUserId, this.otherUserVerified = false, this.otherUserVerifiedType});
  @override State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _db = Supabase.instance.client;
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true, _more = true, _fetching = false, _again = false;
  int _limit = 50;
  String? _error;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); _load();
    _channel = _db.channel('chat:${widget.conversationId}:${identityHashCode(this)}')
      .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.conversationId),
        callback: (_) => _load()).subscribe((status, error) { if (status == RealtimeSubscribeStatus.subscribed) _load(); });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _load(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _scroll.dispose(); if (_channel != null) _db.removeChannel(_channel!); super.dispose(); }
  Future<void> _load() async {
    if (_fetching) { _again = true; return; }
    _fetching = true;
    try {
      final rows = await _db.from('messages').select().eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: false).order('id', ascending: false).limit(_limit);
      if (mounted) setState(() { _messages = List<Map<String, dynamic>>.from(rows); _more = rows.length == _limit; _error = null; });
    } catch (_) { if (mounted) setState(() => _error = 'Không tải được tin nhắn. Kiểm tra kết nối.'); }
    finally {
      _fetching = false;
      if (mounted) { setState(() => _loading = false); if (_again) { _again = false; _load(); } }
    }
  }
  Future<void> _send(String text, XFile? file, bool video) async {
    final me = _db.auth.currentUser?.id;
    if (me == null) throw Exception('Bạn cần đăng nhập lại.');
    PostMedia? media;
    try {
      if (file != null) media = await MediaService.uploadChat(file, widget.conversationId, video: video);
      await _db.from('messages').insert({'conversation_id': widget.conversationId, 'sender_id': me,
        'content': text, 'media': media?.toJson()});
    } catch (e) {
      if (media != null) { try { await MediaService.removeFailedChatUpload(media); } catch (_) {} }
      rethrow;
    }
    await _load();
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    _notify(text.isNotEmpty ? text : video ? 'Đã gửi một video' : 'Đã gửi một ảnh');
  }
  Future<void> _notify(String text) async {
    try {
      final me = _db.auth.currentUser!.id;
      final p = await _db.from('profiles').select('username').eq('id', me).single();
      await _db.functions.invoke('notify-chat', body: {'recipient_id': widget.otherUserId, 'sender_id': me,
        'sender_name': p['username'], 'message_text': text, 'conversation_id': widget.conversationId});
    } catch (_) { /* Message delivery does not depend on push. */ }
  }
  Future<void> _call(bool video) => CallScreen.openOutgoing(context, conversationId: widget.conversationId,
    otherId: widget.otherUserId, name: widget.otherUserName, video: video);
  String _time(dynamic value) { final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal(); return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }
  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(titleSpacing: 0, title: Row(children: [
      CircleAvatar(radius: 18, child: Text(widget.otherUserName.isEmpty ? '?' : widget.otherUserName.characters.first.toUpperCase())),
      const SizedBox(width: 10), Expanded(child: Text(widget.otherUserName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      if (widget.otherUserVerified) VerifiedBadge(size: 15, verifiedType: widget.otherUserVerifiedType),
    ]), actions: [IconButton(tooltip: 'Gọi thoại', onPressed: () => _call(false), icon: const Icon(Icons.call_outlined)),
      IconButton(tooltip: 'Gọi video', onPressed: () => _call(true), icon: const Icon(Icons.videocam_outlined))]),
    body: Column(children: [
      if (_error != null) MaterialBanner(content: Text(_error!), actions: [TextButton(onPressed: _load, child: const Text('Thử lại'))]),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined, size: 60, color: colors.primary), const SizedBox(height: 12), const Text('Bắt đầu cuộc trò chuyện'),
          const SizedBox(height: 4), const Text('Gửi lời chào, ảnh hoặc một video ngắn'),
        ])) : ListView.builder(reverse: true, controller: _scroll, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          itemCount: _messages.length + (_more ? 1 : 0), itemBuilder: (context, i) {
            if (i == _messages.length) return TextButton(onPressed: () { _limit += 50; _load(); }, child: const Text('Tải tin nhắn cũ'));
            final m = _messages[i]; final mine = m['sender_id'] == _db.auth.currentUser?.id;
            final media = PostMedia.parse(m['media']);
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .76),
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 5), bottomRight: Radius.circular(mine ? 5 : 20))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                if (media != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 230, height: 210,
                  child: MediaTile(key: ValueKey(m['id']), media: media))),
                if ((m['content']?.toString() ?? '').isNotEmpty) Padding(padding: EdgeInsets.only(top: media == null ? 0 : 8),
                  child: SelectableText(m['content'], style: TextStyle(color: mine ? colors.onPrimaryContainer : colors.onSurface, fontSize: 15))),
                const SizedBox(height: 4), Text(_time(m['created_at']), style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
              ])));
          })),
      MessageComposer(onSend: _send),
    ]));
  }
}
