import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/post_media.dart';
import '../services/media_service.dart';
import '../utils/cloudinary_helper.dart';

class MediaGallery extends StatefulWidget {
  final List<PostMedia> items;
  final double height;
  const MediaGallery({super.key, required this.items, this.height = 300});
  @override State<MediaGallery> createState() => _MediaGalleryState();
}
class _MediaGalleryState extends State<MediaGallery> {
  int _index = 0;
  @override Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(height: widget.height, child: Stack(children: [
      PageView.builder(itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => MediaTile(key: ValueKey(widget.items[i].toJson().toString()), media: widget.items[i])),
      if (widget.items.length > 1) Positioned(right: 12, top: 12, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Text('${_index + 1}/${widget.items.length}', style: const TextStyle(color: Colors.white)))),
    ]));
  }
}

class MediaTile extends StatefulWidget {
  final PostMedia media;
  const MediaTile({super.key, required this.media});
  @override State<MediaTile> createState() => _MediaTileState();
}
class _MediaTileState extends State<MediaTile> {
  late Future<String> _url;
  @override void initState() { super.initState(); _url = MediaService.resolve(widget.media); }
  @override void didUpdateWidget(covariant MediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url || oldWidget.media.storagePath != widget.media.storagePath) {
      _url = MediaService.resolve(widget.media);
    }
  }
  @override Widget build(BuildContext context) => FutureBuilder<String>(future: _url, builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Center(child: TextButton.icon(
        onPressed: () => setState(() => _url = MediaService.resolve(widget.media)),
        icon: const Icon(Icons.refresh), label: const Text('Tải lại tệp')));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final url = snapshot.data!;
    final thumb = widget.media.isVideo ? CloudinaryHelper.videoThumbnail(url) : CloudinaryHelper.postImage(url);
    return InkWell(onTap: () async {
      try {
        final fresh = await MediaService.resolve(widget.media);
        if (!context.mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewer(url: fresh, video: widget.media.isVideo)));
      } catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được tệp. Hãy thử lại.'))); }
    }, child: Stack(fit: StackFit.expand, children: [
      if (!widget.media.isVideo || thumb != url) CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))
      else Container(color: Colors.black87),
      if (widget.media.isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 60)),
    ]));
  });
}

class MediaViewer extends StatefulWidget {
  final String url;
  final bool video;
  const MediaViewer({super.key, required this.url, this.video = false});
  @override State<MediaViewer> createState() => _MediaViewerState();
}
class _MediaViewerState extends State<MediaViewer> with WidgetsBindingObserver {
  VideoPlayerController? _player;
  String? _error;
  bool _ready = false;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); if (widget.video) _initVideo(); }
  Future<void> _initVideo() async {
    final player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _player = player;
    try {
      await player.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() => _ready = true);
      await player.play();
    } catch (_) { if (mounted) setState(() => _error = 'Không phát được video. Hãy mở lại để thử.'); }
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state != AppLifecycleState.resumed) _player?.pause(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _player?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
    body: Center(child: !widget.video ? InteractiveViewer(minScale: 1, maxScale: 5,
      child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Text('Không tải được ảnh', style: TextStyle(color: Colors.white))))
      : _error != null ? Text(_error!, style: const TextStyle(color: Colors.white))
      : !_ready ? const CircularProgressIndicator()
      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: AspectRatio(aspectRatio: _player!.value.aspectRatio, child: VideoPlayer(_player!))),
          VideoProgressIndicator(_player!, allowScrubbing: true, padding: const EdgeInsets.all(16)),
          ValueListenableBuilder<VideoPlayerValue>(valueListenable: _player!, builder: (_, value, __) => IconButton(
            color: Colors.white, iconSize: 42, onPressed: () => value.isPlaying ? _player!.pause() : _player!.play(),
            icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle))),
        ])));
}
