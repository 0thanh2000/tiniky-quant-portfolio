import 'services/app_links_service.dart';
import 'screens/session_shell.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/notifications_screen.dart';
import 'theme.dart';

// ============================================
// CẤU HÌNH
// ============================================
const supabaseUrl = 'https://pezfnmvomhjvsjgrlper.supabase.co';
const supabasePublishableKey = 'sb_publishable_4HYLcxn5PBE-gBs3unHQUQ_z3sDlmLB';
const oneSignalAppId = '6888b726-2b50-4958-9f29-56b32a2a9ba3';

// ⭐ Navigator key — để navigate từ OneSignal callback
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ⭐ Global ValueNotifier cho theme
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.light);

// ⭐ Key lưu theme
const String _themePrefKey = 'theme_mode';

// ============================================
// MAIN
// ============================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ LOAD THEME từ SharedPreferences
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);
    if (savedTheme == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    }
    debugPrint('🎨 Loaded theme: ${themeModeNotifier.value}');

    // ⭐ LẮNG NGHE THAY ĐỔI THEME → lưu vào prefs
    themeModeNotifier.addListener(() {
      final mode = themeModeNotifier.value;
      final value = mode == ThemeMode.dark ? 'dark' : 'light';
      prefs.setString(_themePrefKey, value);
      debugPrint('🎨 Saved theme: $value');
    });
  } catch (e) {
    debugPrint('⚠️ Theme load error: $e');
  }

  // ⭐ AUDIO SESSION — cho phép video + nhạc cùng chạy
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType:
          AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
    debugPrint('✅ AudioSession configured');
  } catch (e) {

    event.notification.display();
  });
}

// ⭐ Helper navigate qua GlobalKey
void _navigateToNotifications() {
  // Đợi 500ms cho app khởi động xong
  Future.delayed(const Duration(milliseconds: 500), () {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('   ⚠️ Navigator context chưa sẵn sàng');
      return;
    }

    // Kiểm tra đã đăng nhập chưa
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('   ⚠️ Chưa đăng nhập');
      return;
    }

    // Điều hướng tới NotificationsScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  });
}

// ============================================
// ROOT WIDGET
// ============================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Tiniky',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          navigatorKey: navigatorKey, // ⭐ QUAN TRỌNG
          home: StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: FluentColors.accent,
                    ),
                  ),
                );
              }

              final session =
                  snapshot.hasData ? snapshot.data!.session : null;

              if (session != null) {
                return SessionShell(key: ValueKey(session.user.id), child: const MainScreen());
              } else {
                return const LoginScreen();
              }
            },
          ),
        );
      },
    );
  }
}
