import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/conversation_service.dart';
import 'chat_screen.dart';
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override State<ChatListScreen> createState() => _ChatListScreenState();
}
class _ChatListScreenState extends State<ChatListScreen> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _chats = [], _people = [];
  bool _loading = true, _opening = false;
  String? _error;
  Timer? _debounce;
  int _queryVersion = 0;
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _debounce?.cancel(); _search.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final rows = await _db.rpc('app_conversation_list');
      if (mounted) setState(() { _chats = List<Map<String, dynamic>>.from(rows as List); _error = null; });
    } catch (_) { if (mounted) setState(() => _error = 'Không tải được hội thoại. Kiểm tra cấu hình Supabase.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  void _searchPeople(String value) {
    _debounce?.cancel(); final version = ++_queryVersion;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final q = value.trim().replaceAll('%', '').replaceAll('_', '');
        if (q.isEmpty) { if (mounted) setState(() => _people = []); return; }
        final rows = await _db.from('profiles').select('id, username, avatar_url, is_verified, verified_type')
          .neq('id', _db.auth.currentUser!.id).ilike('username', '%$q%').limit(40);
        if (mounted && version == _queryVersion) setState(() => _people = List<Map<String, dynamic>>.from(rows));
      } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm được người dùng.'))); }
    });
    setState(() {});
  }
  Future<void> _open(Map<String, dynamic> user, {String? conversationId}) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final id = conversationId ?? await ConversationService.open(user['id'].toString());
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id,
        otherUserId: user['id'].toString(), otherUserName: user['username'] ?? 'Người dùng',
        otherUserVerified: user['is_verified'] == true, otherUserVerifiedType: user['verified_type'])));
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được hội thoại: $e'))); }
    finally { if (mounted) setState(() => _opening = false); }
  }
  @override Widget build(BuildContext context) {
    final searching = _search.text.trim().isNotEmpty;
    final rows = searching ? _people : _chats;
    return Scaffold(appBar: AppBar(title: const Text('Tin nhắn')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: TextField(controller: _search, onChanged: _searchPeople,
          decoration: InputDecoration(hintText: 'Tìm người để nhắn tin...', prefixIcon: const Icon(Icons.search), filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
        if (_opening) const LinearProgressIndicator(),
        if (_error != null) TextButton(onPressed: _load, child: Text('$_error Thử lại')),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load,
          child: rows.isEmpty ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
            const SizedBox(height: 100), Icon(Icons.chat_bubble_outline, size: 60, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16), Center(child: Text(searching ? 'Không tìm thấy người dùng' : 'Tìm tên bạn bè để bắt đầu trò chuyện')),
          ]) : ListView.separated(physics: const AlwaysScrollableScrollPhysics(), itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4), itemBuilder: (context, i) {
              final row = rows[i]; final user = searching ? row : Map<String, dynamic>.from(row['profile'] as Map);
              return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(radius: 26, backgroundImage: user['avatar_url'] == null ? null : NetworkImage(user['avatar_url']),
                  child: user['avatar_url'] == null ? const Icon(Icons.person_outline) : null),
                title: Text(user['username'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(searching ? 'Bắt đầu trò chuyện' : row['preview']?.toString() ?? 'Chưa có tin nhắn', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right), onTap: _opening ? null : () => _open(user, conversationId: searching ? null : row['id'].toString()));
            }))),
      ]));
  }
}
