import '../services/conversation_service.dart';
import 'chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../widgets/verified_badge.dart';
import '../utils/cache_helper.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late TabController _tabController;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingReceived = [];
  List<Map<String, dynamic>> _pendingSent = [];
  List<Map<String, dynamic>> _suggestions = [];

  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // KHỞI TẠO: CACHE TRƯỚC, NETWORK SAU
  // ============================================
  Future<void> _init() async {
    final cached = await CacheHelper.getFriends();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _friends = cached;
        _isLoading = false;
      });
    }
    _fetchAll();
  }

  // ============================================
  // TẢI DỮ LIỆU + CACHE
  // ============================================
  Future<void> _fetchAll() async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) return;

      final friends1 = await _supabase
          .from('friendships')
          .select(
              'friend_id, profiles!friend_id(id, username, avatar_url, bio, is_verified, verified_type)')
          .eq('user_id', me)
          .eq('status', 'accepted');

      final friends2 = await _supabase
          .from('friendships')
          .select(
              'user_id, profiles!user_id(id, username, avatar_url, bio, is_verified, verified_type)')
          .eq('friend_id', me)
          .eq('status', 'accepted');

      final friendsList = <Map<String, dynamic>>[];
      for (final f in friends1) {
        friendsList.add(Map<String, dynamic>.from(f['profiles'] ?? {}));
      }
      for (final f in friends2) {
        friendsList.add(Map<String, dynamic>.from(f['profiles'] ?? {}));
      }

      final received = await _supabase
          .from('friendships')
          .select(
              'id, user_id, profiles!user_id(id, username, avatar_url, bio, is_verified, verified_type)')
          .eq('friend_id', me)
          .eq('status', 'pending');

      final receivedList = received
          .map<Map<String, dynamic>>((r) => {
                'friendship_id': r['id'],
                ...Map<String, dynamic>.from(r['profiles'] ?? {}),
              })
          .toList();

      final sent = await _supabase
          .from('friendships')
          .select(
              'id, friend_id, profiles!friend_id(id, username, avatar_url, bio, is_verified, verified_type)')
          .eq('user_id', me)
          .eq('status', 'pending');

      final sentList = sent
          .map<Map<String, dynamic>>((r) => {
                'friendship_id': r['id'],
                ...Map<String, dynamic>.from(r['profiles'] ?? {}),
              })
          .toList();

      final allFriendships = await _supabase
          .from('friendships')
          .select('user_id, friend_id')
          .or('user_id.eq.$me,friend_id.eq.$me');

      final excludeIds = <String>{me};
      for (final f in allFriendships) {
        excludeIds.add(f['user_id']);
        excludeIds.add(f['friend_id']);
      }

      final suggestionsRes = await _supabase
          .from('profiles')
          .select(
              'id, username, avatar_url, bio, is_verified, verified_type')
          .not('id', 'in', '(${excludeIds.join(",")})')
          .limit(20);

      final suggestionsList =
          List<Map<String, dynamic>>.from(suggestionsRes);

      if (!mounted) return;
      setState(() {
        _friends = friendsList;
        _pendingReceived = receivedList;
        _pendingSent = sentList;
        _suggestions = suggestionsList;
        _isLoading = false;
        _isOffline = false;
      });

      await CacheHelper.saveFriends(friendsList);
    } catch (e) {
      debugPrint('❌ Lỗi tải friends: $e');
      if (_friends.isNotEmpty) {
        // Đã có cache → chỉ set offline
        if (mounted) setState(() => _isOffline = true);
      } else {
        await _loadFromCache();
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheHelper.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = cached;
        _isLoading = false;
        _isOffline = true;
      });
      debugPrint('📱 Đã load ${cached.length} bạn bè từ cache');
    } catch (e) {
      debugPrint('❌ Lỗi load cache friends: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> friendship) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'accepted'}).eq(
              'id', friendship['friendship_id']);
      _fetchAll();
    } catch (e) {
      debugPrint('Lỗi chấp nhận: $e');
    }
  }

  Future<void> _declineRequest(Map<String, dynamic> friendship) async {
    try {
      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendship['friendship_id']);
      _fetchAll();
    } catch (e) {
      debugPrint('Lỗi từ chối: $e');
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    try {
      await _supabase.rpc('app_request_friend', params: {'other_user': user['id']});
      _fetchAll();
    } catch (e) {
      debugPrint('Lỗi gửi lời mời: $e');
    }
  }

  Future<void> _cancelRequest(Map<String, dynamic> friendship) async {
    try {
      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendship['friendship_id']);
      _fetchAll();
    } catch (e) {
      debugPrint('Lỗi hủy lời mời: $e');
    }
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bạn bè',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gradStart,
          labelColor: AppColors.gradStart,
          unselectedLabelColor:
              isDark ? AppColors.darkSubText : AppColors.lightSubText,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Bạn bè (${_friends.length})'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lời mời'),
                  if (_pendingReceived.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingReceived.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Gợi ý'),
          ],
        ),
      ),
      body: _isLoading && _friends.isEmpty
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(isDark),
                _buildRequestsTab(isDark),
                _buildSuggestionsTab(isDark),
              ],
            ),
    );
  }

  Widget _buildFriendsTab(bool isDark) {
    if (_friends.isEmpty) {
      return _buildEmpty(
          isDark,
          _isOffline ? Icons.cloud_off : Icons.people_outline,
          _isOffline ? 'Không có bạn bè trong bộ nhớ đệm' : 'Chưa có bạn bè',
          _isOffline
              ? 'Kết nối mạng để tải danh sách'
              : 'Hãy kết bạn để bắt đầu!');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _friends.length,
      itemBuilder: (context, i) =>
          _buildUserTile(_friends[i], isDark, actionType: 'friend', onAdd: () => _chat(_friends[i])),
    );
  }

  Widget _buildRequestsTab(bool isDark) {
    if (_pendingReceived.isEmpty && _pendingSent.isEmpty) {
      return _buildEmpty(isDark, Icons.mail_outline, 'Không có lời mời nào',
          'Các lời mời kết bạn sẽ hiện ở đây');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_pendingReceived.isNotEmpty) ...[
          _buildSectionHeader('Lời mời kết bạn', isDark),
          ..._pendingReceived.map(
            (f) => _buildUserTile(
              f,
              isDark,
              actionType: 'received',
              onAccept: () => _acceptRequest(f),
              onDecline: () => _declineRequest(f),
            ),
          ),
        ],
        if (_pendingSent.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('Lời mời đã gửi', isDark),
          ..._pendingSent.map(
            (f) => _buildUserTile(
              f,
              isDark,
              actionType: 'sent',
              onCancel: () => _cancelRequest(f),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionsTab(bool isDark) {
    if (_suggestions.isEmpty) {
      return _buildEmpty(isDark, Icons.person_search_outlined,
          'Không có gợi ý', 'Hiện chưa có gợi ý kết bạn');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) => _buildUserTile(
        _suggestions[i],
        isDark,
        actionType: 'suggestion',
        onAdd: () => _sendRequest(_suggestions[i]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
        ),
      ),
    );
  }

  Widget _buildUserTile(
    Map<String, dynamic> user,
    bool isDark, {
    required String actionType,
    VoidCallback? onAccept,
    VoidCallback? onDecline,
    VoidCallback? onAdd,
    VoidCallback? onCancel,
  }) {
    final avatarUrl = user['avatar_url'];
    final username = user['username'] ?? 'Người dùng';
    final bio = user['bio'] ?? '';
    final isVerified = user['is_verified'] == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () => _openProfile(user['id']),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            gradient: AppGradients.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? AppColors.darkBg : Colors.white,
            backgroundImage:
                avatarUrl != null && avatarUrl.toString().isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
            child: avatarUrl == null || avatarUrl.toString().isEmpty
                ? const Icon(Icons.person, color: AppColors.gradStart)
                : null,
          ),
        ),
      ),
      title: GestureDetector(
        onTap: () => _openProfile(user['id']),
        child: Row(
          children: [
            Flexible(
              child: Text(
                username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? AppColors.darkText : AppColors.lightText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified)
              VerifiedBadge(
                size: 15,
                verifiedType: user['verified_type'],
              ),
          ],
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
      trailing: _buildActionButtons(
        actionType: actionType,
        onAccept: onAccept,
        onDecline: onDecline,
        onAdd: onAdd,
        onCancel: onCancel,
      ),
    );
  }

  Widget _buildActionButtons({
    required String actionType,
    VoidCallback? onAccept,
    VoidCallback? onDecline,
    VoidCallback? onAdd,
    VoidCallback? onCancel,
  }) {
    switch (actionType) {
      case 'friend':
        return IconButton(
          icon: const Icon(Icons.chat_bubble_outline,
              color: AppColors.gradStart),
          onPressed: onAdd,
        );

      case 'received':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gradStart,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Chấp nhận',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Xóa', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        );

      case 'sent':
        return SizedBox(
          height: 34,
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hủy', style: TextStyle(fontSize: 12)),
          ),
        );

      case 'suggestion':
        return SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add,
                size: 14, color: Colors.white),
            label: const Text(
              'Kết bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gradStart,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        );
    }
    return const SizedBox.shrink();
  }

  Future<void> _chat(Map<String, dynamic> user) async {
    try {
      final id = await ConversationService.open(user['id'].toString());
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        conversationId: id, otherUserName: user['username'] ?? 'Người dùng', otherUserId: user['id'].toString(),
        otherUserVerified: user['is_verified'] == true, otherUserVerifiedType: user['verified_type'])));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được tin nhắn: $e'))); }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    ).then((_) => _fetchAll());
  }

  Widget _buildEmpty(
      bool isDark, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color:
                  isDark ? AppColors.darkSubText : AppColors.lightSubText,
            ),
          ),
        ],
      ),
    );
  }
}
