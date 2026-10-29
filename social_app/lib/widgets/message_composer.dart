import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_service.dart';

class MessageComposer extends StatefulWidget {
  final String hint;
  final Future<void> Function(String text, XFile? file, bool video) onSend;
  const MessageComposer({super.key, required this.onSend, this.hint = 'Nhắn tin...'});
  @override State<MessageComposer> createState() => _MessageComposerState();
}
class _MessageComposerState extends State<MessageComposer> {
  final _text = TextEditingController();
  XFile? _file;
  bool _video = false;
  bool _busy = false;
  @override void dispose() { _text.dispose(); super.dispose(); }
  Future<void> _pick(bool video) async {
    if (_busy) return;
    try {
      final file = video ? await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60))
        : await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048);
      if (file == null) return;
      await MediaService.validate(file, video: video);
      if (mounted) setState(() { _file = file; _video = video; });
    } catch (e) { _error(e); }
  }
  void _error(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  Future<void> _send() async {
    if (_busy || (_text.text.trim().isEmpty && _file == null)) return;
    setState(() => _busy = true);
    try {
      await widget.onSend(_text.text.trim(), _file, _video);
      if (mounted) setState(() { _text.clear(); _file = null; });
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => SafeArea(top: false, child: Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_busy) const LinearProgressIndicator(),
      if (_file != null) Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 64,
          child: _video ? const Icon(Icons.video_file, size: 36) : Image.file(File(_file!.path), fit: BoxFit.cover, cacheWidth: 160))),
        const SizedBox(width: 10), Expanded(child: Text(_video ? 'Video ngắn đã chọn' : 'Ảnh đã chọn')),
        IconButton(onPressed: _busy ? null : () => setState(() => _file = null), icon: const Icon(Icons.close)),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        PopupMenuButton<bool>(enabled: !_busy, tooltip: 'Gửi ảnh hoặc video', icon: const Icon(Icons.add_circle_outline),
          onSelected: _pick, itemBuilder: (_) => const [
            PopupMenuItem(value: false, child: ListTile(leading: Icon(Icons.image_outlined), title: Text('Ảnh'))),
            PopupMenuItem(value: true, child: ListTile(leading: Icon(Icons.videocam_outlined), title: Text('Video tối đa 60 giây'))),
          ]),
        Expanded(child: TextField(controller: _text, enabled: !_busy, minLines: 1, maxLines: 5, maxLength: 4000,
          textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: widget.hint,
            counterText: '', filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
        const SizedBox(width: 6), IconButton.filled(onPressed: _busy ? null : _send, tooltip: 'Gửi', icon: const Icon(Icons.send_rounded)),
      ]),
    ]))));
}
