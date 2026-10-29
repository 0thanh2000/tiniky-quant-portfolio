import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../widgets/verified_badge.dart';
import '../utils/cache_helper.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ============================================
  // KHỞI TẠO: CACHE TRƯỚC, NETWORK SAU
  // ============================================
  Future<void> _init() async {
    final cached = await CacheHelper.getNotifications();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _notifications = cached;
        _isLoading = false;
      });
    }
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) return;

      final response = await _supabase
          .from('notifications')
          .select('''
            *,
            actor:actor_id (id, username, avatar_url, is_verified, verified_type)
          ''')
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(response);
      setState(() {
        _notifications = list;
        _isLoading = false;
        _isOffline = false;
      });

      await CacheHelper.saveNotifications(list);
    } catch (e) {
      debugPrint('❌ Lỗi tải thông báo: $e');
      if (_notifications.isNotEmpty) {
        if (mounted) setState(() => _isOffline = true);
      } else {
        await _loadFromCache();
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheHelper.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = cached;
        _isLoading = false;
        _isOffline = true;
      });
      debugPrint('📱 Đã load ${cached.length} thông báo từ cache');
    } catch (e) {
      debugPrint('❌ Lỗi load cache notifications: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _markAsRead(String notifId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notifId);

      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == notifId);
        if (idx >= 0) _notifications[idx]['is_read'] = true;
      });

      await CacheHelper.saveNotifications(_notifications);
    } catch (e) {
      debugPrint('Lỗi đánh dấu đã đọc: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final me = _supabase.auth.currentUser!.id;
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', me)
          .eq('is_read', false);

      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });

      await CacheHelper.saveNotifications(_notifications);
    } catch (e) {
      debugPrint('Lỗi đánh dấu tất cả: $e');
    }
  }

  Future<void> _handleTap(Map<String, dynamic> notif) async {
    if (notif['is_read'] == false) {
      await _markAsRead(notif['id']);
    }

    final actor = notif['actor'];
    final actorId = actor != null ? actor['id'] : null;

    if (!mounted) return;

    if (actorId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: actorId),
        ),
      );
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final d = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount =
        _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.primaryGradient.createShader(bounds),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thông báo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all,
                  color: AppColors.gradStart, size: 18),
              label: const Text(
                'Đọc hết',
                style: TextStyle(
                    color: AppColors.gradStart,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _notifications.isNotEmpty
          ? RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
                itemBuilder: (context, i) =>
                    _buildNotifItem(_notifications[i], isDark),
              ),
            )
          : _isLoading
              ? const SizedBox.shrink()
              : _buildEmpty(isDark),
    );
  }

  Widget _buildNotifItem(Map<String, dynamic> notif, bool isDark) {
    final actor = notif['actor'] ?? {};
    final avatarUrl = actor['avatar_url'];
    final username = actor['username'] ?? 'Ai đó';
    final isVerified = actor['is_verified'] == true;
    final isRead = notif['is_read'] == true;

    return InkWell(
      onTap: () => _handleTap(notif),
      child: Container(
        color: isRead
            ? (isDark ? AppColors.darkBg : AppColors.lightBg)
            : (isDark
                ? AppColors.gradStart.withValues(alpha: 0.1)
                : AppColors.gradStart.withValues(alpha: 0.05)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: AppGradients.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        isDark ? AppColors.darkBg : Colors.white,
                    backgroundImage: avatarUrl != null &&
                            avatarUrl.toString().isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null ||
                            avatarUrl.toString().isEmpty
                        ? const Icon(Icons.person,
                            color: AppColors.gradStart)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getNotifColor(notif['type']),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBg
                            : AppColors.lightBg,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _getNotifIcon(notif['type']),
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: username,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' ${_getNotifText(notif)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _timeAgo(notif['created_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.gradStart,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            if ((notif['type'] == 'like_post' ||
                    notif['type'] == 'comment_post') &&
                notif['target_id'] != null)
              _buildThumbnail(notif['target_id'], isDark),

            if (isVerified)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: VerifiedBadge(
                  size: 16,
                  verifiedType: actor['verified_type'],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String postId, bool isDark) {
    return FutureBuilder(
      future: _supabase
          .from('posts')
          .select('image_url')
          .eq('id', postId)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final url = snapshot.data!['image_url'];
        if (url == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'like_post':
      case 'like_video':
        return Icons.favorite;
      case 'comment_post':
      case 'comment_video':
        return Icons.mode_comment;
      case 'follow':
        return Icons.person_add;
      case 'friend_request':
        return Icons.group_add;
      case 'friend_accept':
        return Icons.check;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'like_post':
      case 'like_video':
        return AppColors.likeRed;
      case 'comment_post':
      case 'comment_video':
        return Colors.blue;
      case 'follow':
        return AppColors.gradStart;
      case 'friend_request':
        return Colors.orange;
      case 'friend_accept':
        return Colors.green;
      default:
        return AppColors.gradStart;
    }
  }

  String _getNotifText(Map<String, dynamic> notif) {
    final type = notif['type'];
    final content = notif['content'] ?? '';

    switch (type) {
      case 'like_post':
        return 'đã thích bài viết của bạn';
      case 'comment_post':
        return 'đã bình luận: "$content"';
      case 'like_video':
        return 'đã thích video của bạn';
      case 'comment_video':
        return 'đã bình luận video: "$content"';
      case 'follow':
        return 'đã theo dõi bạn';
      case 'friend_request':
        return 'đã gửi lời mời kết bạn';
      case 'friend_accept':
        return 'đã chấp nhận lời mời kết bạn';
      default:
        return 'đã tương tác với bạn';
    }
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isOffline ? Icons.cloud_off : Icons.notifications_none,
            size: 80,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
          const SizedBox(height: 12),
          Text(
            _isOffline
                ? 'Không có thông báo trong bộ nhớ đệm'
                : 'Chưa có thông báo nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isOffline
                ? 'Kết nối mạng để tải thông báo mới'
                : 'Các tương tác với bạn sẽ hiện ở đây',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
            ),
          ),
        ],
      ),
    );
  }
}