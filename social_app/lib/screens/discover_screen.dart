import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import 'hashtag_screen.dart';
import 'user_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _trendingHashtags = [];
  List<Map<String, dynamic>> _topPosts = [];
  List<Map<String, dynamic>> _suggestedUsers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      // 1. Trending hashtags
      final hashtagsRes = await _supabase
          .rpc('get_trending_hashtags', params: {
        'days_back': 7,
        'max_count': 12,
      });

      // 2. Top posts (nhiều like nhất 7 ngày qua)
      final topPostsRes = await _supabase
          .from('posts')
          .select(
              '*, profiles!user_id(username, avatar_url), likes(user_id)')
          .order('created_at', ascending: false)
          .limit(30);

      // Sort theo số like
      final topPosts = List<Map<String, dynamic>>.from(topPostsRes);
      topPosts.sort((a, b) {
        final likesA = (a['likes'] as List?)?.length ?? 0;
        final likesB = (b['likes'] as List?)?.length ?? 0;
        return likesB.compareTo(likesA);
      });

      // 3. Suggested users (random 10 user)
      final usersRes = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, bio')
          .limit(20);

      if (!mounted) return;
      setState(() {
        _trendingHashtags = List<Map<String, dynamic>>.from(hashtagsRes);
        _topPosts = topPosts.take(15).toList();
        _suggestedUsers = List<Map<String, dynamic>>.from(usersRes);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải discover: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openHashtag(String hashtag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HashtagScreen(hashtag: hashtag),
      ),
    );
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.primaryGradient.createShader(bounds),
          child: const Text(
            'Khám phá',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TRENDING HASHTAGS
                    _buildSectionTitle(
                      'Trending Hashtag',
                      Icons.local_fire_department,
                      Colors.orange,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildHashtagList(isDark),
                    const SizedBox(height: 24),

                    // GỢI Ý NGƯỜI DÙNG
                    _buildSectionTitle(
                      'Gợi ý người dùng',
                      Icons.people_outline,
                      AppColors.gradStart,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildSuggestedUsers(isDark),
                    const SizedBox(height: 24),

                    // BÀI VIẾT NỔI BẬT
                    _buildSectionTitle(
                      'Bài viết nổi bật',
                      Icons.trending_up,
                      Colors.green,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildTopPosts(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(
      String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  // ============================================
  // DANH SÁCH HASHTAG TRENDING
  // ============================================
  Widget _buildHashtagList(bool isDark) {
    if (_trendingHashtags.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Chưa có hashtag nào trending',
          style: TextStyle(
            color:
                isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _trendingHashtags.map((item) {
        final hashtag = item['hashtag'] as String;
        final count = item['post_count'] as int;
        return GestureDetector(
          onTap: () => _openHashtag(hashtag),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.gradStart.withValues(alpha: 0.15),
                  AppColors.gradMid.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gradStart.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hashtag,
                  style: const TextStyle(
                    color: AppColors.gradStart,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '($count)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // GỢI Ý NGƯỜI DÙNG
  // ============================================
  Widget _buildSuggestedUsers(bool isDark) {
    if (_suggestedUsers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedUsers.length,
        itemBuilder: (context, i) {
          final user = _suggestedUsers[i];
          return GestureDetector(
            onTap: () => _openProfile(user['id']),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      gradient: AppGradients.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          isDark ? AppColors.darkBg : Colors.white,
                      backgroundImage: user['avatar_url'] != null
                          ? CachedNetworkImageProvider(user['avatar_url'])
                          : null,
                      child: user['avatar_url'] == null
                          ? const Icon(Icons.person,
                              color: AppColors.gradStart)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user['username'] ?? 'User',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // BÀI VIẾT NỔI BẬT
  // ============================================
  Widget _buildTopPosts(bool isDark) {
    if (_topPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _topPosts.map((post) {
        final profile = post['profiles'] ?? {};
        final likes = (post['likes'] as List?) ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.gradStart,
                    backgroundImage: profile['avatar_url'] != null
                        ? NetworkImage(profile['avatar_url'])
                        : null,
                    child: profile['avatar_url'] == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile['username'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.favorite,
                      color: AppColors.likeRed, size: 14),
                  const SizedBox(width: 4),
                  Text('${likes.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                      )),
                ],
              ),
              if (post['content'] != null &&
                  post['content'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    post['content'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}