import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/social_post_card.dart';
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});
  @override State<PostDetailScreen> createState() => _PostDetailScreenState();
}
class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final p = await Supabase.instance.client.from('posts')
        .select('*, profiles!user_id(username), likes(user_id), comments(id)').eq('id', widget.postId).maybeSingle();
      if (mounted) setState(() { _post = p; _error = p == null ? 'Bài viết đã bị xóa hoặc bạn không có quyền xem.' : null; });
    } catch (_) { if (mounted) setState(() => _error = 'Không tải được bài viết.'); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Bài viết')),
    body: _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: _load, child: const Text('Thử lại'))]))
      : _post == null ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12), children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(_post!['profiles']?['username'] ?? 'Người dùng', style: Theme.of(context).textTheme.titleLarge)),
          SocialPostCard(post: _post!, expanded: true, onChanged: _load),
        ])));
}
