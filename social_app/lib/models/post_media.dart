/// A media item can be public (Cloudinary/legacy URL) or private (chat storage).
class PostMedia {
  final String kind;
  final String url;
  final String? publicId;
  final String? storagePath;
  const PostMedia({required this.kind, this.url = '', this.publicId, this.storagePath});

  bool get isVideo => kind == 'video';
  Map<String, dynamic> toJson() => {
    'kind': kind, 'url': url,
    if (publicId != null) 'public_id': publicId,
    if (storagePath != null) 'storage_path': storagePath,
  };
  static PostMedia? parse(dynamic value) {
    if (value is! Map) return null;
    final kind = value['kind'];
    final url = value['url']?.toString() ?? '';
    final path = value['storage_path']?.toString();
    if ((kind != 'image' && kind != 'video') || (url.isEmpty && (path == null || path.isEmpty))) return null;
    return PostMedia(kind: kind as String, url: url,
      publicId: value['public_id']?.toString(), storagePath: path);
  }

  static List<PostMedia> fromPost(Map<String, dynamic> post) {
    final raw = post['media'];
    final items = raw is List ? raw.map(parse).whereType<PostMedia>().toList() : <PostMedia>[];
    if (items.isNotEmpty) return items;
    final image = post['image_url']?.toString() ?? '';
    final video = post['video_url']?.toString() ?? '';
    return [if (image.isNotEmpty) PostMedia(kind: 'image', url: image),
      if (video.isNotEmpty) PostMedia(kind: 'video', url: video)];
  }
}
