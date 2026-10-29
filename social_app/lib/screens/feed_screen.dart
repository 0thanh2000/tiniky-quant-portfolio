import '../services/share_service.dart';
import 'comments_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../theme.dart';
import '../utils/cache_helper.dart';
import '../utils/video_cache_manager.dart';
import '../utils/connectivity_helper.dart';
import '../utils/cloudinary_helper.dart';
import '../widgets/verified_badge.dart';
import 'create_video_screen.dart';
import 'user_profile_screen.dart';

// ============================================
// ⭐ VIDEO PRELOADER — TỐI ƯU CAO
// ============================================
class VideoPreloader {
  static final Map<String, VideoPlayerController> _cache = {};
  static final List<String> _order = [];
  
  // ⭐ TĂNG: 12 controller trong RAM (thay vì 5)
  static const int _maxSize = 12;
  
  static final Set<AudioPlayer> _activeAudioPlayers = {};

  static bool _isAlive(VideoPlayerController? c) {
    if (c == null) return false;
    try {
      return c.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static bool has(String url) {
    final c = _cache[url];
    if (c == null) return false;
    if (!_isAlive(c)) {
      _cache.remove(url);
      _order.remove(url);
      return false;
    }
    return true;
  }

  static VideoPlayerController? get(String url) {
    if (!has(url)) return null;
    _order.remove(url);
    _order.add(url);
    return _cache[url];
  }

  static bool isAlive(VideoPlayerController? c) => _isAlive(c);

  static void registerAudio(AudioPlayer player) {
    _activeAudioPlayers.add(player);
  }

  static void unregisterAudio(AudioPlayer player) {
    _activeAudioPlayers.remove(player);
  }

  static Future<void> pauseAllAudio() async {
    for (final p in _activeAudioPlayers.toList()) {
      try {
        await p.pause();
      } catch (_) {}
    }
  }

  /// ⭐ Load controller — ưu tiên file cache
  static Future<VideoPlayerController?> load(String url) async {
    if (has(url)) return get(url);

    _cache.remove(url);
    _order.remove(url);

    final optimizedUrl = CloudinaryHelper.video(url, width: 720);

    try {
      final cachedFile = await VideoCacheManager.getCachedFile(url);

      VideoPlayerController controller;

      if (cachedFile != null) {
        debugPrint('📁 Phát từ cache: ${cachedFile.path.split('/').last}');
        controller = VideoPlayerController.file(cachedFile);
        await controller.initialize();
      } else {
        debugPrint('🌐 Phát từ network: ${optimizedUrl.substring(0, 50)}...');
        controller =
            VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
        await controller.initialize();

        // ⭐ Tải file về disk chạy nền
        VideoCacheManager.downloadAndCache(url).then((file) {
          if (file != null) {
            debugPrint('✅ Video sẵn sàng xem offline');
          }
        });
      }

      controller.setLooping(true);
      _cache[url] = controller;
      _order.add(url);

      // ⭐ LRU cleanup — giữ 12 controller
      while (_order.length > _maxSize) {
        final oldest = _order.removeAt(0);
        if (oldest == url) {
          _order.insert(0, oldest);
          break;
        }
        try {
          await _cache[oldest]?.pause();
          await _cache[oldest]?.dispose();
        } catch (e) {
          debugPrint('Lỗi dispose: $e');
        }
        _cache.remove(oldest);
      }

      return controller;
    } catch (e) {
      debugPrint('❌ Lỗi load video: $e');
      return null;
    }
  }

  /// ⭐ Chỉ tải file về disk (không tạo controller — tiết kiệm RAM)
  static Future<void> prefetchFile(String url) async {
    try {
      // Nếu đã có file → bỏ qua
      final exists = await VideoCacheManager.hasCachedFile(url);
      if (exists) return;

      // Nếu đã có controller → bỏ qua
      if (has(url)) return;

      debugPrint('📥 Prefetch file: ${url.substring(0, 50)}...');
      await VideoCacheManager.downloadAndCache(url);
    } catch (e) {
      debugPrint('Lỗi prefetch: $e');
    }
  }

  static Future<void> pauseAll() async {
    for (var c in _cache.values) {
      try {
        if (_isAlive(c) && c.value.isPlaying) await c.pause();
      } catch (_) {}
    }
    await pauseAllAudio();
  }

  static Future<void> clearControllers() async {
    for (var c in _cache.values) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    _cache.clear();
    _order.clear();
    _activeAudioPlayers.clear();
  }

  static Future<void> clearAll() async {
    await clearControllers();
    await VideoCacheManager.clearAll();
  }
}

// ============================================
// FEED SCREEN
// ============================================
class FeedScreen extends StatefulWidget {
  final bool isActive;
  const FeedScreen({super.key, required this.isActive});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _isOffline = false;
  int _currentIndex = 0;

  // ⭐ Debounce preload — tránh preload liên tục khi user đang scroll
  Timer? _preloadDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    _preloadDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      VideoPreloader.pauseAll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchVideos();
    } else if (state == AppLifecycleState.paused) {
      VideoPreloader.pauseAll();
    }
  }

