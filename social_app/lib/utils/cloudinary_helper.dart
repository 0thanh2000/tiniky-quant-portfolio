/// Cloudinary Helper — Tự động resize/nén ảnh & video
class CloudinaryHelper {
  static String transform(String url, {required String params}) {
    if (url.isEmpty) return url;
    if (!url.contains('res.cloudinary.com')) return url;
    if (!url.contains('/upload/')) return url;

    final uploadIndex = url.indexOf('/upload/');
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('w_') ||
        afterUpload.startsWith('h_') ||
        afterUpload.startsWith('q_') ||
        afterUpload.startsWith('c_') ||
        afterUpload.startsWith('f_') ||
        afterUpload.startsWith('so_') ||
        afterUpload.startsWith('vc_')) {
      return url;
    }

    return url.replaceFirst('/upload/', '/upload/$params/');
  }

  static String avatarSmall(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url,
        params: 'w_100,h_100,c_fill,q_auto:good,f_auto,dpr_auto');
  }

  static String avatarMedium(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url,
        params: 'w_200,h_200,c_fill,q_auto:good,f_auto,dpr_auto');
  }

  static String avatarLarge(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url,
        params: 'w_400,h_400,c_fill,q_auto:good,f_auto,dpr_auto');
  }

  static String coverPhoto(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url,
        params: 'w_800,h_450,c_fill,q_auto:good,f_auto,dpr_auto');
  }

  static String postImage(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url, params: 'w_800,q_auto:good,f_auto,dpr_auto');
  }

  static String thumbnail(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url,
        params: 'w_400,h_400,c_fill,q_auto:good,f_auto,dpr_auto');
  }

  static String thumbSmall(String? url) {
    if (url == null || url.isEmpty) return '';
    return transform(url,
        params: 'w_100,h_100,c_fill,q_auto:good,f_auto,dpr_auto');
  }

  static String video(String? url, {int width = 720}) {
    if (url == null || url.isEmpty) return '';
    return transform(url, params: 'w_$width,q_auto:good,f_auto,vc_auto');
  }

  static String videoThumbnail(String? url) {
    if (url == null || url.isEmpty) return '';
    if (!url.contains('res.cloudinary.com')) return url;

    String thumbUrl = url;
    if (url.endsWith('.mp4') || url.endsWith('.mov')) {
      thumbUrl = '${url.substring(0, url.length - 4)}.jpg';
    } else if (url.endsWith('.webm')) {
      thumbUrl = '${url.substring(0, url.length - 5)}.jpg';
    } else {
      return url;
    }

    return transform(thumbUrl,
        params: 'so_0,w_400,h_400,c_fill,q_auto:good,f_auto');
  }
}