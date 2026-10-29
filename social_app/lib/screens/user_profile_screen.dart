import '../services/conversation_service.dart';
import '../widgets/social_post_card.dart';
import '../models/post_media.dart';
import '../widgets/media_gallery.dart';
import '../services/share_service.dart';
import '../utils/cloudinary_helper.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'video_viewer_screen.dart';
import 'widgets/profile_tabs.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _videos = [];

  int _followerCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  String _friendshipStatus = 'none';
  bool _isMyProfile = false;

  bool _isLoading = true;
  int _selectedTab = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
      _isMyProfile = (me == widget.userId);

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      final countsRes = await _supabase.rpc(
        'get_follow_counts',
        params: {'user_uuid': widget.userId},
      );
      final counts = (countsRes as List).first;
      _followerCount = counts['followers'] ?? 0;
      _followingCount = counts['following'] ?? 0;

      if (!_isMyProfile) {
        final followRes = await _supabase.rpc(
          'is_following',
          params: {'follower': me, 'following': widget.userId},
        );
        _isFollowing = followRes == true;

        final friends = await _supabase.from('friendships').select('user_id, friend_id, status')
          .or('and(user_id.eq.$me,friend_id.eq.${widget.userId}),and(user_id.eq.${widget.userId},friend_id.eq.$me)');
        _friendshipStatus = 'none';
        for (final f in friends) {
          if (f['status'] == 'accepted') { _friendshipStatus = 'accepted'; break; }
          if (f['status'] == 'pending') _friendshipStatus = f['user_id'] == me ? 'pending' : 'received';
        }
      }

      final posts = await _supabase
          .from('posts')
          .select('*, likes(user_id), comments(id)')
      final videos = await _supabase
          .from('videos')
          .select('*, video_likes(user_id), video_comments(id)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = List<Map<String, dynamic>>.from(posts);
        _photos = List<Map<String, dynamic>>.from(posts).expand((p) => PostMedia.fromPost(p).where((m) => !m.isVideo).map((m) => {...p, 'image_url': m.url})).toList();
        _videos = [...List<Map<String, dynamic>>.from(videos), ...List<Map<String, dynamic>>.from(posts).expand((p) => PostMedia.fromPost(p).where((m) => m.isVideo).map((m) => {...p, 'video_url': m.url, 'is_post_media': true}))];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải user profile: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isProcessing || _isMyProfile) return;
    setState(() => _isProcessing = true);
    try {
      if (_isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .match({'follower_id': me, 'following_id': widget.userId});
        if (!mounted) return;
        setState(() {
          _isFollowing = false;
          _followerCount = (_followerCount - 1).clamp(0, 9999999);
        });
      } else {
        await _supabase.from('follows').insert({
          'follower_id': me,
          'following_id': widget.userId,
        });
        if (!mounted) return;
        setState(() {
          _isFollowing = true;
        final myProfile = await _supabase
            .from('profiles')
            .select('username')
            .eq('id', me)
            .single();
        final myName = myProfile['username'] ?? 'Ai đó';

        _supabase.functions.invoke('notify-follow', body: {
          'target_user_id': widget.userId,
          'follower_id': me,           // ⭐ THÊM
          'follower_name': myName,     // ⭐ Tên thật
        }).then((_) {}, onError: (e) {
          debugPrint('Lỗi notify: $e');
        });
      }
    } catch (e) {
      debugPrint('Lỗi follow: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isProcessing || _isMyProfile) return;
    setState(() => _isProcessing = true);

    try {
      await _supabase.rpc('app_request_friend', params: {'other_user': widget.userId});

      if (!mounted) return;
      await _fetchAll();
      if (!mounted) return;
        ),
      );
    } catch (e) {
      debugPrint('Lỗi kết bạn: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _unfriend() async {
    if (_isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text(
            'Bạn có chắc muốn hủy kết bạn với ${_profile?['username'] ?? 'người này'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    final me = _supabase.auth.currentUser!.id;

    try {
      await _supabase
          .from('friendships')
          .delete()
          .match({'user_id': me, 'friend_id': widget.userId});

      await _supabase
          .from('friendships')
          .delete()
          .match({'user_id': widget.userId, 'friend_id': me});

      if (!mounted) return;
      setState(() => _friendshipStatus = 'none');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy kết bạn'),
          backgroundColor: Colors.orange,
    }
  }

  Future<void> _cancelFriendRequest() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final me = _supabase.auth.currentUser!.id;

    try {
      await _supabase
          .from('friendships')
          .delete()
          .match({'user_id': me, 'friend_id': widget.userId});

      if (!mounted) return;
      setState(() => _friendshipStatus = 'none');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hủy lời mời kết bạn')),
      );
    } catch (e) {
      debugPrint('Lỗi hủy lời mời: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openChat() async {
    if (_isMyProfile) return;

    try {
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: _profile?['username'] ?? 'Người dùng',
            otherUserId: widget.userId,
            otherUserVerified: _profile?['is_verified'] == true,
            otherUserVerifiedType: _profile?['verified_type'],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Lỗi mở chat: $e');
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile),
      ),
    );
    if (result == true) _fetchAll();
  }

  void _openFollowers(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowersScreen(
          userId: widget.userId,
          type: type,
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? FluentColors.darkBg : FluentColors.lightBg,
        body: const Center(
          child: CircularProgressIndicator(color: FluentColors.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? FluentColors.darkBg : FluentColors.lightBg,
      body: CustomScrollView(
        slivers: [
          _buildHeader(isDark),
          SliverToBoxAdapter(child: _buildInfoSection(isDark)),
          if (!_isMyProfile) SliverToBoxAdapter(child: Align(alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: () => ShareService.profile(context, widget.userId, _profile?['username'] ?? 'Người dùng'),
              icon: const Icon(Icons.share_outlined), label: const Text('Chia sẻ trang cá nhân')))),
          if (_isMyProfile) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(onPressed: () async {
              final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
              if (saved == true) _fetchAll();
            }, icon: const Icon(Icons.edit_note), label: const Text('Đăng bài viết')))),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              selectedIndex: _selectedTab,
              child: ProfileTabs(
                selectedIndex: _selectedTab,
                onTabChanged: (i) => setState(() => _selectedTab = i),
                postCount: _posts.length,
                videoCount: _videos.length,
                photoCount: _photos.length,
              ),
            ),
            ..._buildVideosSliver(isDark)
          else if (_selectedTab == 3)
            SliverToBoxAdapter(child: _buildAboutSection(isDark))
          else
            SliverToBoxAdapter(child: ProfileFriendsSection(userId: widget.userId)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final coverUrl = _profile?['cover_url'];
    final avatarUrl = _profile?['avatar_url'];

    final screenWidth = MediaQuery.of(context).size.width;
    final coverHeight = screenWidth * 0.56;
    const avatarRadius = 56.0;
    const avatarBorder = 7.0;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: coverHeight + avatarRadius + avatarBorder,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppGradients.primaryGradient,
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0, 0.4, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.arrow_back,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: coverHeight - avatarRadius - avatarBorder,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? FluentColors.darkBg : Colors.white,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.primaryGradient,
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: FluentColors.accent,
                      backgroundImage: avatarUrl != null &&
                              avatarUrl.toString().isNotEmpty
                          ? CachedNetworkImageProvider(
                              CloudinaryHelper.avatarLarge(avatarUrl))
                          : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
            ],
          ),
          if ((_profile?['bio'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
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
              _buildStat('Bài viết', _posts.length, isDark),
              _buildStatDivider(isDark),
              _buildStat('Followers', _followerCount, isDark,
                  type: 'followers'),
              _buildStatDivider(isDark),
              _buildStat('Following', _followingCount, isDark,
                  type: 'following'),
            ],
          ),
          const SizedBox(height: 16),

          _isMyProfile
              ? _buildMyProfileButtons(isDark)
              : _buildOtherProfileButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildMyProfileButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            child: ElevatedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 18),
              label: const Text(
                'Chỉnh sửa',
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: FluentColors.accentDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FluentRadius.medium),
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
            color: isDark ? FluentColors.darkCard : FluentColors.lightCard,
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
            onPressed: () => ShareService.profile(context, widget.userId, _profile?['username'] ?? 'Người dùng'),
          ),
        ),
      ],
    );
  }

  // ⭐ NÚT KẾT BẠN XANH ĐẬM + BỎ THEO DÕI CAM
  Widget _buildOtherProfileButtons(bool isDark) {
    return Row(
      children: [
        // ⭐ NÚT THEO DÕI / BỎ THEO DÕI
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _toggleFollow,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isFollowing
                          ? Icons.person_remove_outlined
                          : Icons.person_add_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
              label: Text(
                _isFollowing ? 'Bỏ theo dõi' : 'Theo dõi',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                // ⭐ CAM khi đang follow, XANH ĐẬM khi chưa follow
                backgroundColor: _isFollowing
                    ? FluentColors.accentOrange  // Cam #F97316
                    : FluentColors.accentDark,   // Xanh đậm #059669
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FluentRadius.medium),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ⭐ NÚT KẾT BẠN
        Expanded(
          child: SizedBox(
            height: 48,
            child: _buildFriendButton(isDark),
          ),
        ),
        const SizedBox(width: 10),

        // ⭐ NÚT CHAT
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: isDark ? FluentColors.darkCard : FluentColors.lightCard,
            borderRadius: BorderRadius.circular(FluentRadius.medium),
            border: Border.all(
              color: isDark
                  ? FluentColors.darkBorder
                  : FluentColors.lightBorder,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.chat_bubble_outline,
              color: isDark
                  ? FluentColors.darkText
                  : FluentColors.lightText,
              size: 20,
            ),
            onPressed: _openChat,
          ),
        ),
      ],
    );
  }

  // ⭐ NÚT KẾT BẠN XANH ĐẬM
  Widget _buildFriendButton(bool isDark) {
    switch (_friendshipStatus) {
      case 'received':
        return ElevatedButton.icon(onPressed: _isProcessing ? null : () async {
          setState(() => _isProcessing = true);
          try {
            await _supabase.from('friendships').update({'status': 'accepted'})
              .match({'user_id': widget.userId, 'friend_id': _supabase.auth.currentUser!.id, 'status': 'pending'});
            await _fetchAll();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không chấp nhận được lời mời: $e')));
          } finally { if (mounted) setState(() => _isProcessing = false); }
        }, icon: const Icon(Icons.person_add_alt_1), label: const Text('Chấp nhận'));
      case 'accepted':
        // ĐÃ LÀ BẠN BÈ → Nút xanh emerald nhạt hơn
        return ElevatedButton.icon(
          onPressed: _isProcessing ? null : _unfriend,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.people,
                  color: Colors.white, size: 18),
          label: const Text(
            'Bạn bè',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: FluentColors.accent, // Xanh emerald
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FluentRadius.medium),
            ),
          ),
        );

      case 'pending':
        // ĐÃ GỬI LỜI MỜI → Xám
        return ElevatedButton.icon(
          onPressed: _isProcessing ? null : _cancelFriendRequest,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.hourglass_top,
                  color: Colors.white, size: 18),
          label: const Text(
            'Đã gửi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B7280), // Xám
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FluentRadius.medium),
            ),
          ),
        );

      default:
        // ⭐ CHƯA KẾT BẠN → Nút XANH ĐẬM
        return ElevatedButton.icon(
          onPressed: _isProcessing ? null : _sendFriendRequest,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add,
                  color: Colors.white, size: 18),
          label: const Text(
            'Kết bạn',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: FluentColors.accentDark, // ⭐ Xanh đậm
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FluentRadius.medium),
            ),
          ),
        );
    }
  }

  Widget _buildStat(String label, int count, bool isDark, {String? type}) {
    final isClickable = type != null;
    return GestureDetector(
      onTap: isClickable ? () => _openFollowers(type) : null,
      behavior: HitTestBehavior.opaque,
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
    if (_posts.isEmpty) {
      return [
        SliverToBoxAdapter(
            child: _buildEmptyState('Chưa có bài viết', isDark)),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final post = _posts[i];
              final likes = (post['likes'] as List?) ?? [];
              final comments = (post['comments'] as List?) ?? [];
              return _buildPostCard(
                  post, likes.length, comments.length, isDark);
            },
            childCount: _posts.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildPostCard(Map<String, dynamic> post, int likeCount, int commentCount, bool isDark) {
    return SocialPostCard(key: ValueKey(post['id']), post: post, onChanged: _fetchAll);
  }

  List<Widget> _buildPhotosSliver(bool isDark) {
    if (_photos.isEmpty) {
      return [
        SliverToBoxAdapter(child: _buildEmptyState('Chưa có ảnh', isDark)),
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
            (context, i) => CachedNetworkImage(
              imageUrl: CloudinaryHelper.thumbnail(_photos[i]['image_url']),
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? FluentColors.darkCard : Colors.grey[200],
              ),
            ),
            childCount: _photos.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVideosSliver(bool isDark) {
    if (_videos.isEmpty) {
      return [
        SliverToBoxAdapter(
            child: _buildEmptyState('Chưa có video', isDark)),
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
              final video = _videos[i];
              final videoUrl = video['video_url'] as String? ?? '';
              final thumbUrl = CloudinaryHelper.videoThumbnail(videoUrl);

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => video['is_post_media'] == true ? MediaViewer(url: videoUrl, video: true) : VideoViewerScreen(videos: _videos.where((v) => v['is_post_media'] != true).toList(), initialIndex: i, userName: _profile?['username'], userAvatar: _profile?['avatar_url'], userId: _profile?['id']))),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: isDark
                            ? FluentColors.darkCard
                            : Colors.grey[200],
                        child: const Icon(Icons.videocam,
                            color: Colors.white54, size: 30),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 32),
                    ),
                  ],
                ),
              );
            },
            childCount: _videos.length,
          ),
        ),
      ),
    ];
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
            const SizedBox(height: 16),
            _buildInfoRow(Icons.home_outlined, 'Quê quán',
                _profile?['hometown'], isDark),
            _buildInfoRow(Icons.location_on_outlined, 'Nơi ở',
                _profile?['current_city'], isDark),
            _buildInfoRow(Icons.work_outline, 'Công việc',
                _profile?['work'], isDark),
            _buildInfoRow(Icons.school_outlined, 'Học vấn',
                _profile?['education'], isDark, isLast: true),
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
          Icon(Icons.inbox_outlined,
              size: 60,
              color: isDark
                  ? FluentColors.darkSubText
                  : FluentColors.lightSubText),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? FluentColors.darkSubText
                    : FluentColors.lightSubText,
              )),
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
  _TabHeaderDelegate({required this.child, required this.selectedIndex});

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
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}
