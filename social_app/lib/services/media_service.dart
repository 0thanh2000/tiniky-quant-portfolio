import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../models/post_media.dart';

class MediaService {
  static const maxImages = 10;
  static const maxImageBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxVideoSeconds = 60;
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> validate(XFile file, {required bool video}) async {
    final size = await file.length();
    if (size <= 0 || size > (video ? maxVideoBytes : maxImageBytes)) {
      throw Exception(video ? 'Video tối đa 50 MB.' : 'Mỗi ảnh tối đa 10 MB.');
    }
    if (video) {
      final controller = VideoPlayerController.file(File(file.path));
      try {
        await controller.initialize().timeout(const Duration(seconds: 20));
        if (controller.value.duration.inMilliseconds <= 0 ||
            controller.value.duration > const Duration(seconds: maxVideoSeconds)) {
          throw Exception('Vui lòng chọn video dài tối đa 60 giây.');
        }
      } finally { await controller.dispose(); }
    }
  }

  /// Signed upload: API secret lives only inside the Supabase Edge Function.
  static Future<PostMedia> uploadPublic(XFile file, {required bool video}) async {
    await validate(file, video: video);
    final signed = await _db.functions.invoke('cloudinary-sign', body: {'kind': video ? 'video' : 'image'});
    if (signed.status != 200 || signed.data is! Map) {
      throw Exception('Chưa cấu hình upload Cloudinary. Xem HUONG_DAN.md.');
    }
    final data = Map<String, dynamic>.from(signed.data as Map);
    final cloud = data['cloud_name'] as String;
    final params = Map<String, dynamic>.from(data['params'] as Map);
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', Uri.https('api.cloudinary.com', '/v1_1/$cloud/${video ? 'video' : 'image'}/upload'));
      params.forEach((k, v) => request.fields[k] = v.toString());
      request.fields['signature'] = data['signature'] as String;
      request.fields['api_key'] = data['api_key'] as String;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await http.Response.fromStream(await client.send(request)).timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) throw Exception('Upload thất bại (${response.statusCode}). Kiểm tra preset và dung lượng.');
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final url = result['secure_url'] as String?;
      if (url == null || !url.startsWith('https://')) throw Exception('Upload không trả về URL hợp lệ.');
      return PostMedia(kind: video ? 'video' : 'image', url: url, publicId: result['public_id'] as String?);
    } finally { client.close(); }
  }

  /// Chat attachments are private; store the object path, never an expiring URL.
  static Future<PostMedia> uploadChat(XFile file, String conversationId, {required bool video}) async {
    await validate(file, video: video);
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Bạn cần đăng nhập lại.');
    final ext = file.name.split('.').last.toLowerCase();
    const mime = {'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp',
      'heic':'image/heic','heif':'image/heif','gif':'image/gif','mp4':'video/mp4','mov':'video/quicktime','webm':'video/webm'};
    if (!mime.containsKey(ext) || !(mime[ext]!.startsWith(video ? 'video/' : 'image/'))) {
      throw Exception('Định dạng tệp chưa được hỗ trợ.');
    }
    final path = '$conversationId/${user.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _db.storage.from('chat-media').upload(path, File(file.path),
      fileOptions: FileOptions(contentType: mime[ext], upsert: false));
    return PostMedia(kind: video ? 'video' : 'image', storagePath: path);
  }

  static Future<String> resolve(PostMedia media) async {
    if (media.storagePath == null) return media.url;
    return _db.storage.from('chat-media').createSignedUrl(media.storagePath!, 3600);
  }
  static Future<void> removeFailedChatUpload(PostMedia media) async {
    if (media.storagePath != null) await _db.storage.from('chat-media').remove([media.storagePath!]);
  }
}
