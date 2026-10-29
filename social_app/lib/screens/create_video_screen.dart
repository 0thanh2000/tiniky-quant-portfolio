import '../services/media_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_compress/video_compress.dart';
import 'package:audio_session/audio_session.dart';
import 'feed_screen.dart'; // ⭐ Để truy cập VideoPreloader


class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});
  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  final _supabase = Supabase.instance.client;

  // VIDEO
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  double _fileSizeMB = 0;
  double _originalAspectRatio = 16 / 9;

  // NHẠC
  final _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _selectedMusic;
  List<Map<String, dynamic>> _musicList = [];
  bool _isLoadingMusic = true;

  // ÂM LƯỢNG
  double _originalVolume = 1.0; // Preview: 100% khi chưa có nhạc
  double _musicVolume = 1.0;

  // Volume LƯU VÀO DB
  final double _uploadOriginalVolume = 0.3; // Khi đăng: âm gốc 30%
  final double _uploadMusicVolume = 1.0;    // Khi đăng: nhạc 100%

  // TEXT OVERLAY
  String _overlayText = '';
  final double _overlayFontSize = 24;
  Color _overlayColor = Colors.white;
  final TextEditingController _textController = TextEditingController();

  // UPLOAD
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';

  int _currentStep = 0;

  // FIX AUDIO FOCUS
  bool _shouldVideoPlay = true;
  DateTime? _lastResumeAttempt;

  @override
  void initState() {
    super.initState();
    _pauseExternalMedia(); // ⭐ Pause media Feed trước
    _fetchMusic();
    _configureAudioSession();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ⭐ Pause tất cả media đang chạy ở Feed
  Future<void> _pauseExternalMedia() async {
    try {
      await VideoPreloader.pauseAll();
      await VideoPreloader.pauseAllAudio();
      debugPrint('✅ Đã pause external media');
    } catch (e) {
      debugPrint('Lỗi pause external: $e');
    }
  }

  // ============================================
  // CẤU HÌNH AUDIO SESSION
  // ============================================
  Future<void> _configureAudioSession() async {
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
      debugPrint('⚠️ AudioSession error: $e');
    }
  }

  // ============================================
  // LẤY NHẠC
  // ============================================
  Future<void> _fetchMusic() async {
    try {
      final response = await _supabase
          .from('music')
          .select()
          .order('title', ascending: true);

      final valid = <Map<String, dynamic>>[];
      for (final m in response) {
        final url = m['audio_url']?.toString() ?? '';
        if (url.isNotEmpty) {
          valid.add(Map<String, dynamic>.from(m));
        }
      }

      if (!mounted) return;
      setState(() {
        _musicList = valid;
        _isLoadingMusic = false;
      });
    } catch (e) {
      debugPrint('Lỗi tải nhạc: $e');
      if (!mounted) return;
      setState(() => _isLoadingMusic = false);
    }
  }

  Future<void> _recordWithCamera() async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked != null) {
        await _loadVideo(File(picked.path));
      }
    } catch (e) {
      _showError('Không thể quay: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (picked != null) {
        await _loadVideo(File(picked.path));
      }
    } catch (e) {
      _showError('Không thể chọn: $e');
    }
  }

  // ============================================
  // LOAD VIDEO
  // ============================================
  Future<void> _loadVideo(File file) async {
    await _videoController?.dispose();
    await _audioPlayer.stop();

    final controller = VideoPlayerController.file(file);
    await controller.initialize();

    final ratio = controller.value.aspectRatio;
    controller.setLooping(true);
    controller.setVolume(_originalVolume);

    final size = await file.length();
    final sizeMB = size / 1024 / 1024;

    if (!mounted) return;
    setState(() {
      _videoFile = file;
      _videoController = controller;
      _isVideoReady = true;
      _currentStep = 1;
      _fileSizeMB = sizeMB;
      _originalAspectRatio = ratio > 0 ? ratio : 16 / 9;
      _shouldVideoPlay = true;
      _originalVolume = 1.0;
    });

    controller.addListener(() {
      if (!mounted) return;
      final v = _videoController;
      if (v == null || !v.value.isInitialized) return;

      if (_shouldVideoPlay && !v.value.isPlaying) {
        final now = DateTime.now();
        if (_lastResumeAttempt == null ||
            now.difference(_lastResumeAttempt!).inMilliseconds > 500) {
          _lastResumeAttempt = now;
          debugPrint('🔄 Auto-resume video');
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted &&
                _shouldVideoPlay &&
                _videoController != null &&
                !_videoController!.value.isPlaying) {
              try {
                _videoController!.play();
              } catch (_) {}
            }
          });
        }
      }
    });

    controller.play();
    debugPrint('=== Video: ${sizeMB.toStringAsFixed(2)} MB, ratio ${ratio.toStringAsFixed(2)}');
  }

  // ============================================
  // SYNC PLAY/PAUSE
  // ============================================
  Future<void> _syncPlay() async {
    _shouldVideoPlay = true;
    if (_videoController == null || !_isVideoReady) return;

    try {
      await _videoController!.play();
    } catch (_) {}

    if (_selectedMusic != null) {
      try {
        await _audioPlayer.play();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted &&
          _shouldVideoPlay &&
          _videoController != null &&
          !_videoController!.value.isPlaying) {
        debugPrint('🔄 Force resume video');
        try {
          await _videoController!.play();
        } catch (_) {}
      }
    }

    if (mounted) setState(() {});
  }

  void _syncPause() {
    _shouldVideoPlay = false;
    if (_videoController == null || !_isVideoReady) return;
    try {
      _videoController!.pause();
    } catch (_) {}
    try {
      _audioPlayer.pause();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _toggleVideoPlay() {
    if (_videoController == null || !_isVideoReady) return;
    if (_videoController!.value.isPlaying) {
      _syncPause();
    } else {
      _syncPlay();
    }
  }

  // ============================================
  // ÂM LƯỢNG
  // ============================================
  void _onOriginalVolumeChanged(double v) {
    setState(() => _originalVolume = v);
    _videoController?.setVolume(v);
  }

  void _onMusicVolumeChanged(double v) {
    setState(() => _musicVolume = v);
    _audioPlayer.setVolume(v);
  }

  // ============================================
  // CHỌN NHẠC
  // ============================================
  Future<void> _selectMusic(Map<String, dynamic>? music) async {
    await _audioPlayer.stop();

    if (music == null) {
      // BỎ NHẠC → bật lại âm gốc
      if (!mounted) return;
      _originalVolume = 1.0;
      try {
        _videoController?.setVolume(1.0);
      } catch (_) {}
      setState(() => _selectedMusic = null);
      await _syncPlay();
      return;
    }

    try {
      final url = music['audio_url']?.toString() ?? '';
      if (url.isEmpty) {
        _showError('Nhạc không có URL hợp lệ');
        return;
      }

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      ));

      final duration = await _audioPlayer.setUrl(url);

      if (duration != null && duration.inSeconds < 10) {
        _showError('Bài nhạc quá ngắn (<10s). Vui lòng chọn bài khác.');
        await _audioPlayer.stop();
        return;
      }

      await _audioPlayer.setVolume(_musicVolume);
      await _audioPlayer.setLoopMode(LoopMode.one);

      if (!mounted) return;

      // ⭐ TẮT âm gốc (do ROM Realme chặn 2 audio cùng lúc)
      _originalVolume = 0.0;
      try {
        _videoController?.setVolume(0.0);
      } catch (_) {}

      setState(() => _selectedMusic = music);

      await _syncPlay();

      debugPrint('🎵 Đã chọn: ${music['title']} (${duration?.inSeconds}s)');
    } catch (e) {
      debugPrint('Lỗi phát nhạc: $e');
      _showError('Không thể phát nhạc này');
      if (mounted) setState(() => _selectedMusic = null);
      await _syncPlay();
    }
  }

  // ============================================
  // SHEET CHỌN NHẠC
  // ============================================
  void _openMusicPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Chọn nhạc nền',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.music_off, color: Colors.white),
              ),
              title: const Text(
                'Không có nhạc',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await _selectMusic(null);
                if (mounted) Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: _isLoadingMusic
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : _musicList.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Chưa có nhạc nào.\nVui lòng upload nhạc lên Supabase.',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _musicList.length,
                          itemBuilder: (context, i) {
                            final music = _musicList[i];
                            final isSelected =
                                _selectedMusic?['id'] == music['id'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? const Color(0xFFFE2C55)
                                    : Colors.grey[800],
                                child: const Icon(Icons.music_note,
                                    color: Colors.white),
                              ),
                              title: Text(
                                music['title'] ?? 'Không tên',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                music['artist'] ?? 'Nghệ sĩ ẩn danh',
                                style:
                                    const TextStyle(color: Colors.white54),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check,
                                      color: Color(0xFFFE2C55))
                                  : null,
                              onTap: () async {
                                await _selectMusic(music);
                                if (mounted && context.mounted) Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    ).then((_) async {
      await _syncPlay();
    });
  }

  // ============================================
  // SHEET ÂM THANH
  // ============================================
  void _openAudioSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Xong',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.mic, color: Colors.black, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Gốc',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFFE2C55),
                  inactiveTrackColor: Colors.grey[300],
                  thumbColor: Colors.white,
                  overlayColor: const Color(0x29FE2C55),
                  trackHeight: 8,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 14),
                ),
                child: Slider(
                  value: _originalVolume,
                  onChanged: (v) {
                    _onOriginalVolumeChanged(v);
                    setSheetState(() {});
                  },
                  min: 0.0,
                  max: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.music_note, color: Colors.black, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Âm thanh',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFFE2C55),
                  inactiveTrackColor: Colors.grey[300],
                  thumbColor: Colors.white,
                  overlayColor: const Color(0x29FE2C55),
                  trackHeight: 8,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 14),
                ),
                child: Slider(
                  value: _musicVolume,
                  onChanged: _selectedMusic != null
                      ? (v) {
                          _onMusicVolumeChanged(v);
                          setSheetState(() {});
                        }
                      : null,
                  min: 0.0,
                  max: 1.0,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // TEXT EDITOR
  // ============================================
  void _openTextEditor() {
    _textController.text = _overlayText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thêm văn bản',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nhập văn bản...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Màu:',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 12),
                  ..._buildColorOptions(),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _overlayText = _textController.text.trim();
                    });
                    Navigator.pop(context);
                    await _syncPlay();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE2C55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'XONG',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildColorOptions() {
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.pink,
    ];
    return colors.map((c) {
      return GestureDetector(
        onTap: () => setState(() => _overlayColor = c),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: _overlayColor == c ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      );
    }).toList();
  }

  // ============================================
  // SHEET ĐĂNG BÀI
  // ============================================
  void _openEditSheet() {
    _syncPause();

    final captionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mô tả video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Thêm mô tả... #hashtag #xuhuong',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedMusic != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note,
                          color: Color(0xFFFE2C55), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_selectedMusic!['title']} - ${_selectedMusic!['artist']}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _uploadVideo(captionController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE2C55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'ĐĂNG VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ).then((_) async {
      await _syncPlay();
    });
  }

  // ============================================
  // NÉN VIDEO
  // ============================================
  Future<File> _compressVideo(File input) async {
    final originalSize = await input.length();
    final originalMB = originalSize / 1024 / 1024;

    debugPrint('=== TRƯỚC NÉN: ${originalMB.toStringAsFixed(2)} MB');

    if (!mounted) return input;
    setState(() => _uploadStatus = 'Đang tối ưu video...');

    try {
      if (originalMB < 15) {
        debugPrint('=== Video nhỏ (<15MB) → giữ nguyên');
        return input;
      }

      final info = await VideoCompress.compressVideo(
        input.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      if (info?.file != null) {
        final newSize = await info!.file!.length();
        final newMB = newSize / 1024 / 1024;
        final reduction =
            ((1 - newSize / originalSize) * 100).toStringAsFixed(0);

        debugPrint('=== SAU NÉN: ${newMB.toStringAsFixed(2)} MB (giảm $reduction%)');

        if (newMB > originalMB * 0.95) {
          return input;
        }

        return info.file!;
      }
    } catch (e) {
      debugPrint('=== Lỗi nén: $e');
    }

    return input;
  }

  // ============================================
  // UPLOAD CLOUDINARY
  // ============================================
  Future<String?> _uploadToCloudinary(File video) async {
    final media = await MediaService.uploadPublic(XFile(video.path), video: true);
    return media.url;
  }

  // ============================================
  // UPLOAD VIDEO
  // ============================================
  Future<void> _uploadVideo(String caption) async {
    if (_videoFile == null) {
      _showError('Vui lòng chọn video');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Đang chuẩn bị...';
    });

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showError('Chưa đăng nhập');
      if (mounted) setState(() => _isUploading = false);
      return;
    }

    try {
      setState(() => _uploadProgress = 0.15);
      final compressed = await _compressVideo(_videoFile!);

      if (!mounted) return;
      setState(() {
        _uploadProgress = 0.4;
        _uploadStatus = 'Đang upload lên Cloudinary...';
      });

      final videoUrl = await _uploadToCloudinary(compressed);

      if (videoUrl == null) {
        throw Exception('Upload Cloudinary thất bại');
      }

      if (!mounted) return;
      setState(() {
        _uploadProgress = 0.85;
        _uploadStatus = 'Đang lưu thông tin...';
      });

      // LƯU VÀO DB với volume chuẩn (30% gốc + 100% nhạc)
      await _supabase.from('videos').insert({
        'user_id': user.id,
        'video_url': videoUrl,
        'caption': caption,
        'music_id': _selectedMusic?['id'],
        'music_name': _selectedMusic != null
            ? '${_selectedMusic!['title']} - ${_selectedMusic!['artist']}'
            : null,
        'music_url': _selectedMusic?['audio_url'],
        'overlay_text': _overlayText.isEmpty ? null : _overlayText,
        'overlay_font_size': _overlayFontSize,
        'overlay_color':
            _overlayColor.toARGB32().toRadixString(16).padLeft(8, '0'),
        'original_volume': _uploadOriginalVolume,
        'music_volume': _uploadMusicVolume,
        'duration': _videoController?.value.duration.inSeconds ?? 0,
        'views': 0,
      });

      if (!mounted) return;
      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng video thành công! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('=== Lỗi đăng: $e');
      _showError('Lỗi đăng: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _currentStep == 0 ? _buildChooseStep() : _buildPreviewStep(),
    );
  }

  // ============================================
  // BƯỚC 0: CHỌN NGUỒN
  // ============================================
  Widget _buildChooseStep() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          Column(
            children: [
              const Spacer(),
              const Text(
                'Tạo video mới',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chọn cách bạn muốn tạo video',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              _buildSourceButton(
                icon: Icons.videocam_rounded,
                label: 'Quay video',
                subtitle: 'Dùng camera để quay (tối đa 60s)',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFE2C55), Color(0xFFFF5C7A)],
                ),
                onTap: _recordWithCamera,
              ),
              const SizedBox(height: 20),
              _buildSourceButton(
                icon: Icons.video_library_rounded,
                label: 'Tải lên từ thư viện',
                subtitle: 'Chọn video có sẵn (tối đa 60s)',
                gradient: const LinearGradient(
                  colors: [Color(0xFF25F4EE), Color(0xFF00B8B0)],
                ),
                onTap: _pickFromGallery,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (gradient as LinearGradient)
                    .colors[0]
                    .withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // BƯỚC 1: PREVIEW
  // ============================================
  Widget _buildPreviewStep() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_videoController != null && _isVideoReady)
          GestureDetector(
            onTap: _toggleVideoPlay,
            child: Center(
              child: AspectRatio(
                aspectRatio: _originalAspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),

        if (_overlayText.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _overlayText,
                    style: TextStyle(
                      color: _overlayColor,
                      fontSize: _overlayFontSize,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black87),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

        if (_videoController != null && !_videoController!.value.isPlaying)
          const Center(
            child: IgnorePointer(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 100,
              ),
            ),
          ),

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 28),
                  onPressed: () {
                    _syncPause();
                    setState(() {
                      _currentStep = 0;
                      _videoFile = null;
                      _videoController = null;
                      _isVideoReady = false;
                      _overlayText = '';
                      _selectedMusic = null;
                      _originalVolume = 1.0;
                    });
                  },
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openEditSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE2C55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Tiếp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _fileSizeMB > 50
                          ? Colors.red.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_fileSizeMB.toStringAsFixed(1)} MB',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: _openMusicPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedMusic != null
                            ? const Color(0xFFFE2C55).withValues(alpha: 0.8)
                            : Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedMusic != null
                                  ? '${_selectedMusic!['title']} - ${_selectedMusic!['artist']}'
                                  : 'Thêm nhạc',
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
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: _openAudioSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.tune,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Âm thanh',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      GestureDetector(
                        onTap: _openTextEditor,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _overlayText.isNotEmpty
                                ? const Color(0xFFFE2C55).withValues(alpha: 0.8)
                                : Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.text_fields,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                _overlayText.isNotEmpty
                                    ? 'Sửa chữ'
                                    : 'Văn bản',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_isUploading) _buildUploadOverlay(),
      ],
    );
  }

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    color: const Color(0xFFFE2C55),
                    strokeWidth: 6,
                  ),
                  Center(
                    child: Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _uploadStatus,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng đợi, không tắt app...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
