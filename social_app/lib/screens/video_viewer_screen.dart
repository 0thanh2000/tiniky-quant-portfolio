import 'comments_sheet.dart';
import '../services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../widgets/verified_badge.dart';
import 'user_profile_screen.dart';

class VideoViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  final String? userName;
  final String? userAvatar;
  final String? userId;

  const VideoViewerScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.userName,
    this.userAvatar,
    this.userId,
  });

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;


  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              return _VideoViewerItem(
                video: widget.videos[i],
                isActive: i == _currentIndex,
                userName: widget.userName,
                userAvatar: widget.userAvatar,
                userId: widget.userId,
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// WIDGET VIDEO ITEM
// ============================================
class _VideoViewerItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final String? userName;
  final String? userAvatar;
  final String? userId;

  const _VideoViewerItem({
    required this.video,
    required this.isActive,
    this.userName,
    this.userAvatar,
    this.userId,
  });

  @override
  State<_VideoViewerItem> createState() => _VideoViewerItemState();
}

class _VideoViewerItemState extends State<_VideoViewerItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _fetchLikeData();
  }

  Future<void> _initVideo() async {
    try {
      final url = widget.video['video_url'];
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      _controller!.setLooping(true);

      if (!mounted) return;
      setState(() => _isInitialized = true);

      if (widget.isActive) {
        _controller!.play();
      }
    } catch (e) {
      debugPrint('Lỗi load video: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _VideoViewerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  Future<void> _fetchLikeData() async {
    try {
      final me = _supabase.auth.currentUser!.id;
      final videoId = widget.video['id'];

      final likes = await _supabase
          .from('video_likes')
          .select('user_id')
          .eq('video_id', videoId);

      final comments = await _supabase
          .from('video_comments')
          .select('id')
          .eq('video_id', videoId);

      if (!mounted) return;
      setState(() {
        _likeCount = (likes as List).length;
        _commentCount = (comments as List).length;
        _isLiked = (likes).any((l) => l['user_id'] == me);
      });
    } catch (e) {
      debugPrint('Lỗi fetch: $e');
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
        if (!mounted) return;
        setState(() {
          _isLiked = false;
          _likeCount = (_likeCount - 1).clamp(0, 999999);
        });
      } else {
        await _supabase
            .from('video_likes')
            .insert({'user_id': me, 'video_id': videoId});
        if (!mounted) return;
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
      }
    } catch (e) {
      debugPrint('Lỗi like: $e');
    }
  }

  void _openProfile() {
    if (widget.userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: widget.userId!),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.video['caption'] ?? '';
    final musicName = widget.video['music_name'] ?? 'Nhạc nền';
    final profile = widget.video['profiles'] ?? {};
    final isVerified = profile['is_verified'] == true;
    final verifiedType = profile['verified_type'];

    return GestureDetector(
      onTap: () {
        if (_controller != null && _isInitialized) {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
          setState(() {});
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Icon pause
          if (_isInitialized &&
              _controller != null &&
              !_controller!.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white54,
                size: 80,
              ),
            ),

          // Gradient
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black54,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // Info trái dưới
          Positioned(
            left: 16,
            right: 90,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _openProfile,
                  child: Row(
                    children: [
                      // USERNAME + TÍCH XANH
                      Flexible(
                        child: Text(
                          '@${widget.userName ?? 'user'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified)
                        VerifiedBadge(
                          size: 16,
                          verifiedType: verifiedType,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (caption.toString().isNotEmpty)
                  Text(
                    caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.music_note,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        musicName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nút phải
          Positioned(
            right: 12,
            bottom: 30,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _openProfile,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey,
                      backgroundImage: widget.userAvatar != null &&
                              widget.userAvatar!.isNotEmpty
                          ? NetworkImage(widget.userAvatar!)
                          : null,
                      child: widget.userAvatar == null ||
                              widget.userAvatar!.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 24)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _ActionIcon(
                  icon: _isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                  label: _formatCount(_likeCount),
                  onTap: _handleLike,
                ),
                const SizedBox(height: 18),

                _ActionIcon(
                  icon: Icons.mode_comment_outlined,
                  color: Colors.white,
                  label: _formatCount(_commentCount),
                  onTap: () async {
                    await _controller?.pause();
                    if (!mounted || !context.mounted) return;
                    await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                      builder: (_) => CommentsSheet(postId: widget.video['id'].toString(), isVideo: true));
                    if (mounted) { _fetchLikeData(); if (widget.isActive) _controller?.play(); }
                  },
                ),
                const SizedBox(height: 18),

                _ActionIcon(
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: 'Chia sẻ',
                  onTap: () => ShareService.video(context, widget.video['id'].toString()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
