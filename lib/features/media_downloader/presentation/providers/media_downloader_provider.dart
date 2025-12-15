import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../../domain/entities/media_download_entity.dart';
import '../../data/services/media_extractor_service.dart';
import '../../data/services/social_media_download_service.dart';

class MediaDownloaderState {
  final List<MediaDownloadEntity> downloads;
  final bool isDownloading;
  final String? error;

  MediaDownloaderState({
    this.downloads = const [],
    this.isDownloading = false,
    this.error,
  });

  MediaDownloaderState copyWith({
    List<MediaDownloadEntity>? downloads,
    bool? isDownloading,
    String? error,
  }) {
    return MediaDownloaderState(
      downloads: downloads ?? this.downloads,
      isDownloading: isDownloading ?? this.isDownloading,
      error: error,
    );
  }
}

class MediaDownloaderNotifier extends StateNotifier<MediaDownloaderState> {
  MediaDownloaderNotifier() : super(MediaDownloaderState());

  final YoutubeExplode _ytExplode = YoutubeExplode();
  final MediaExtractorService _extractorService = MediaExtractorService();
  final SocialMediaDownloadService _socialService = SocialMediaDownloadService();

  // Common helper for platforms that require a direct media URL (mp4/jpg/etc.).
  Future<void> _downloadDirectMedia({
    required String originalUrl,
    required String mediaUrl,
    required DownloadQuality quality,
    required MediaPlatform platform,
    required MediaType type,
    required String titlePrefix,
  }) async {
    // Require a direct media link (to avoid fragile HTML scraping and auth issues)
    if (!_extractorService.isMediaUrl(mediaUrl)) {
      throw Exception(
        'This URL is not a direct media file. '
        'Open the video or image, copy its direct link ending with .mp4, .jpg, etc, then try again.',
      );
    }

    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create initial entity
    var download = MediaDownloadEntity(
      id: downloadId,
      url: originalUrl,
      platform: platform,
      type: type,
      title: '$titlePrefix Media',
      quality: quality,
    );

    state = state.copyWith(
      downloads: [...state.downloads, download],
      isDownloading: true,
    );

    try {
      final directory = await _getDownloadDirectory();
      final extension = mediaUrl.split('.').last.split('?').first;
      final fileName = '${titlePrefix.toLowerCase()}_$downloadId.$extension';
      final filePath = path.join(directory.path, fileName);

      await _extractorService.downloadFile(
        mediaUrl,
        filePath,
        (progress) {
          final updatedDownloads = state.downloads.map((d) {
            if (d.id == downloadId) {
              return d.copyWith(progress: progress);
            }
            return d;
          }).toList();
          state = state.copyWith(downloads: updatedDownloads);
        },
      );

      final file = File(filePath);
      final fileSize = await file.length();

      final completedDownloads = state.downloads.map((d) {
        if (d.id == downloadId) {
          return d.copyWith(
            isCompleted: true,
            filePath: filePath,
            fileSize: fileSize,
            progress: 1.0,
          );
        }
        return d;
      }).toList();

      state = state.copyWith(
        downloads: completedDownloads,
        isDownloading: false,
      );
    } catch (e) {
      final errorDownloads = state.downloads.map((d) {
        if (d.id == downloadId) {
          return d.copyWith(error: e.toString());
        }
        return d;
      }).toList();
      state = state.copyWith(
        downloads: errorDownloads,
        isDownloading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Detect platform from URL
  MediaPlatform _detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return MediaPlatform.youtube;
    } else if (lowerUrl.contains('instagram.com')) {
      return MediaPlatform.instagram;
    } else if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.com')) {
      return MediaPlatform.facebook;
    } else if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      return MediaPlatform.twitter;
    } else if (lowerUrl.contains('tiktok.com')) {
      return MediaPlatform.tiktok;
    }
    return MediaPlatform.other;
  }

  // Detect media type from URL
  MediaType _detectMediaType(String url, MediaPlatform platform) {
    final lowerUrl = url.toLowerCase();
    if (platform == MediaPlatform.instagram) {
      if (lowerUrl.contains('/reel/') || lowerUrl.contains('/reels/')) {
        return MediaType.reel;
      } else if (lowerUrl.contains('/stories/') || lowerUrl.contains('/story/')) {
        return MediaType.story;
      } else {
        return MediaType.post;
      }
    } else if (platform == MediaPlatform.youtube) {
      if (lowerUrl.contains('/shorts/')) {
        return MediaType.reel;
      }
      return MediaType.video;
    }
    return MediaType.video;
  }

  // Extract video ID from YouTube URL
  String? _extractYouTubeVideoId(String url) {
    final regex = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  // Get YouTube video info and download
  Future<void> downloadYouTubeVideo(
    String url,
    DownloadQuality quality,
  ) async {
    try {
      final videoId = _extractYouTubeVideoId(url);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }

      final video = await _ytExplode.videos.get(videoId);
      final manifest = await _ytExplode.videos.streamsClient.getManifest(videoId);

      // IMPORTANT: Use MUXED streams to get video WITH audio
      // Video-only streams have no audio and require FFmpeg to merge
      StreamInfo? streamInfo;
      final muxedStreams = manifest.muxed.toList();
      
      if (muxedStreams.isEmpty) {
        throw Exception('No downloadable streams found for this video');
      }
      
      // Sort muxed streams by bitrate (higher bitrate = better quality)
      muxedStreams.sort((a, b) {
        final aBitrate = a.bitrate.bitsPerSecond;
        final bBitrate = b.bitrate.bitsPerSecond;
        return bBitrate.compareTo(aBitrate); // Descending order (highest first)
      });
      
      // Select stream based on quality preference
      switch (quality) {
        case DownloadQuality.highest:
          streamInfo = muxedStreams.first;
          break;
        case DownloadQuality.high:
          // Get high bitrate stream (top 25%)
          final index = (muxedStreams.length * 0.25).floor();
          streamInfo = muxedStreams[index.clamp(0, muxedStreams.length - 1)];
          break;
        case DownloadQuality.medium:
          // Get medium bitrate stream (middle 50%)
          final index = (muxedStreams.length * 0.5).floor();
          streamInfo = muxedStreams[index.clamp(0, muxedStreams.length - 1)];
          break;
        case DownloadQuality.low:
          // Get low bitrate stream (bottom 75%)
          final index = (muxedStreams.length * 0.75).floor();
          streamInfo = muxedStreams[index.clamp(0, muxedStreams.length - 1)];
          break;
        case DownloadQuality.lowest:
          streamInfo = muxedStreams.last;
          break;
      }
      
      // Get quality label for display
      final qualityLabel = _getQualityLabel(quality);

      // Create download entity with unique ID (include timestamp to avoid duplicates)
      final downloadId = '${videoId}_${DateTime.now().millisecondsSinceEpoch}';
      final download = MediaDownloadEntity(
        id: downloadId,
        url: url,
        platform: MediaPlatform.youtube,
        type: _detectMediaType(url, MediaPlatform.youtube),
        title: '${video.title} [$qualityLabel]',
        thumbnailUrl: video.thumbnails.highResUrl,
        quality: quality,
      );

      state = state.copyWith(
        downloads: [...state.downloads, download],
        isDownloading: true,
      );

      // Get download directory
      final directory = await _getDownloadDirectory();
      // Clean filename - remove special characters
      final cleanTitle = video.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final fileName = '${cleanTitle}_$qualityLabel.${streamInfo.container.name}';
      final filePath = path.join(directory.path, fileName);

      // Download the video
      final stream = _ytExplode.videos.streamsClient.get(streamInfo);
      final file = File(filePath);
      final fileStream = file.openWrite();

      int downloadedBytes = 0;
      final totalBytes = streamInfo.size.totalBytes;

      await for (final data in stream) {
        fileStream.add(data);
        downloadedBytes += data.length;
        final progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

        // Update progress
        final updatedDownloads = state.downloads.map((d) {
          if (d.id == download.id) {
            return d.copyWith(progress: progress);
          }
          return d;
        }).toList();

        state = state.copyWith(downloads: updatedDownloads);
      }

      await fileStream.close();

      // Mark as completed
      final completedDownloads = state.downloads.map((d) {
        if (d.id == download.id) {
          return d.copyWith(
            isCompleted: true,
            filePath: filePath,
            fileSize: totalBytes,
            progress: 1.0,
          );
        }
        return d;
      }).toList();

      state = state.copyWith(
        downloads: completedDownloads,
        isDownloading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Download from Instagram - tries extraction first, falls back to direct URL
  Future<void> downloadInstagramMedia(
    String url,
    DownloadQuality quality,
  ) async {
    // If it's already a direct media URL, download directly
    if (_extractorService.isMediaUrl(url)) {
      await _downloadDirectMedia(
        originalUrl: url,
        mediaUrl: url,
        quality: quality,
        platform: MediaPlatform.instagram,
        type: _detectMediaType(url, MediaPlatform.instagram),
        titlePrefix: 'Instagram',
      );
      return;
    }

    // Try to extract media URL from the Instagram page
    try {
      final mediaInfoList = await _socialService.extractInstagramMedia(url);
      if (mediaInfoList.isNotEmpty) {
        final mediaInfo = mediaInfoList.first;
        await _downloadExtractedMedia(
          originalUrl: url,
          extractedUrl: mediaInfo.url,
          quality: quality,
          platform: MediaPlatform.instagram,
          type: mediaInfo.type == MediaInfoType.video ? MediaType.video : MediaType.image,
          titlePrefix: 'Instagram_${mediaInfo.type.name}',
        );
        return;
      }
    } catch (e) {
      // Extraction failed, throw helpful error
      throw Exception(
        'Could not download Instagram media. '
        'Try opening the post in browser, long-press on the video/image, '
        'and copy the direct media URL.',
      );
    }
  }

  // Download from Facebook
  Future<void> downloadFacebookMedia(
    String url,
    DownloadQuality quality,
  ) async {
    // If it's already a direct media URL, download directly
    if (_extractorService.isMediaUrl(url)) {
      await _downloadDirectMedia(
        originalUrl: url,
        mediaUrl: url,
        quality: quality,
        platform: MediaPlatform.facebook,
        type: MediaType.video,
        titlePrefix: 'Facebook',
      );
      return;
    }

    // Try to extract media URL from Facebook page
    try {
      final mediaInfoList = await _socialService.extractFacebookMedia(url);
      if (mediaInfoList.isNotEmpty) {
        final mediaInfo = mediaInfoList.first;
        await _downloadExtractedMedia(
          originalUrl: url,
          extractedUrl: mediaInfo.url,
          quality: quality,
          platform: MediaPlatform.facebook,
          type: MediaType.video,
          titlePrefix: 'Facebook_video',
        );
        return;
      }
    } catch (e) {
      throw Exception(
        'Could not download Facebook video. '
        'Facebook videos often require login. '
        'Try using the web version and copying the direct video URL.',
      );
    }
  }

  // Download from Twitter/X
  Future<void> downloadTwitterMedia(
    String url,
    DownloadQuality quality,
  ) async {
    // If it's already a direct media URL, download directly
    if (_extractorService.isMediaUrl(url)) {
      await _downloadDirectMedia(
        originalUrl: url,
        mediaUrl: url,
        quality: quality,
        platform: MediaPlatform.twitter,
        type: MediaType.video,
        titlePrefix: 'Twitter',
      );
      return;
    }

    // Try to extract media URL from Twitter
    try {
      final mediaInfoList = await _socialService.extractTwitterMedia(url);
      if (mediaInfoList.isNotEmpty) {
        final mediaInfo = mediaInfoList.first;
        await _downloadExtractedMedia(
          originalUrl: url,
          extractedUrl: mediaInfo.url,
          quality: quality,
          platform: MediaPlatform.twitter,
          type: mediaInfo.type == MediaInfoType.video ? MediaType.video : MediaType.image,
          titlePrefix: 'Twitter_${mediaInfo.type.name}',
        );
        return;
      }
    } catch (e) {
      throw Exception(
        'Could not download Twitter/X media. '
        'Try opening the tweet, playing the video, and using a third-party service.',
      );
    }
  }

  // Download from TikTok
  Future<void> downloadTikTokMedia(
    String url,
    DownloadQuality quality,
  ) async {
    // If it's already a direct media URL, download directly
    if (_extractorService.isMediaUrl(url)) {
      await _downloadDirectMedia(
        originalUrl: url,
        mediaUrl: url,
        quality: quality,
        platform: MediaPlatform.tiktok,
        type: MediaType.reel,
        titlePrefix: 'TikTok',
      );
      return;
    }

    // Try to extract media URL from TikTok
    try {
      final mediaInfoList = await _socialService.extractTikTokMedia(url);
      if (mediaInfoList.isNotEmpty) {
        final mediaInfo = mediaInfoList.first;
        await _downloadExtractedMedia(
          originalUrl: url,
          extractedUrl: mediaInfo.url,
          quality: quality,
          platform: MediaPlatform.tiktok,
          type: MediaType.reel,
          titlePrefix: 'TikTok_video',
        );
        return;
      }
    } catch (e) {
      throw Exception(
        'Could not download TikTok video. '
        'TikTok has strict protection. '
        'Try using TikTok\'s built-in download feature or a third-party service.',
      );
    }
  }

  // Download generic media from any URL
  Future<void> downloadGenericMedia(
    String url,
    DownloadQuality quality,
  ) async {
    await _downloadDirectMedia(
      originalUrl: url,
      mediaUrl: url,
      quality: quality,
      platform: MediaPlatform.other,
      type: MediaType.video,
      titlePrefix: 'Media',
    );
  }

  // Helper to download extracted media with proper error handling
  Future<void> _downloadExtractedMedia({
    required String originalUrl,
    required String extractedUrl,
    required DownloadQuality quality,
    required MediaPlatform platform,
    required MediaType type,
    required String titlePrefix,
  }) async {
    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create initial entity
    var download = MediaDownloadEntity(
      id: downloadId,
      url: originalUrl,
      platform: platform,
      type: type,
      title: '$titlePrefix Media',
      quality: quality,
    );

    state = state.copyWith(
      downloads: [...state.downloads, download],
      isDownloading: true,
    );

    try {
      final directory = await _getDownloadDirectory();
      // Determine extension from URL or default to mp4
      String extension = 'mp4';
      final urlParts = extractedUrl.split('.');
      if (urlParts.length > 1) {
        final ext = urlParts.last.split('?').first.toLowerCase();
        if (['mp4', 'webm', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'mp3'].contains(ext)) {
          extension = ext;
        }
      }
      
      final fileName = '${titlePrefix.toLowerCase().replaceAll(' ', '_')}_$downloadId.$extension';
      final filePath = path.join(directory.path, fileName);

      await _socialService.downloadFile(
        extractedUrl,
        filePath,
        (progress) {
          final updatedDownloads = state.downloads.map((d) {
            if (d.id == downloadId) {
              return d.copyWith(progress: progress);
            }
            return d;
          }).toList();
          state = state.copyWith(downloads: updatedDownloads);
        },
      );

      final file = File(filePath);
      final fileSize = await file.length();

      final completedDownloads = state.downloads.map((d) {
        if (d.id == downloadId) {
          return d.copyWith(
            isCompleted: true,
            filePath: filePath,
            fileSize: fileSize,
            progress: 1.0,
          );
        }
        return d;
      }).toList();

      state = state.copyWith(
        downloads: completedDownloads,
        isDownloading: false,
      );
    } catch (e) {
      final errorDownloads = state.downloads.map((d) {
        if (d.id == downloadId) {
          return d.copyWith(error: e.toString());
        }
        return d;
      }).toList();
      state = state.copyWith(
        downloads: errorDownloads,
        isDownloading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Generic download method
  Future<void> downloadMedia(String url, DownloadQuality quality) async {
    final platform = _detectPlatform(url);

    switch (platform) {
      case MediaPlatform.youtube:
        await downloadYouTubeVideo(url, quality);
        break;
      case MediaPlatform.instagram:
        await downloadInstagramMedia(url, quality);
        break;
      case MediaPlatform.facebook:
        await downloadFacebookMedia(url, quality);
        break;
      case MediaPlatform.twitter:
        await downloadTwitterMedia(url, quality);
        break;
      case MediaPlatform.tiktok:
        await downloadTikTokMedia(url, quality);
        break;
      case MediaPlatform.other:
        await downloadGenericMedia(url, quality);
        break;
    }
  }

  // Get download directory
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory(path.join(directory.path, 'Downloads', 'VexMedia'));
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir;
      }
    }
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(path.join(directory.path, 'Downloads', 'VexMedia'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  // Cancel download
  void cancelDownload(String id) {
    final updatedDownloads = state.downloads
        .where((d) => d.id != id)
        .toList();
    state = state.copyWith(downloads: updatedDownloads);
  }

  // Clear completed downloads
  void clearCompleted() {
    final activeDownloads = state.downloads
        .where((d) => !d.isCompleted)
        .toList();
    state = state.copyWith(downloads: activeDownloads);
  }

  // Clear all downloads
  void clearAll() {
    state = state.copyWith(downloads: []);
  }

  // Helper to get quality label
  String _getQualityLabel(DownloadQuality quality) {
    switch (quality) {
      case DownloadQuality.lowest:
        return 'Lowest';
      case DownloadQuality.low:
        return 'Low';
      case DownloadQuality.medium:
        return 'Medium';
      case DownloadQuality.high:
        return 'High';
      case DownloadQuality.highest:
        return 'Highest';
    }
  }
}

final mediaDownloaderProvider =
    StateNotifierProvider<MediaDownloaderNotifier, MediaDownloaderState>(
  (ref) => MediaDownloaderNotifier(),
);

