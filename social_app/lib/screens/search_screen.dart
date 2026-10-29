import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../widgets/verified_badge.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  late TabController _tabController;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _videos = [];

  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  final List<String> _suggestions = [
    'lập trình',
    'viral',
    'xuhuong',
    'chill',
    'nhạc',
    'tiktok',
    'học tập',
    'du lịch',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _users = [];
        _posts = [];
        _videos = [];
        _hasSearched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Tìm users (có is_verified)
      final usersRes = await _supabase
          .from('profiles')
          .select(
              'id, username, full_name, avatar_url, bio, is_verified, verified_type')
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(20);

      final postsRes = await _supabase
          .from('posts')
          .select('*, profiles!user_id(username, avatar_url)')
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      final videosRes = await _supabase
          .from('videos')
          .select('*, profiles!user_id(username, avatar_url)')
          .or('caption.ilike.%$query%,music_name.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(20);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(usersRes);
        _posts = List<Map<String, dynamic>>.from(postsRes);
        _videos = List<Map<String, dynamic>>.from(videosRes);
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Lỗi tìm kiếm: $e');
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _handleSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _performSearch(suggestion);
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
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? AppColors.darkText : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBg : AppColors.lightBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(Icons.search,
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: TextStyle(
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm bạn bè, bài viết...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: Icon(Icons.close,
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      size: 20),
                ),
            ],
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? _buildSuggestions(isDark)
              : _buildResults(isDark),
    );
  }

  Widget _buildSuggestions(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                'Tìm kiếm phổ biến',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => _handleSuggestionTap(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '#$s',
                    style: TextStyle(
                      color:
                          isDark ? AppColors.darkText : AppColors.lightText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    return Column(
      children: [
        Container(
          color: isDark ? AppColors.darkCard : Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gradStart,
            labelColor: AppColors.gradStart,
            unselectedLabelColor: isDark
                ? AppColors.darkSubText
                : AppColors.lightSubText,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'Người dùng (${_users.length})'),
              Tab(text: 'Bài viết (${_posts.length})'),
              Tab(text: 'Video (${_videos.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUsersTab(isDark),
              _buildPostsTab(isDark),
              _buildVideosTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // TAB 1: NGƯỜI DÙNG (có tích xanh)
  // ============================================
  Widget _buildUsersTab(bool isDark) {
    if (_users.isEmpty) {
      return _buildEmpty('Không tìm thấy người dùng nào', isDark);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      itemBuilder: (context, i) {
        final user = _users[i];
        final avatarUrl = user['avatar_url'];
        return ListTile(
          onTap: () => _openProfile(user['id']),
          leading: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              gradient: AppGradients.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: isDark ? AppColors.darkBg : Colors.white,
              backgroundImage: avatarUrl != null &&
                      avatarUrl.toString().isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.toString().isEmpty
                  ? const Icon(Icons.person, color: AppColors.gradStart)
                  : null,
            ),
          ),
          // TÊN + TÍCH XANH
          title: Row(
            children: [
              Flexible(
                child: Text(
                  user['username'] ?? 'Người dùng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user['is_verified'] == true)
                VerifiedBadge(
                  size: 16,
                  verifiedType: user['verified_type'],
                ),
            ],
          ),
          subtitle: user['bio'] != null &&
                  user['bio'].toString().isNotEmpty
              ? Text(
                  user['bio'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                  ),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right,
            color:
                isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(bool isDark) {
    if (_posts.isEmpty) {
      return _buildEmpty('Không tìm thấy bài viết nào', isDark);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        final profile = post['profiles'] ?? {};
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
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
                    radius: 16,
                    backgroundColor: AppColors.gradStart,
                    backgroundImage: profile['avatar_url'] != null
                        ? NetworkImage(profile['avatar_url'])
                        : null,
                    child: profile['avatar_url'] == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile['username'] ?? 'Người dùng',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (post['content'] != null &&
                  post['content'].toString().isNotEmpty)
                Text(
                  post['content'],
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              if (post['image_url'] != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: post['image_url'],
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 150,
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideosTab(bool isDark) {
    if (_videos.isEmpty) {
      return _buildEmpty('Không tìm thấy video nào', isDark);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, i) {
        final video = _videos[i];
        final videoUrl = video['video_url'] as String? ?? '';
        String thumbUrl = videoUrl;
        if (videoUrl.endsWith('.mp4') || videoUrl.endsWith('.mov')) {
          thumbUrl = '${videoUrl.substring(0, videoUrl.length - 4)}.jpg';
        }
        return GestureDetector(
          onTap: () {
            final userId = video['user_id'];
            if (userId != null) _openProfile(userId.toString());
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: isDark ? AppColors.darkCard : Colors.grey[200],
                  child: const Icon(Icons.videocam,
                      color: Colors.white54, size: 30),
                ),
              ),
              const Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white, size: 32),
              ),
              if (video['caption'] != null &&
                  video['caption'].toString().isNotEmpty)
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Text(
                    video['caption'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 60,
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText),
          const SizedBox(height: 12),
          Text(
            message,
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
