class MimeUtils {
  static const Map<String, String> _extToMime = {
    // Documents
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'html': 'text/html',
    'htm': 'text/html',

    // Images
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'webp': 'image/webp',

    // Audio
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'aac': 'audio/aac',
    'm4a': 'audio/mp4',

    // Video
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'avi': 'video/x-msvideo',
    'mkv': 'video/x-matroska',

    // Archives
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
  };

  static String inferMimeType(String fileName, {String? contentType}) {
    final ct = (contentType ?? '').trim().toLowerCase();
    if (ct.isNotEmpty) return ct;
    final idx = fileName.lastIndexOf('.');
    if (idx > 0 && idx < fileName.length - 1) {
      final ext = fileName.substring(idx + 1).toLowerCase();
      return _extToMime[ext] ?? 'application/octet-stream';
    }
    return 'application/octet-stream';
  }

  static bool canPreviewInApp(String mime, String fileName) {
    final m = mime.toLowerCase();
    if (m.startsWith('image/')) return true;
    if (m == 'application/pdf') return true;
    if (m.startsWith('text/') || m == 'application/json' || m == 'text/csv')
      return true;
    // You can extend with audio/video if you add viewers; for now keep conservative
    return false;
  }
}
