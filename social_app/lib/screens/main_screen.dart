import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'feed_screen.dart';
import 'home_screen.dart';
import 'friends_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _refreshKey = 0;
  int _unreadCount = 0;
  RealtimeChannel? _notifChannel;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUnreadCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final session = _supabase.auth.currentSession;
      if (session == null) return;
      setState(() => _refreshKey++);
      _fetchUnreadCount();
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) return;
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', me)
          .eq('is_read', false);

      if (!mounted) return;
      setState(() => _unreadCount = (response as List).length);
    } catch (e) {
      debugPrint('Lỗi đếm thông báo: $e');
    }
  }

  void _subscribeToNotifications() {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;
    _notifChannel = _supabase
        .channel('notifications:user:$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (_) => _fetchUnreadCount(),
        )
        .subscribe();
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
    if (index == 3) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _fetchUnreadCount();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ⭐ MÀU CHỮ ĐẬM — Giống Facebook
    const activeColor = FluentColors.accent;
    final inactiveColor = isDark
        ? const Color(0xFFE5E5E5) // Trắng sáng (dark mode)
        : const Color(0xFF1A1A1A); // Đen đậm (light mode)

    return Scaffold(
      body: IndexedStack(
        key: ValueKey(_refreshKey),
        index: _currentIndex,
        children: [
          FeedScreen(isActive: _currentIndex == 0),
          const HomeScreen(),
          const FriendsScreen(),
          const NotificationsScreen(),
          ProfileScreen(isActive: _currentIndex == 4),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          c
                  ? FluentColors.darkMica
                  : FluentColors.lightMica,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? FluentColors.darkBorder
                      : FluentColors.lightBorder,
                  width: 0.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    _buildTab(0, Icons.play_circle_outline,
                        Icons.play_circle_filled, 'Feed', activeColor, inactiveColor),
                    _buildTab(1, Icons.article_outlined, Icons.article,
                        'Bảng tin', activeColor, inactiveColor),
                    _buildTab(2, Icons.people_outline, Icons.people,
                        'Bạn bè', activeColor, inactiveColor),
                    _buildNotifTab(activeColor, inactiveColor),
                    _buildTab(4, Icons.person_outline, Icons.person,
                        'Cá nhân', activeColor, inactiveColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ⭐ TAB THƯỜNG
  Widget _buildTab(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    Color activeColor,
    Color inactiveColor,
  ) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabChanged(index),
          borderRadius: BorderRadius.circular(12),
          splashColor: activeColor.withValues(alpha: 0.1),
          highlightColor: activeColor.withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 12 : 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                  letterSpacing: 0.1,
                  height: 1.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ TAB THÔNG BÁO (có badge)
  Widget _buildNotifTab(Color activeColor, Color inactiveColor) {
    final isActive = _currentIndex == 3;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabChanged(3),
          borderRadius: BorderRadius.circular(12),
          splashColor: activeColor.withValues(alpha: 0.1),
          highlightColor: activeColor.withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 12 : 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive
                          ? Icons.notifications
                          : Icons.notifications_outlined,
                      size: 24,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: FluentColors.likeRed,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            _unreadCount > 99 ? '99+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                  letterSpacing: 0.1,
                  height: 1.2,
                ),
                child: const Text('Thông báo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