  Future<void> _init() async {
    final cached = await CacheHelper.getVideos();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _videos = cached;
        _isLoading = false;
      });
      _preloadAround(0);
    }
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      final response = await _supabase
          .from('videos')
          .select(
              '*, profiles!user_id(username, avatar_url, is_verified, verified_type)')
          .order('created_at', ascending: false);

      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(response);
      setState(() {
        _videos = list;
        _isLoading = false;
        _isOffline = false;
      });

      await CacheHelper.saveVideos(list);
      if (list.isNotEmpty) _preloadAround(0);
    } catch (e) {
      debugPrint('❌ Lỗi tải videos: $e');
      if (_videos.isEmpty) {
        await _loadVideosFromCache();
      } else {
        if (mounted) setState(() => _isOffline = true);
      }
    }
  }

  Future<void> _loadVideosFromCache() async {
    try {
      final cached = await CacheHelper.getVideos();
      if (!mounted) return;
      setState(() {
        _videos = cached;
        _isLoading = false;
        _isOffline = true;
      });
      if (cached.isNotEmpty) _preloadAround(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  // ============================================
  // ⭐ PRELOAD TỐI ƯU — 5 KẾ + 10 DISK + 3 TRƯỚC
  // ============================================
  void _preloadAround(int currentIndex) {
    // ⭐ Debounce 500ms — chờ user dừng scroll mới preload
    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(const Duration(milliseconds: 500), () {
      _doPreload(currentIndex);
    });
  }

  void _doPreload(int currentIndex) {
    if (_videos.isEmpty) return;

    // ⭐ Preload 5 video KẾ TIẾP — tạo controller (RAM)
    for (int i = currentIndex + 1; i <= currentIndex + 5; i++) {
      if (i < _videos.length) {
        final url = _videos[i]['video_url'] as String?;
        if (url != null && !VideoPreloader.has(url)) {
          VideoPreloader.load(url);
        }
      }
    }

    // ⭐ Prefetch 5 video SAU NỮA — chỉ tải file (không tạo controller)
    // Để khi user vuốt nhanh tới vẫn có file sẵn
    for (int i = currentIndex + 6; i <= currentIndex + 10; i++) {
      if (i < _videos.length) {
        final url = _videos[i]['video_url'] as String?;
        if (url != null) {
          VideoPreloader.prefetchFile(url);
        }
      }
    }

    // ⭐ Preload 3 video TRƯỚC — phòng user vuốt ngược
    for (int i = currentIndex - 1; i >= currentIndex - 3 && i >= 0; i--) {
      final url = _videos[i]['video_url'] as String?;
      if (url != null && !VideoPreloader.has(url)) {
        VideoPreloader.load(url);
      }
    }

    debugPrint(
        '✅ Preload quanh #$currentIndex: +5 (RAM), +10 (disk), -3 (RAM)');
  }

  Future<void> _openCreateVideo() async {
    _preloadDebounce?.cancel();
    await VideoPreloader.pauseAll();
    await VideoPreloader.pauseAllAudio();

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateVideoScreen()),
    );

    if (!mounted) return;

    if (result == true) {
      await VideoPreloader.clearControllers();
      _fetchVideos();
    } else {
      await _resumeCurrentVideo();
    }
  }

  Future<void> _resumeCurrentVideo() async {

    try {
      final c = VideoPreloader.get(url);
      if (c != null && VideoPreloader.isAlive(c)) {
        await c.play();
      }
    } catch (e) {
      debugPrint('Lỗi resume video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_videos.isNotEmpty)
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _preloadAround(index);
              },
              itemBuilder: (context, index) {
                return _VideoItem(
                  key: ValueKey(_videos[index]['id']),
                  video: _videos[index],
                  isActive: widget.isActive && index == _currentIndex,
                );
              },
            ),

          if (_videos.isEmpty && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOffline
                          ? FluentIcons.cloud_off_24_regular
                          : FluentIcons.video_off_24_regular,
                      color: Colors.white54,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isOffline
                          ? 'Không có video nào trong bộ nhớ đệm'
                          : 'Chưa có video nào.\nHãy đăng video đầu tiên!',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // APPBAR + NÚT VIDEO TRÒN XANH
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Dành cho bạn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Đã follow',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 15),
                            ),
                          ],
                        ),
                        if (_isOffline) ...[
                          const SizedBox(height: 4),
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
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _openCreateVideo,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: FluentColors.accent.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: FluentColors.accent.withValues(alpha: 0.25),
                            blurRadius: 28,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        FluentIcons.add_24_filled,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

  final bool isActive;

  const _VideoItem({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  VideoPlayerController? _controller;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isOffline = false;
  bool _isDisposed = false;
  final _supabase = Supabase.instance.client;

  double get _originalVolume {
    return (widget.video['original_volume'] as num?)?.toDouble() ?? 0.3;
  }

  double get _musicVolume {
    return (widget.video['music_volume'] as num?)?.toDouble() ?? 1.0;
  }

    _initMusic();
    _fetchLikeData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _safePause();
    try {
      if (_audioPlayer != null) {
        VideoPreloader.unregisterAudio(_audioPlayer!);
        _audioPlayer!.dispose();
      }
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initMusic() async {
    final musicUrl = widget.video['music_url']?.toString();
    if (musicUrl == null || musicUrl.isEmpty) return;

    try {
      final player = AudioPlayer();
      await player.setUrl(musicUrl);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_musicVolume);

      if (!mounted || _isDisposed) {
        player.dispose();
        return;
      }
      _audioPlayer = player;
      VideoPreloader.registerAudio(player);

      if (widget.isActive) {
        try {
          player.play();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Lỗi load music: $e');
    }
  }

  void _safePlay() {
    if (_isDisposed || !mounted) return;
    final c = _controller;
    if (c == null || !VideoPreloader.isAlive(c)) return;
    try {
      c.play();
    
      try {
        c.pause();
      } catch (_) {}
    }
    try {
      _audioPlayer?.pause();
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    try {
      final url = widget.video['video_url'] as String?;
      if (url == null || _isDisposed) return;

      if (VideoPreloader.has(url)) {
        final c = VideoPreloader.get(url);
        if (!mounted || _isDisposed) return;

        if (VideoPreloader.isAlive(c)) {
          _controller = c;
          try {
            await c!.setVolume(_originalVolume);
          } catch (_) {}
          if (!mounted || _isDisposed) return;
          setState(() => _isInitialized = true);
          if (widget.isActive) _safePlay();
          return;
        }
        _controller = null;
      }

      final loaded = await VideoPreloader.load(url);
      if (!mounted || _isDisposed) return;

      if (!VideoPreloader.isAlive(loaded)) {
        final hasNet = await ConnectivityHelper.hasConnection();
        if (!mounted || _isDisposed) return;
        setState(() {
          _isInitialized = false;
          _isOffline = !hasNet;
        });
        return;
      }

      _controller = loaded;
      try {
        await _controller!.setVolume(_originalVolume);

      });
      if (widget.isActive) _safePlay();
    } catch (e) {
      debugPrint('Lỗi init video: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isInitialized = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDisposed) return;
    if (widget.isActive && !oldWidget.isActive) {
      _safePlay();
    } else if (!widget.isActive && oldWidget.isActive) {
      _safePause();
    }
  }

  Future<void> _fetchLikeData() async {
    try {
      final me = _supabase.auth.currentUser!.id;
      final videoId = widget.video['id'];

      final likesResponse = await _supabase
          .from('video_likes')
          .select('user_id')
          .eq('video_id', videoId);

      final commentsResponse = await _supabase
          .from('video_comments')
          .select('id')
          .eq('video_id', videoId);

      final likesList = likesResponse as List;
      final commentsList = commentsResponse as List;

      if (!mounted || _isDisposed) return;
      setState(() {
        _likeCount = likesList.length;
        _commentCount = commentsList.length;
        _isLiked = likesList.any((l) => l['user_id'] == me);
      });
    } catch (e) {
      debugPrint('Lỗi fetch like: $e');
    }
  }

  Future<void> _handleLike() async {
    final me = _supabase.auth.currentUser!.id;
    final videoId = widget.video['id'];

    try {
      if (_isLiked) {
        await _supabase
            .from('video_likes')
            .delete()
            .match({'user_id': me, 'video_id': videoId});
        if (!mounted || _isDisposed) return;
        setState(() {
          _isLiked = false;
          _likeCount = (_likeCount - 1).clamp(0, 999999);
        });
      } else {
        await _supabase
            .from('video_likes')
            .insert({'user_id': me, 'video_id': videoId});
        if (!mounted || _isDisposed) return;
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
      }
    } catch (e) {
      debugPrint('Lỗi like: $e');
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: widget.video['id'].toString(), isVideo: true),
    ).then((_) => _fetchLikeData());
  }

  void _openUserProfile() {
    final userId = widget.video['user_id'];
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId.toString()),
      ),
    );
  }

  Color _parseOverlayColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.white;
    try {
      final cleaned = hex.replaceFirst('0x', '');
      return Color(int.parse(cleaned, radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.video['profiles'] ?? {};
    final caption = widget.video['caption'] ?? '';
    final musicName = widget.video['music_name'] ?? 'Nhạc nền';
    final overlayText = widget.video['overlay_text']?.toString() ?? '';
    final overlayColor =
        _parseOverlayColor(widget.video['overlay_color']?.toString());
    final overlayFontSize =
        (widget.video['overlay_font_size'] as num?)?.toDouble() ?? 24.0;

    final canShowVideo = _isInitialized &&
        _controller != null &&
        VideoPreloader.isAlive(_controller);

    return GestureDetector(
      onTap: () {
        if (!canShowVideo) return;
        try {
          if (_controller!.value.isPlaying) {
            _safePause();
          } else {
            _safePlay();
          }
          if (mounted) setState(() {});
        } catch (_) {}
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (canShowVideo)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_isOffline)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.cloud_off_24_regular,
                      color: Colors.white54, size: 60),
                  SizedBox(height: 12),
                  Text('Video chưa được lưu offline',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ],
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          if (overlayText.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      overlayText,
                      style: TextStyle(
                        color: overlayColor,
                        fontSize: overlayFontSize,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(blurRadius: 10, color: Colors.black87),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

          if (canShowVideo && !_controller!.value.isPlaying)
            const Center(
              child: Icon(FluentIcons.play_48_filled,
                  color: Colors.white54, size: 80),
            ),

          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black26,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black54,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.15, 0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 90,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: _openUserProfile,
                        child: Text(
                          '@${profile['username'] ?? 'user'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black87),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (profile['is_verified'] == true)
                      VerifiedBadge(
                        size: 17,
                        verifiedType: profile['verified_type'],
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (caption.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.35,
                        shadows: [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.music_note_2_16_regular,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          musicName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 12,
            bottom: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _openUserProfile,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFCDE89A), Color(0xFF059669)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey,
                        backgroundImage: profile['avatar_url'] != null
                            ? NetworkImage(
                                CloudinaryHelper.avatarMedium(
                                    profile['avatar_url']))
                            : null,
                        child: profile['avatar_url'] == null
                            ? const Icon(FluentIcons.person_24_filled,
                                color: Colors.white, size: 24)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _ActionIconWithAnimation(
                  icon: _isLiked
                      ? FluentIcons.heart_28_filled
                      : FluentIcons.heart_28_regular,
                  color: _isLiked ? Colors.red : Colors.white,
                  label: _formatCount(_likeCount),
                  isActive: _isLiked,
                  onTap: _handleLike,
                ),
                const SizedBox(height: 20),
                _ActionIcon(
                  icon: FluentIcons.comment_28_regular,
                  color: Colors.white,
                  label: _formatCount(_commentCount),
                  onTap: _openComments,
                ),
                const SizedBox(height: 20),
                _ActionIcon(
                  icon: FluentIcons.share_28_regular,
                  color: Colors.white,
                  label: 'Chia sẻ',
                  onTap: () => ShareService.video(context, widget.video['id'].toString()),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.grey, Colors.black],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(FluentIcons.music_note_2_20_filled,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Icon(icon,
                color: color,
                size: 36,
                shadows: const [
                  Shadow(blurRadius: 6, color: Colors.black54),
                ]),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black54),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionIconWithAnimation extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionIconWithAnimation({
    required this.icon,
    required this.color,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ActionIconWithAnimation> createState() =>
      _ActionIconWithAnimationState();
}

class _ActionIconWithAnimationState extends State<_ActionIconWithAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isActive) {
      _animController.forward().then((_) => _animController.reverse());
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            ScaleTransition(
              scale: widget.isActive
                  ? _scaleAnim
                  : const AlwaysStoppedAnimation(1.0),
              child: Icon(widget.icon,
                  color: widget.color,
                  size: 36,
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black54),
                  ]),
            ),
            const SizedBox(height: 4),
            Text(widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black54),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SHEET COMMENT
// ============================================
