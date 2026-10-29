import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/cache_helper.dart';
import '../utils/video_cache_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Biến để force refresh FutureBuilder khi xóa cache
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        children: [
          // ===== DARK MODE TOGGLE =====
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final isDarkMode = mode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: AppColors.gradStart,
                ),
                title: const Text('Chế độ tối'),
                subtitle: Text(isDarkMode ? 'Đang bật' : 'Đang tắt'),
                value: isDarkMode,
                activeThumbColor: AppColors.gradStart,
                onChanged: (v) {
                  themeModeNotifier.value =
                      v ? ThemeMode.dark : ThemeMode.light;
                },
              );
            },
          ),
          const Divider(),

          // ===== DUNG LƯỢNG CACHE VIDEO =====
          FutureBuilder<String>(
            key: ValueKey(_refreshKey),
            future: VideoCacheManager.getCacheSizeFormatted(),
            builder: (context, snapshot) {
              return ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Dung lượng cache video'),
                subtitle: Text(snapshot.data ?? 'Đang tính...'),
                trailing: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Xóa cache video'),
                        content: const Text(
                            'Bạn có chắc muốn xóa toàn bộ video đã tải về?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Xóa',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    await VideoCacheManager.clearAll();
                    if (!mounted || !context.mounted) return;
                    setState(() => _refreshKey++);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa cache video'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Xóa'),
                ),
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Đổi mật khẩu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sẽ được làm sau')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Về ứng dụng'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Tiniky',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026',
              );
            },
          ),
          const Divider(),

          // ===== ĐĂNG XUẤT =====
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Đăng xuất',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                // 1. Logout OneSignal
                try {
                  await OneSignal.logout();
                } catch (_) {}

                // 2. XÓA CACHE JSON (posts/friends/notifications/profile)
                await CacheHelper.clearAll();

                // 3. XÓA FILE VIDEO ĐÃ TẢI OFFLINE
                await VideoCacheManager.clearAll();

                // 4. Đăng xuất Supabase
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
