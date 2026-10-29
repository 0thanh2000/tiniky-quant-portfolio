import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoTestScreen extends StatefulWidget {
  const VideoTestScreen({super.key});
  @override
  State<VideoTestScreen> createState() => _VideoTestScreenState();
}

class _VideoTestScreenState extends State<VideoTestScreen> {
  VideoPlayerController? _controller;
  String _status = 'Đang khởi tạo...';
  int _currentUrlIndex = 0;

  // Thử lần lượt nhiều URL
  final List<String> _urls = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://www.w3schools.com/html/mov_bbb.mp4',
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _tryLoadVideo(_currentUrlIndex);
  }

  Future<void> _tryLoadVideo(int index) async {
    if (index >= _urls.length) {
      setState(() => _status = 'Tất cả URL đều thất bại!');
      return;
    }

    setState(() {
      _status = 'Đang thử URL ${index + 1}/${_urls.length}...';
      _currentUrlIndex = index;
    });

    try {
      // Dispose controller cũ
      await _controller?.dispose();

      final url = _urls[index];
      debugPrint('=== [URL ${index + 1}] Đang load: $url');

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      debugPrint('=== [URL ${index + 1}] THÀNH CÔNG!');
      debugPrint('=== Duration: ${controller.value.duration}');

      controller.setLooping(true);
      controller.play();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _status = 'THÀNH CÔNG! Đang phát video...';
      });
    } catch (e) {
      debugPrint('=== [URL ${index + 1}] THẤT BẠI: $e');
      if (!mounted) return;
      setState(() => _status = 'URL ${index + 1} lỗi: $e\n\nĐang thử URL tiếp...');
      // Đợi 1 giây rồi thử URL tiếp theo
      await Future.delayed(const Duration(seconds: 1));
      _tryLoadVideo(index + 1);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 20),
                      Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'URL đang thử:\n${_urls[_currentUrlIndex]}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            // Nút thoát
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}