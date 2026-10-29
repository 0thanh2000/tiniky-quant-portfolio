import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/comments_sheet.dart';
import '../screens/post_detail_screen.dart';
import '../services/share_service.dart';
import 'post_body.dart';
class SocialPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChanged;
  final bool expanded;
  const SocialPostCard({super.key, required this.post, this.onEdit, this.onDelete, this.onChanged, this.expanded = false});
  @override State<SocialPostCard> createState() => _SocialPostCardState();
}
class _SocialPostCardState extends State<SocialPostCard> {
  bool _busy = false;
  late bool _liked;
  late int _likes;
  int _comments = 0;
  @override void initState() { super.initState(); _read(); }
  @override void didUpdateWidget(covariant SocialPostCard oldWidget) { super.didUpdateWidget(oldWidget); _read(); }
  void _read() {
    final likes = (widget.post['likes'] as List?) ?? [];
    final me = Supabase.instance.client.auth.currentUser?.id;
    _liked = likes.any((l) => l['user_id'] == me); _likes = likes.length;
    _comments = ((widget.post['comments'] as List?) ?? []).length;
  }
  Future<void> _like() async {
    if (_busy) return;
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      if (_liked) { await db.from('likes').delete().match({'user_id': me, 'post_id': widget.post['id']}); }
      else { await db.from('likes').insert({'user_id': me, 'post_id': widget.post['id']}); }
      if (mounted) setState(() { _likes += _liked ? -1 : 1; _liked = !_liked; });
      widget.onChanged?.call();
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa cập nhật được lượt thích.'))); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _comment() async {
    await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent, builder: (_) => CommentsSheet(postId: widget.post['id'].toString()));
    widget.onChanged?.call();
  }
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 8, 6, 0), child: Row(children: [
        const Icon(Icons.public, size: 14), const SizedBox(width: 6), const Text('Công khai', style: TextStyle(fontSize: 12)), const Spacer(),
        if (widget.onEdit != null || widget.onDelete != null) PopupMenuButton<String>(
          onSelected: (v) { if (v == 'edit') widget.onEdit?.call(); if (v == 'delete') widget.onDelete?.call(); },
          itemBuilder: (_) => [if (widget.onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            if (widget.onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Xóa bài viết'))]),
      ])),
      PostBody(post: widget.post, expanded: widget.expanded, onOpen: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: widget.post['id'].toString())));
        widget.onChanged?.call();
      }),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
        Expanded(child: TextButton.icon(onPressed: _busy ? null : _like,
          icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? Colors.red : null, size: 20), label: Text('$_likes'))),
        Expanded(child: TextButton.icon(onPressed: _comment, icon: const Icon(Icons.chat_bubble_outline, size: 20), label: Text('$_comments'))),
        Expanded(child: TextButton.icon(onPressed: () => ShareService.post(context, widget.post), icon: const Icon(Icons.share_outlined, size: 20), label: const Text('Chia sẻ'))),
      ])),
    ]));
}
