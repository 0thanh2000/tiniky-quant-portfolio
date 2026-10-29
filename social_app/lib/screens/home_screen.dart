import '../widgets/post_body.dart';
import '../services/share_service.dart';
import 'post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../theme.dart';
import '../main.dart';
import '../utils/cache_helper.dart';
import '../utils/cloudinary_helper.dart';
import '../widgets/verified_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  int _postLimit = 30;
  bool _hasMore = true;
  bool _fetching = false;
  bool _fetchAgain = false;
  bool _isOffline = false;
  RealtimeChannel? _postsChannel;
  Set<String> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _linkOneSignalToUser();
    _subscribeToPosts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _postsChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchPosts();
      _postsChannel?.unsubscribe();
      _subscribeToPosts();
    }
  }

  Future<void> _init() async {
    final cached = await CacheHelper.getPosts();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _posts = cached;
        _isLoading = false;
      });
    }
    _fetchPosts();
  }

  Future<void> _linkOneSignalToUser() async {
    try {
      final me = supabase.auth.currentUser?.id;
      if (me != null) OneSignal.login(me);
    } catch (e) {
      debugPrint('Lỗi OneSignal: $e');
    }
  }

  void _subscribeToPosts() {
    _postsChannel = supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (_) => _fetchPosts(),
        )
        .subscribe();
  }

  Future<void> _fetchPosts() async {
    if (_fetching) { _fetchAgain = true; return; }
    _fetching = true;
    try {
      final me = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('posts')
          .select(
              '*, profiles!user_id(username, avatar_url, is_verified, verified_type), likes(user_id), comments(id)')
          .order('created_at', ascending: false).order('id', ascending: false).limit(_postLimit);

      final bookmarks = await supabase
          .from('bookmarks')
          .select('post_id')
          .eq('user_id', me);

      if (!mounted) return;
      final postsList = List<Map<String, dynamic>>.from(response);
      setState(() {
        _posts = postsList;
        _hasMore = postsList.length == _postLimit;
        _bookmarkedIds = (bookmarks as List)
            .map<String>((b) => b['post_id'] as String)
            .toSet();
        _isLoading = false;
        _isOffline = false;
      });


      }
    } finally {
      _fetching = false;
      if (_fetchAgain && mounted) { _fetchAgain = false; _fetchPosts(); }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final cachedPosts = await CacheHelper.getPosts();
      if (!mounted) return;
      setState(() {
        _posts = cachedPosts;
        _isLoading = false;
        _isOffline = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  // ============================================
  // ⭐ HANDLE LIKE — GỬI ĐÚNG PARAMS
  // ============================================
  Future<void> _handleLike(
      Map<String, dynamic> post, bool isLiked, String me) async {
    try {
      if (isLiked) {
        await supabase
            .from('likes')
            .delete()
            .match({'user_id': me, 'post_id': post['id']});
      } else {
        await supabase
            .from('likes')
            .insert({'user_id': me, 'post_id': post['id']});

        // ⭐ GỬI THÔNG BÁO với đầy đủ params
        final postOwnerId = post['user_id'];
        if (postOwnerId != null && postOwnerId != me) {
          final myProfile = await supabase
              .from('profiles')
              .select('username')
              .eq('id', me)
              .single();

          supabase.functions.invoke('notify-like', body: {
            'post_owner_id': postOwnerId,
            'liker_id': me,                              // ⭐ THÊM
            'liker_name': myProfile['username'] ?? 'Ai đó',
            'post_id': post['id'],                       // ⭐ THÊM
          }).then((_) {}, onError: (e) {
            debugPrint('Lỗi notify: $e');
          });
        }
      }
      _fetchPosts();
    } catch (e) {
      debugPrint('Lỗi like: $e');
    }
  }

  Future<void> _toggleBookmark(String postId) async {
    final me = supabase.auth.currentUser!.id;
    final isBookmarked = _bookmarkedIds.contains(postId);

    try {
      if (isBookmarked) {
        await supabase
            .from('bookmarks')
            .delete()
            .match({'user_id': me, 'post_id': postId});
        if (!mounted) return;
        setState(() => _bookmarkedIds.remove(postId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã bỏ lưu bài viết')),
  
      debugPrint('Lỗi bookmark: $e');
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> post) async {
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
          if (postsIndex >= 0 && postsIndex + 2 < pathSegments.length) {
            final storagePath =
                pathSegments.sublist(postsIndex + 1).join('/');
            await supabase.storage.from('posts').remove([storagePath]);
          }
        } catch (e) {
          debugPrint('Không xóa được ảnh storage: $e');
        }
      }

      await supabase.from('posts').delete().eq('id', post['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa bài viết'),
          backgroundColor: Colors.orange,
        ),
      );
      _fetchPosts();
    } catch (e) {
      debugPrint('Lỗi xóa bài: $e');
    }
  }

  Future<void> _handleEdit(Map<String, dynamic> post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
    );
    if (result == true) _fetchPosts();
  }

  void _toggleTheme() {
    themeModeNotifier.value = themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final d = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút';
    if (diff.inDays < 1) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return '${d.day}/${d.month}';
  }

  void _openUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  Future<void> _openCreateVideo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == true) _fetchPosts();
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openChatList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  @override

            // TOP BAR
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isDark ? FluentColors.darkBg : FluentColors.lightBg,
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppGradients.primaryGradient.createShader(bounds),
                    child: const Text(
                      'Tiniky',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (_isOffline) ...[
                    const SizedBox(width: 8),
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
                          Icon(FluentIcons.cloud_off_16_regular,
                              color: Colors.white, size: 12),
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
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isDark
                          ? FluentIcons.weather_sunny_24_regular
                          : FluentIcons.weather_moon_24_regular,
                      color: FluentColors.accent,
                    ),
                    onPressed: _toggleTheme,
                  ),
                  IconButton(
                    icon: const Icon(
                      FluentIcons.chat_24_regular,
                      color: FluentColors.accent,
                    ),
                    onPressed: _openChatList,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _openCreateVideo,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: FluentColors.accent.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(FluentIcons.add_24_filled,
                          color: Colors.white, size: 26),
   
            ),

            // SEARCH BAR
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GestureDetector(
                onTap: _openSearch,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FluentColors.darkCard
                        : FluentColors.lightCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? FluentColors.darkBorder
                          : FluentColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.search_20_regular,
                        color: isDark
                            ? FluentColors.darkSubText
                            : FluentColors.lightSubText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tìm kiếm trên Tiniky...',
                        style: TextStyle(
                          color: isDark
                              ? FluentColors.darkSubText
                              : FluentColors.lightSubText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // POSTS
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPosts,
                color: FluentColors.accent,
                child: _posts.isNotEmpty
                    ? ListView.builder(
                        itemCount: _posts.length + 1 + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildPostBox(me, isDark);

                          if (index == _posts.length + 1) return TextButton(onPressed: () { _postLimit += 30; _fetchPosts(); }, child: const Text('Xem thêm bài viết'));
                          final post = _posts[index - 1];
                          final profile = post['profiles'] ?? {};

                              _bookmarkedIds.contains(post['id']);

                          return _PostCard(
                            key: ValueKey(post['id']),
                            post: post,
                            profile: profile,
                            likes: likes,
                            comments: comments,
                            isLiked: isLiked,
                            isDark: isDark,
                            isMyPost: isMyPost,
                            isBookmarked: isBookmarked,
                            timeAgo: _timeAgo(post['created_at']),
                            onLike: () => _handleLike(post, isLiked, me),
                            onComment: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) =>
                                    CommentsSheet(postId: post['id']),
                              ).then((_) => _fetchPosts());
                            },
                            onTapProfile: () => _openUserProfile(
                                post['user_id'].toString()),
                            onEdit: () => _handleEdit(post),
                            onDelete: () => _handleDelete(post),
                            onBookmark: () =>
                                _toggleBookmark(post['id']),
                          );
                        },
                      )
                    : _isLoading
                        ? const SizedBox.shrink()
                        : _buildEmptyState(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostBox(String me, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FluentColors.darkCard : FluentColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(

        ],
      ),
      child: Row(
        children: [
          _buildMyAvatar(me, isDark, 22),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreatePostScreen()),
                ).then((_) => _fetchPosts());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? FluentColors.darkBg
                      : FluentColors.lightBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Bạn đang nghĩ gì?',
                  style: TextStyle(
                    color: isDark
                        ? FluentColors.darkSubText
                        : FluentColors.lightSubText,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreatePostScreen()),
              ).then((_) => _fetchPosts());
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: AppGradients.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(FluentIcons.camera_20_filled,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAvatar(String me, bool isDark, double radius) {
    final myPost = _posts.firstWhere(
      (p) => p['user_id'] == me,


    return CircleAvatar(
      radius: radius,
      backgroundColor: FluentColors.accent,
      backgroundImage: avatarUrl != null
          ? NetworkImage(CloudinaryHelper.avatarMedium(avatarUrl))
          : null,
      child: avatarUrl == null
          ? const Icon(FluentIcons.person_24_filled, color: Colors.white)
          : null,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: AppGradients.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(FluentIcons.image_24_regular,
                    size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                _isOffline
                    ? 'Không có bài viết trong bộ nhớ đệm'
                    : 'Chưa có bài viết nào',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? FluentColors.darkText
                      : FluentColors.lightText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isOffline
                    ? 'Kết nối mạng để tải bài viết mới'
                    : 'Hãy là người đầu tiên chia sẻ!',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? FluentColors.darkSubText
                      : FluentColors.lightSubText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================
// POST CARD
// ============================================
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic> profile;
  final List likes;
  final List comments;
  final bool isLiked;
  final bool isDark;
  final bool isMyPost;
  final bool isBookmarked;
  final String timeAgo;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onTapProfile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBookmark;

  const _PostCard({
    super.key,
    required this.post,
    required this.profile,
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.isDark,
    required this.isMyPost,
    required this.isBookmarked,
    required this.timeAgo,
    required this.onLike,
    required this.onComment,
    required this.onTapProfile,
    required this.onEdit,
    required this.onDelete,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? FluentColors.darkCard : FluentColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
 
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onTapProfile,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(

                      radius: 20,
                      backgroundColor: Colors.white,
                      backgroundImage: profile['avatar_url'] != null
                          ? NetworkImage(
                              CloudinaryHelper.avatarMedium(
                                  profile['avatar_url']))
                          : null,
                      child: profile['avatar_url'] == null
                          ? const Icon(FluentIcons.person_24_filled,
                              color: FluentColors.accent, size: 20)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onTapProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile['username'] ?? 'Người dùng',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark
                                      ? FluentColors.darkText
                                      : FluentColors.lightText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile['is_verified'] == true)
                              VerifiedBadge(
                                size: 16,
                                verifiedType: profile['verified_type'],
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? FluentColors.darkSubText
                                    : FluentColors.lightSubText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              FluentIcons.globe_16_regular,
                              size: 12,
                              color: isDark
                                  ? FluentColors.darkSubText
                                  : FluentColors.lightSubText,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked
                        ? FluentIcons.bookmark_24_filled
                        : FluentIcons.bookmark_24_regular,
                    color: isBookmarked
                        ? FluentColors.accent
                        : (isDark
                            ? FluentColors.darkSubText
                            : FluentColors.lightSubText),
                    size: 22,
                  ),
                  onPressed: onBookmark,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                if (isMyPost)
                  PopupMenuButton<String>(
                    icon: Icon(
                      FluentIcons.more_horizontal_24_regular,
                      color: isDark
                          ? FluentColors.darkSubText
                          : FluentColors.lightSubText,
                    ),
                    color: isDark ? FluentColors.darkCard : Colors.white,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(FluentIcons.edit_20_regular,
                                size: 20,
                                color: isDark
                                    ? FluentColors.darkText
                                    : FluentColors.lightText),
                            const SizedBox(width: 10),
                            Text(
                              'Chỉnh sửa',
                              style: TextStyle(
                                color: isDark
                                    ? FluentColors.darkText
                                    : FluentColors.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(FluentIcons.delete_20_regular,
                                size: 20, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Xóa bài viết',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Icon(FluentIcons.more_horizontal_24_regular,
                      color: isDark
                          ? FluentColors.darkSubText
                          : FluentColors.lightSubText),
              ],
            ),
          ),

          PostBody(post: post, onOpen: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post['id'].toString())))),

          const SizedBox(height: 10),

          if (likes.isNotEmpty || comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (likes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        gradient: AppGradients.pinkGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(FluentIcons.heart_12_filled,
                          color: Colors.white, size: 11),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${likes.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? FluentColors.darkText
                            : FluentColors.lightText,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (comments.isNotEmpty)
                    Text(
                      '${comments.length} bình luận',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? FluentColors.darkSubText
                            : FluentColors.lightSubText,
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark
                ? FluentColors.darkBorder
                : FluentColors.lightBorder,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _AnimatedLikeButton(
                    isLiked: isLiked,
                    isDark: isDark,
                    onTap: onLike,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: FluentIcons.comment_20_regular,
                    label: 'Bình luận',
                    color: isDark
                        ? FluentColors.darkSubText
                        : FluentColors.lightSubText,
                    onTap: onComment,
                  ),
                ),
                Expanded(child: _ActionButton(icon: Icons.share_outlined, label: 'Chia sẻ',
                  color: isDark ? FluentColors.darkSubText : FluentColors.lightSubText,
                  onTap: () => ShareService.post(context, post))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedLikeButton({
    required this.isLiked,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isLiked) {
      _controller.forward().then((_) => _controller.reverse());
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: widget.isLiked
                    ? _scaleAnim
                    : const AlwaysStoppedAnimation(1.0),
                child: Icon(
                  widget.isLiked
                      ? FluentIcons.heart_20_filled
                      : FluentIcons.heart_20_regular,
                  size: 20,
                  color: widget.isLiked
                      ? FluentColors.likeRed
                      : (widget.isDark
                          ? FluentColors.darkSubText
                          : FluentColors.lightSubText),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.isLiked ? 'Đã thích' : 'Thích',
                style: TextStyle(
                  color: widget.isLiked
                      ? FluentColors.likeRed
                      : (widget.isDark
                          ? FluentColors.darkSubText
                          : FluentColors.lightSubText),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
