import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_media.dart';
import '../services/media_service.dart';
import '../widgets/media_gallery.dart';
import '../widgets/message_composer.dart';
import '../widgets/verified_badge.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final bool isVideo;
  const CommentsSheet({super.key, required this.postId, this.isVideo = false});
  @override State<CommentsSheet> createState() => _CommentsSheetState();
}
class _CommentsSheetState extends State<CommentsSheet> {
  final _db = Supabase.instance.client;
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true, _more = true, _fetching = false, _fetchAgain = false;
  String? _error;
  int _limit = 40;
  RealtimeChannel? _channel;
  String get _table => widget.isVideo ? 'video_comments' : 'comments';
  String get _column => widget.isVideo ? 'video_id' : 'post_id';
  @override void initState() {
    super.initState(); _load();
    _channel = _db.channel('comments:$_table:${widget.postId}:${identityHashCode(this)}')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: _table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: _column, value: widget.postId),
        callback: (_) => _load()).subscribe();
  }
  @override void dispose() { _scroll.dispose(); if (_channel != null) _db.removeChannel(_channel!); super.dispose(); }
  Future<void> _load() async {
    if (_fetching) { _fetchAgain = true; return; }
    _fetching = true;
    try {
      final rows = await _db.from(_table).select('*, profiles!user_id(username, avatar_url, is_verified, verified_type)')
        .eq(_column, widget.postId).order('created_at', ascending: false).order('id', ascending: false).limit(_limit);
      if (mounted) setState(() { _comments = List<Map<String, dynamic>>.from(rows); _more = rows.length == _limit; _error = null; });
    } catch (_) { if (mounted) setState(() => _error = 'Không tải được bình luận.'); }
    finally {
      _fetching = false;
      if (mounted) {
        setState(() => _loading = false);
        if (_fetchAgain) { _fetchAgain = false; _load(); }
      }
    }
  }
  Future<void> _send(String text, XFile? file, bool video) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Bạn cần đăng nhập lại.');
    final media = file == null ? null : await MediaService.uploadPublic(file, video: video);
    await _db.from(_table).insert({_column: widget.postId, 'user_id': user.id,
      'content': text, 'media': media?.toJson()});
    await _load();
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    if (!widget.isVideo) _notify(text, media);
  }
  Future<void> _notify(String text, PostMedia? media) async {
    try {
      final post = await _db.from('posts').select('user_id').eq('id', widget.postId).single();
      final me = _db.auth.currentUser!.id;
      if (post['user_id'] == me) return;
      final profile = await _db.from('profiles').select('username').eq('id', me).single();
      await _db.functions.invoke('notify-comment', body: {'post_owner_id': post['user_id'], 'commenter_id': me,
        'commenter_name': profile['username'], 'comment_text': text.isEmpty ? (media?.isVideo == true ? 'Đã bình luận bằng video' : 'Đã bình luận bằng ảnh') : text,
        'post_id': widget.postId});
    } catch (_) { /* The comment is saved even if push is unavailable. */ }
  }
  Future<void> _delete(Map<String, dynamic> comment) async {
    try {
      await _db.from(_table).delete().eq('id', comment['id']).eq('user_id', _db.auth.currentUser!.id);
      await _load();
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không xóa được bình luận.'))); }
  }
  @override Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * .85 - keyboard).clamp(180.0, 900.0).toDouble();
    return Padding(padding: EdgeInsets.only(bottom: keyboard), child: SizedBox(height: height,
      child: Material(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias, child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 6, 6), child: Row(children: [
            Text('Bình luận', style: Theme.of(context).textTheme.titleLarge), const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ])), const Divider(height: 1),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _error != null ? Center(child: TextButton(onPressed: _load, child: Text('$_error Thử lại')))
            : _comments.isEmpty ? const Center(child: Text('Chia sẻ cảm nghĩ đầu tiên của bạn'))
            : RefreshIndicator(onRefresh: _load, child: ListView.builder(controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12),
              itemCount: _comments.length + (_more ? 1 : 0), itemBuilder: (context, i) {
                if (i == _comments.length) return TextButton(onPressed: () { _limit += 40; _load(); }, child: const Text('Xem bình luận trước'));
                final c = _comments[i]; final p = c['profiles'] as Map? ?? {}; final media = PostMedia.parse(c['media']);
                return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 18, backgroundImage: p['avatar_url'] == null ? null : NetworkImage(p['avatar_url']),
                    child: p['avatar_url'] == null ? const Icon(Icons.person_outline, size: 18) : null), const SizedBox(width: 8),
                  Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(p['username'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (p['is_verified'] == true) VerifiedBadge(size: 14, verifiedType: p['verified_type']),
                        if (c['user_id'] == _db.auth.currentUser?.id) PopupMenuButton<String>(padding: EdgeInsets.zero,
                          onSelected: (_) => _delete(c), itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Xóa bình luận'))]),
                      ]),
                      if ((c['content']?.toString() ?? '').isNotEmpty) Text(c['content']),
                      if (media != null) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: SizedBox(height: 190, width: double.infinity, child: MediaTile(key: ValueKey(c['id']), media: media)))),
                    ]))),
                ]));
              }))),
          const Divider(height: 1), MessageComposer(hint: 'Viết bình luận...', onSend: _send),
        ]))));
  }
}
