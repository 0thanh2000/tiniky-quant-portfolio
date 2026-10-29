import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_media.dart';
import '../services/media_service.dart';
import '../widgets/media_gallery.dart';
  const CreatePostScreen({super.key, this.post});
  @override State<CreatePostScreen> createState() => _CreatePostScreenState();
}
class _DraftMedia {
  final XFile file;
  final bool video;
  PostMedia? uploaded;
  _DraftMedia(this.file, this.video);
}
class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _content;
  final _selected = <_DraftMedia>[];
  late final List<PostMedia> _existing;
  bool _busy = false;
  String _status = '';
  @override void initState() {
    super.initState();
    _content = TextEditingController(text: widget.post?['content']?.toString() ?? '');
    _existing = widget.post == null ? [] : PostMedia.fromPost(widget.post!);
  }
  @override void dispose() { _content.dispose(); super.dispose(); }
  void _error(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  Future<void> _pick(bool video) async {
    if (_busy) return;
    try {
      final slots = MediaService.maxImages - _existing.length - _selected.length;
      if (slots <= 0) throw Exception('Mỗi bài tối đa 10 ảnh/video.');
      final picker = ImagePicker();
      final files = <XFile>[];
      if (video) {
        final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
        if (file != null) files.add(file);
      } else { files.addAll(await picker.pickMultiImage(imageQuality: 85, maxWidth: 2048)); }
      if (files.length > slots) throw Exception('Bạn chỉ có thể thêm $slots tệp nữa.');
      for (final f in files) { await MediaService.validate(f, video: video); }
      if (mounted) setState(() => _selected.addAll(files.map((f) => _DraftMedia(f, video))));
    } catch (e) { _error(e); }
  }
  Future<void> _save() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) { _error('Bạn cần đăng nhập lại.'); return; }ảnh/video.'); return; }
    setState(() { _busy = true; _status = 'Đang chuẩn bị...'; });
    try {
      final media = List<PostMedia>.from(_existing);
      for (var i = 0; i < _selected.length; i++) {
        if (mounted) setState(() => _status = 'Đang tải tệp ${i + 1}/${_selected.length}...');
        final item = _selected[i];
        item.uploaded ??= await MediaService.uploadPublic(item.file, video: item.video);
        media.add(item.uploaded!);
      }
      final images = media.where((m) => !m.isVideo);
      final videos = media.where((m) => m.isVideo);
      final values = {'content': content, 'media': media.map((m) => m.toJson()).toList(),
        'image_url': images.isEmpty ? null : images.first.url,
        'video_url': videos.isEmpty ? null : videos.first.url};
      if (widget.post == null) {
        await db.from('posts').insert({...values, 'user_id': user.id});
      } else {
        await db.from('posts').update(values).eq('id', widget.post!['id']).eq('user_id', user.id).select('id').single();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(appBar: AppBar(title: Text(widget.post == null ? 'Tạo bài viết' : 'Chỉnh sửa bài viết'), actions: [
      TextButton(onPressed: _busy ? null : _save, child: Text(widget.post == null ? 'ĐĂNG' : 'LƯU')),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Row(children: [Icon(Icons.public, size: 16), SizedBox(width: 6), Text('Công khai')]),
      const SizedBox(height: 12),
      TextField(controller: _content, enabled: !_busy, minLines: 4, maxLines: 12, maxLength: 10000,
        decoration: const InputDecoration(hintText: 'Bạn đang nghĩ gì?', border: InputBorder.none)),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < _existing.length; i++) _preview(
          MediaTile(media: _existing[i]), () => setState(() => _existing.removeAt(i))),
        for (var i = 0; i < _selected.length; i++) _preview(
          _selected[i].video ? const Center(child: Icon(Icons.videocam, size: 42))
            : Image.file(File(_selected[i].file.path), fit: BoxFit.cover, cacheWidth: 320),
          () => setState(() => _selected.removeAt(i))),
      ]),
      const SizedBox(height: 20),
      Wrap(spacing: 10, children: [
        OutlinedButton.icon(onPressed: _busy ? null : () => _pick(false), icon: const Icon(Icons.photo_library_outlined), label: const Text('Thêm ảnh')),
        OutlinedButton.icon(onPressed: _busy ? null : () => _pick(true), icon: const Icon(Icons.video_library_outlined), label: const Text('Thêm video')),
      ]),
      const Text('Tối đa 10 tệp • Ảnh 10 MB • Video 60 giây, 50 MB', style: TextStyle(fontSize: 12)),
      if (_busy) ...[const SizedBox(height: 16), const LinearProgressIndicator(), const SizedBox(height: 8), Text(_status)],
    ])));
  Widget _preview(Widget child, VoidCallback remove) => SizedBox(width: 140, height: 140, child: Stack(fit: StackFit.expand, children: [
    ClipRRect(borderRadius: BorderRadius.circular(14), child: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: child)),
    Positioned(top: 0, right: 0, child: IconButton.filled(onPressed: _busy ? null : remove, icon: const Icon(Icons.close, size: 18))),
  ]));
}
