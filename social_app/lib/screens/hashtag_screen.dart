import '../widgets/post_body.dart';
import 'post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'user_profile_screen.dart';

class HashtagScreen extends StatefulWidget {
  final String hashtag;
  const HashtagScreen({super.key, required this.hashtag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      // Bỏ dấu # trong query
      final tag = widget.hashtag.replaceFirst('#', '');

      final response = await _supabase
          .from('posts')
          .select(
              '*, profiles!user_id(id, username, avatar_url), likes(user_id), comments(id)')
          .ilike('content', '%#$tag%')
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _posts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải hashtag: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          widget.hashtag,
          style: const TextStyle(
            color: AppColors.gradStart,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmpty(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _posts.length,
                  itemBuilder: (context, i) =>
                      _buildPostCard(_posts[i], isDark),
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserProfileScreen(userId: profile['id']),
                      ),
                    );
                  },
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
                Text(
                  profile['username'] ?? 'Người dùng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
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
          Icon(Icons.tag,
              size: 80,
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText),
          const SizedBox(height: 12),
          Text(
            'Chưa có bài viết nào với hashtag này',
            style: TextStyle(
              fontSize: 15,
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
