import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';
import 'friends_screen.dart';
class ProfileFriendsSection extends StatefulWidget {
  final String userId;
  const ProfileFriendsSection({super.key, required this.userId});
  @override State<ProfileFriendsSection> createState() => _ProfileFriendsSectionState();
}
class _ProfileFriendsSectionState extends State<ProfileFriendsSection> {
  List<Map<String, dynamic>>? _friends;
  String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client.rpc('app_profile_friends', params: {'profile_id': widget.userId});
      if (mounted) setState(() { _friends = List<Map<String, dynamic>>.from(rows as List); _error = null; });
    } catch (_) { if (mounted) setState(() => _error = 'Không tải được bạn bè. Kiểm tra kết nối và cấu hình Supabase.'); }
  }
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    Row(children: [Text('Bạn bè${_friends == null ? '' : ' (${_friends!.length})'}', style: Theme.of(context).textTheme.titleLarge), const Spacer(),
      if (widget.userId == Supabase.instance.client.auth.currentUser?.id) TextButton(onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())); _load();
      }, child: const Text('Lời mời'))]),
    if (_error != null) ...[Text(_error!), TextButton(onPressed: _load, child: const Text('Thử lại'))]
    else if (_friends == null) const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
    else if (_friends!.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Text('Chưa có bạn bè.'))
    else for (final f in _friends!) ListTile(leading: CircleAvatar(
      backgroundImage: (f['avatar_url']?.toString() ?? '').isEmpty ? null : NetworkImage(f['avatar_url']),
      child: (f['avatar_url']?.toString() ?? '').isEmpty ? const Icon(Icons.person_outline) : null),
      title: Text(f['username'] ?? 'Người dùng'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: f['id'].toString())))),
  ]));
}
