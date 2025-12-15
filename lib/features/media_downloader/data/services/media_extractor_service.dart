import 'package:dio/dio.dart';

/// Lightweight helper around Dio for downloading media files.
///
/// NOTE: For legal and technical reasons we only support downloading when
/// the URL you pass already points directly to a media file (e.g. .mp4, .jpg).
/// Many social platforms (Instagram, Facebook, Twitter/X, TikTok, etc.)
/// require authentication, signed requests, or obfuscated APIs for downloads.
/// Those cannot be reliably scraped from inside the app, so users should copy
/// the direct media link before downloading.
class MediaExtractorService {
  final Dio _dio = Dio();

  /// Returns true if the URL looks like a direct media file.
  bool isMediaUrl(String url) {
    final mediaExtensions = ['.mp4', '.webm', '.ogg', '.mp3', '.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final lowerUrl = url.toLowerCase();
    return mediaExtensions.any((ext) => lowerUrl.contains(ext));
  }

  // Download file with progress tracking
  Future<void> downloadFile(
    String url,
    String filePath,
    Function(double) onProgress,
  ) async {
    await _dio.download(
      url,
      filePath,
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );
  }
}

