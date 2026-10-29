import '../widgets/post_body.dart';
import 'post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'user_profile_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});
  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSaved();
  }

  Future<void> _fetchSaved() async {
    try {
      final me = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('bookmarks')
          .select('''
            post_id,
            created_at,
            posts:post_id (
              *,
              profiles!user_id (id, username, avatar_url),
              likes(user_id),
              comments(id)
            )
          ''')
          .eq('user_id', me)
          .order('created_at', ascending: false);

      final posts = response.where((item) => item['posts'] != null)
          .map<Map<String, dynamic>>((item) => {
                ...Map<String, dynamic>.from(item['posts'] ?? {}),
                'bookmarked_at': item['created_at'],
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _savedPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải saved: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unsave(String postId) async {
    final me = _supabase.auth.currentUser!.id;
    try {
      await _supabase
          .from('bookmarks')
          .delete()
          .match({'user_id': me, 'post_id': postId});
      if (!mounted) return;
      setState(() {
        _savedPosts.removeWhere((p) => p['id'] == postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ lưu')),
      );
    } catch (e) {
      debugPrint('Lỗi bỏ lưu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Bài viết đã lưu'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedPosts.isEmpty
              ? _buildEmpty(isDark)
              : RefreshIndicator(
                  onRefresh: _fetchSaved,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _savedPosts.length,
                    itemBuilder: (context, i) =>
                        _buildPostCard(_savedPosts[i], isDark),
                  ),
                ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, bool isDark) {
    final profile = post['profiles'] ?? {};
    final likes = (post['likes'] as List?) ?? [];
    final comments = (post['comments'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserProfileScreen(userId: profile['id']),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.gradStart,
                    backgroundImage: profile['avatar_url'] != null
                        ? NetworkImage(profile['avatar_url'])
                        : null,
                    child: profile['avatar_url'] == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile['username'] ?? 'Người dùng',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                ),
                // Nút bỏ lưu
                IconButton(
                  icon: const Icon(Icons.bookmark,
                      color: AppColors.gradStart),
                  onPressed: () => _unsave(post['id']),
                ),
              ],
            ),
          ),
          PostBody(post: post, onOpen: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post['id'].toString())))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.favorite,
                    color: AppColors.likeRed, size: 18),
                const SizedBox(width: 4),
                Text('${likes.length}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: 13,
                    )),
                const SizedBox(width: 16),
                Icon(Icons.mode_comment_outlined,
                    size: 18,
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
                const SizedBox(width: 4),
                Text('${comments.length}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border,
              size: 80,
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText),
          const SizedBox(height: 12),
          Text(
            'Chưa có bài viết nào được lưu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bấm biểu tượng bookmark trên bài viết để lưu',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
            ),
          ),
        ],
      ),
    );
  }
}
