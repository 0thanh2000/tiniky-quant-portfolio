import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import 'user_profile_screen.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final String type; // 'followers' hoặc 'following'

  const FollowersScreen({
    super.key,
    required this.userId,
    required this.type,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      List<dynamic> response;

      if (widget.type == 'followers') {
        // Người đang follow user này
        response = await _supabase
            .from('follows')
            .select(
                'follower_id, profiles!follower_id(id, username, avatar_url, bio)')
            .eq('following_id', widget.userId);
      } else {
        // Người mà user này đang follow
        response = await _supabase
            .from('follows')
            .select(
                'following_id, profiles!following_id(id, username, avatar_url, bio)')
            .eq('follower_id', widget.userId);
      }

      final users = response.map<Map<String, dynamic>>((row) {
        return Map<String, dynamic>.from(row['profiles'] ?? {});
      }).toList();

      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải danh sách: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.type == 'followers' ? 'Người theo dõi' : 'Đang theo dõi';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? _buildEmpty(isDark, title)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  itemBuilder: (context, i) {
                    final user = _users[i];
                    return _buildUserTile(user, isDark);
                  },
                ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isDark) {
    final avatarUrl = user['avatar_url'];
    final username = user['username'] ?? 'Người dùng';
    final bio = user['bio'] ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          gradient: AppGradients.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: isDark ? AppColors.darkBg : Colors.white,
          backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.toString().isEmpty
              ? const Icon(Icons.person, color: AppColors.gradStart)
              : null,
        ),
      ),
      title: Text(
        username,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      subtitle: bio.toString().isNotEmpty
          ? Text(
              bio,
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
        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: user['id']),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(bool isDark, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có $title',
            style: TextStyle(
              fontSize: 16,
              color:
                  isDark ? AppColors.darkSubText : AppColors.lightSubText,
            ),
          ),
        ],
      ),
    );
  }
}