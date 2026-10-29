import '../widgets/social_post_card.dart';
import '../models/post_media.dart';
import '../widgets/media_gallery.dart';
import '../services/share_service.dart';
import 'profile_friends_section.dart';
import 'create_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../widgets/verified_badge.dart';
import '../utils/cache_helper.dart';
import '../utils/cloudinary_helper.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'edit_post_screen.dart';
import 'followers_screen.dart';
import 'saved_posts_screen.dart';
import 'video_viewer_screen.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_tabs.dart';

class ProfileScreen extends StatefulWidget {
  final bool isActive;
  const ProfileScreen({super.
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _myPhotos = [];
  List<Map<String, dynamic>> _myVideos = [];

  int _followerCount = 0;
  int _followingCount = 0;

  bool _isLoading = true;
  bool _isOffline = false;
  int _selectedTab = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _init();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _fetchAll();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final cached = await CacheHelper.getProfile();
    if (cached != null && mounted) {
      setState(() {
        _profile = cached;
        _isLoading = false;
      });
      _animController.forward();
    }
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

          .eq('id', user.id)
          .single();

      final countsRes = await _supabase.rpc(
        'get_follow_counts',
        params: {'user_uuid': user.id},
      );
      final counts = (countsRes as List).first;
      _followerCount = counts['followers'] ?? 0;
      _followingCount = counts['following'] ?? 0;

      final posts = await _supabase
          .from('posts')
          .select('*, likes(user_id), comments(id)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final videos = await _supabase
          .from('videos')
          .select('*, video_likes(user_id), video_comments(id)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _myPosts = List<Map<String, dynamic>>.from(posts);
        _myPhotos = List<Map<String, dynamic>>.from(posts).expand((p) => PostMedia.fromPost(p).where((m) => !m.isVideo).map((m) => {...p, 'image_url': m.url})).toList();
        _myVideos = [...List<Map<String, dynamic>>.from(videos), ...List<Map<String, dynamic>>.from(posts).expand((p) => PostMedia.fromPost(p).where((m) => m.isVideo).map((m) => {...p, 'video_url': m.url, 'is_post_media': true}))];
        _isLoading = false;
        _isOffline = false;
      });
      _animController.forward();

      } else {
        await _loadFromCache();
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheHelper.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = cached;
        _isLoading = false;
        _isOffline = true;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _openEditProfile(
      {bool onlyAvatar = false, bool onlyCover = false}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: _profile,
          onlyAvatar: onlyAvat

  Future<void> _handleDeletePost(Map<String, dynamic> post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa bài viết'),
        content: const Text('Bạn có chắc muốn xóa bài viết này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (post['image_url'] != null) {
        try {
          final url = post['image_url'] as String;
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;
          final postsIndex = pathSegments.indexOf('posts');
          if (postsIndex >= 0 && postsInde
        }
      }

      await _supabase.from('posts').delete().eq('id', post['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa bài viết'),
          backgroundColor: Colors.orange,
        ),
      );
      _fetchAll();
    } catch (e) {
      debugPrint('Lỗi xóa: $e');
    }
  }

  Future<void> _handleEditPost(Map<String, dynamic> post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
    );
    if (result == true) _fetchAll();
  }

  void _openFollowers(String type) {
      MaterialPageRoute(
        builder: (_) => FollowersScreen(userId: userId, type: type),
      ),
    ).then((_) => _fetchAll());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading && _profile == null) {
      return Scaffold(
        backgroundColor: isDark ? FluentColors.darkBg : FluentColors.lightBg,
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? FluentColors.darkBg : FluentColors.lightBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            ProfileHeader(
              profile: _profile,
              onEditAvatar: () => _openE
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            SliverToBoxAdapter(child: _buildNameSection(isDark)),
            SliverToBoxAdapter(
                }))),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeaderDelegate(
                selectedIndex: _selectedTab,
                child: ProfileTabs(
                  selectedIndex: _selectedTab,
                  onTabChanged: (i) => setState(() => _selectedTab = i),
                  postCount: _myPosts.length,
                  videoCount: _myVideos.length,
                  photoCount: _myPhotos.length,
                ),
              ),
            ),
            if (_selectedTab == 0)
              ..._buildPostsSliver(isDark)
            else if (_selectedTab == 1)
              ..._buildPhotosSliver(isDark)
            else if (_selectedTab == 2)
              ..._buildVideosSliver(isDark)
            else if (_selectedTab == 3)
              SliverToBoxAdapter(child: _buildAboutSection(isDark))
            else
              SliverToBoxAdapter(child: ProfileFriendsSection(userId: _supabase.auth.currentUser!.id)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _profile?['username'] ?? 'Người dùng',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FluentColors.darkText
                        : FluentColors.lightText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_profile?['is_verified'] == true)
                VerifiedBadge(
                  size: 22,
                  verifiedType: _profile?['verified_type'],
                ),
              if (_isOffline) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('Offline',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if ((_profile?['bio'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _profile!['bio'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? FluentColors.darkSubText
                    : FluentColors.lightSubText,
              ),
            ),
          ],
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('Bài viết', _myPosts.length, isDark),
              _buildStatDivider(isDark),
              _buildStat('Followers', _followerCount, isDark,
                  type: 'followers'),
              _buildStatDivider(isDark),
              _buildStat('Following', _followingCount, isDark,
                  type: 'following'),
            ],
          ),
          const SizedBox(height: 16),

          // ⭐ NÚT CHỈNH SỬA XANH ĐẬM
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openEditProfile(),
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(
                        color: Colors.white,           // ⭐ Chữ trắng rõ
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FluentColors.accentDark, // ⭐ Xanh đậm
                      foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? FluentColors.darkCard
                      : FluentColors.lightCard,
                  borderRadius: BorderRadius.circular(FluentRadius.medium),
                  border: Border.all(
                    color: isDark
                        ? FluentColors.darkBorder
                        : FluentColors.lightBorder,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.bookmark_outline,
                      color: isDark
                          ? FluentColors.darkText
                          : FluentColors.lightText,
                      size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SavedPostsScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? FluentColors.darkCard
                      : FluentColors.lightCard,
                  borderRadius: BorderRadius.circular(FluentRadius.medium),
                  border: Border.all(
                    color: isDark
                        ? FluentColors.darkBorder
                        : FluentColors.lightBorder,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.share_outlined,
                      color: isDark
                          ? FluentColors.darkText
                          : FluentColors.lightText,
                      size: 20),
                  onPressed: () => ShareService.profile(context, _supabase.auth.currentUser!.id, _profile?['username'] ?? 'Người dùng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, bool isDark, {String? type}) {
    final isClickable = type != null;
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? FluentColors.darkText
                    : FluentColors.lightText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? FluentColors.darkSubText
                    : FluentColors.lightSubText,
                decoration: isClickable
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: isDark
                    ? FluentColors.darkSubText
                    : FluentColors.lightSubText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark
          ? FluentColors.darkBorder
          : FluentColors.lightBorder,
    );
  }

  List<Widget> _buildPostsSliver(bool isDark) {
    if (_myPosts.isEmpty) {
      return [
        SliverToBoxAdapter(
            child: _buildEmptyState('Chưa có bài viết nào', isDark)),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final post = _myPosts[i];
              final likes = (post['likes'] as List?) ?? [];
              final comments = (post['comments'] as List?) ?? [];
              return _buildPostCard(
                  post, likes.length, comments.length, isDark);
            },
            childCount: _myPosts.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildPostCard(Map<String, dynamic> post, int likeCount, int commentCount, bool isDark) {
    return SocialPostCard(key: ValueKey(post['id']), post: post, onChanged: _fetchAll, onEdit: () => _handleEditPost(post), onDelete: () => _handleDeletePost(post));
  }

  List<Widget> _buildPhotosSliver(bool isDark) {
    if (_myPhotos.isEmpty) {
      return [
        SliverToBoxAdapter(
            child: _buildEmptyState('Chưa có ảnh nào', isDark)),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final photo = _myPhotos[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewer(url: photo['image_url']))),
                child: Container(
                  color:
                      isDark ? FluentColors.darkCard : Colors.grey[200],
                  child: CachedNetworkImage(
                    imageUrl:
                        CloudinaryHelper.thumbnail(photo['image_url']),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark
                          ? FluentColors.darkCard
                          : Colors.grey[200],
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark
                          ? FluentColors.darkCard
                          : Colors.grey[200],
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
            childCount: _myPhotos.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVideosSliver(bool isDark) {
    if (_myVideos.isEmpty) {
      return [
        SliverToBoxAdapter(
            child: _buildEmptyState('Chưa có video nào', isDark)),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final video = _myVideos[i];
              final likes = (video['video_likes'] as List?) ?? [];
              return _buildVideoGridItem(video, likes.length, isDark, i);
            },
            childCount: _myVideos.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildVideoGridItem(
      Map<String, dynamic> video, int likeCount, bool isDark, int index) {
    final videoUrl = video['video_url'] as String? ?? '';
    final thumbnailUrl = CloudinaryHelper.videoThumbnail(videoUrl);
    final hasValidThumb =
        thumbnailUrl.isNotEmpty && thumbnailUrl != videoUrl;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => video['is_post_media'] == true ? MediaViewer(url: videoUrl, video: true) : VideoViewerScreen(videos: _myVideos.where((v) => v['is_post_media'] != true).toList(), initialIndex: index, userName: _profile?['username'], userAvatar: _profile?['avatar_url'], userId: _profile?['id']))),
      child: Container(
        color: isDark ? FluentColors.darkCard : Colors.grey[200],
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasValidThumb)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildVideoPlaceholder(isDark),
                errorWidget: (_, __, ___) =>
                    _buildVideoPlaceholder(isDark),
              )
            else
              _buildVideoPlaceholder(isDark),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),

            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 40,
                shadows: [
                  Shadow(blurRadius: 8, color: Colors.black54),
                ],
              ),
            ),

            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Row(
                children: [
                  const Icon(Icons.favorite,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(likeCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (video['caption'] != null &&
                video['caption'].toString().isNotEmpty)
              Positioned(
                top: 6,
                left: 6,
                right: 6,
                child: Text(
                  video['caption'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black87),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.softGreen,
      ),
      child: const Center(
        child: Icon(Icons.videocam_outlined,
            color: Colors.white54, size: 40),
      ),
    );
  }

  Widget _buildAboutSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? FluentColors.darkCard : FluentColors.lightCard,
          borderRadius: BorderRadius.circular(FluentRadius.large),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: FluentColors.accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Thông tin cá nhân',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FluentColors.darkText
                        : FluentColors.lightText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.home_outlined, 'Quê quán',
                _profile?['hometown'], isDark),
            _buildInfoRow(Icons.location_on_outlined, 'Nơi ở',
                _profile?['current_city'], isDark),
            _buildInfoRow(Icons.work_outline, 'Công việc',
                _profile?['work'], isDark),
            _buildInfoRow(Icons.school_outlined, 'Học vấn',
                _profile?['education'], isDark),
            _buildInfoRow(Icons.cake_outlined, 'Sinh nhật',
                _profile?['birthday'], isDark),
            _buildInfoRow(Icons.favorite_outline, 'Mối quan hệ',
                _profile?['relationship_status'], isDark,
                isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String? value, bool isDark,
      {bool isLast = false}) {
    final hasValue = value != null && value.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FluentColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? FluentColors.darkSubText
                        : FluentColors.lightSubText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Chưa cập nhật',
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle:
                        hasValue ? FontStyle.normal : FontStyle.italic,
                    color: hasValue
                        ? (isDark
                            ? FluentColors.darkText
                            : FluentColors.lightText)
                        : (isDark
                            ? FluentColors.darkSubText
                            : FluentColors.lightSubText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 60,
            color: isDark
                ? FluentColors.darkSubText
                : FluentColors.lightSubText,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? FluentColors.darkSubText
                  : FluentColors.lightSubText,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final int selectedIndex;

  _TabHeaderDelegate({
    required this.child,
    required this.selectedIndex,
  });

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? FluentColors.darkBg
            : Colors.white,
        child: child,
      );

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}
