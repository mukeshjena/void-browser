import 'package:dio/dio.dart';
import 'dart:convert';

/// Service for downloading media from various social media platforms.
/// Uses web-based extraction techniques that work without official API keys.
class SocialMediaDownloadService {
  final Dio _dio;

  SocialMediaDownloadService() : _dio = Dio() {
    _dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
    };
    _dio.options.followRedirects = true;
    _dio.options.validateStatus = (status) => status != null && status < 500;
  }

  /// Extract Instagram media URL from post/reel/story URL
  /// Returns a list of media URLs (posts can have multiple images/videos)
  Future<List<MediaInfo>> extractInstagramMedia(String url) async {
    try {
      // Try using Instagram's public embed API
      final embedUrl = _getInstagramEmbedUrl(url);
      if (embedUrl != null) {
        final response = await _dio.get(embedUrl);
        if (response.statusCode == 200) {
          final mediaUrls = _parseInstagramEmbed(response.data.toString());
          if (mediaUrls.isNotEmpty) {
            return mediaUrls;
          }
        }
      }

      // Fallback: Try to extract from page HTML
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final mediaUrls = _extractMediaFromHtml(response.data.toString(), 'instagram');
        if (mediaUrls.isNotEmpty) {
          return mediaUrls;
        }
      }

      throw Exception(
        'Could not extract media from Instagram. '
        'Try copying the direct video/image URL instead.',
      );
    } catch (e) {
      if (e.toString().contains('Could not extract')) {
        rethrow;
      }
      throw Exception('Instagram extraction failed: ${e.toString()}');
    }
  }

  /// Extract Facebook video URL
  Future<List<MediaInfo>> extractFacebookMedia(String url) async {
    try {
      // Try mobile version which is simpler to parse
      final mobileUrl = url.replaceAll('www.facebook.com', 'm.facebook.com');
      
      final response = await _dio.get(
        mobileUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15',
          },
        ),
      );

      if (response.statusCode == 200) {
        final mediaUrls = _extractMediaFromHtml(response.data.toString(), 'facebook');
        if (mediaUrls.isNotEmpty) {
          return mediaUrls;
        }
      }

      throw Exception(
        'Could not extract media from Facebook. '
        'Videos may require login or the URL format is not supported.',
      );
    } catch (e) {
      if (e.toString().contains('Could not extract')) {
        rethrow;
      }
      throw Exception('Facebook extraction failed: ${e.toString()}');
    }
  }

  /// Extract Twitter/X video URL
  Future<List<MediaInfo>> extractTwitterMedia(String url) async {
    try {
      // Normalize URL (x.com -> twitter.com for API compatibility)
      final twitterUrl = url.replaceAll('x.com', 'twitter.com');
      
      // Try using the publish.twitter.com oembed endpoint
      final tweetId = _extractTwitterTweetId(twitterUrl);
      if (tweetId != null) {
        // Twitter's syndication API
        final syndicationUrl = 'https://cdn.syndication.twimg.com/tweet-result?id=$tweetId&token=0';
        
        try {
          final response = await _dio.get(syndicationUrl);
          if (response.statusCode == 200) {
            final mediaUrls = _parseTwitterSyndication(response.data);
            if (mediaUrls.isNotEmpty) {
              return mediaUrls;
            }
          }
        } catch (_) {
          // Syndication API might not work, continue to fallback
        }
      }

      // Fallback: Try to extract from page
      final response = await _dio.get(twitterUrl);
      if (response.statusCode == 200) {
        final mediaUrls = _extractMediaFromHtml(response.data.toString(), 'twitter');
        if (mediaUrls.isNotEmpty) {
          return mediaUrls;
        }
      }

      throw Exception(
        'Could not extract media from Twitter/X. '
        'Try copying the direct video URL from the tweet.',
      );
    } catch (e) {
      if (e.toString().contains('Could not extract')) {
        rethrow;
      }
      throw Exception('Twitter extraction failed: ${e.toString()}');
    }
  }

  /// Extract TikTok video URL
  Future<List<MediaInfo>> extractTikTokMedia(String url) async {
    try {
      // TikTok's mobile API endpoint
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15',
          },
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data.toString();
        
        // Try to find video URL in the page
        final mediaUrls = _extractTikTokVideoUrl(html);
        if (mediaUrls.isNotEmpty) {
          return mediaUrls;
        }
      }

      throw Exception(
        'Could not extract media from TikTok. '
        'TikTok videos often require direct download links.',
      );
    } catch (e) {
      if (e.toString().contains('Could not extract')) {
        rethrow;
      }
      throw Exception('TikTok extraction failed: ${e.toString()}');
    }
  }

  // Helper methods

  String? _getInstagramEmbedUrl(String url) {
    // Extract shortcode from Instagram URL
    final regex = RegExp(r'instagram\.com/(?:p|reel|reels)/([A-Za-z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      final shortcode = match.group(1);
      return 'https://www.instagram.com/p/$shortcode/embed/';
    }
    return null;
  }

  List<MediaInfo> _parseInstagramEmbed(String html) {
    final mediaList = <MediaInfo>[];
    
    // Look for video URL in embed
    final videoRegex = RegExp(r'"video_url"\s*:\s*"([^"]+)"');
    final videoMatches = videoRegex.allMatches(html);
    for (final match in videoMatches) {
      final url = match.group(1)?.replaceAll(r'\u0026', '&');
      if (url != null && url.isNotEmpty) {
        mediaList.add(MediaInfo(
          url: url,
          type: MediaInfoType.video,
          quality: 'HD',
        ));
      }
    }

    // Look for display URL (image)
    if (mediaList.isEmpty) {
      final imageRegex = RegExp(r'"display_url"\s*:\s*"([^"]+)"');
      final imageMatches = imageRegex.allMatches(html);
      for (final match in imageMatches) {
        final url = match.group(1)?.replaceAll(r'\u0026', '&');
        if (url != null && url.isNotEmpty) {
          mediaList.add(MediaInfo(
            url: url,
            type: MediaInfoType.image,
            quality: 'Original',
          ));
        }
      }
    }

    return mediaList;
  }

  List<MediaInfo> _extractMediaFromHtml(String html, String platform) {
    final mediaList = <MediaInfo>[];

    // Common video URL patterns
    final videoPatterns = [
      RegExp(r'(https?://[^\s"<>]+\.mp4[^\s"<>]*)'),
      RegExp(r'(https?://[^\s"<>]+\.webm[^\s"<>]*)'),
      RegExp(r'"contentUrl"\s*:\s*"([^"]+)"'),
      RegExp(r'"video_url"\s*:\s*"([^"]+)"'),
      RegExp(r'src="(https?://[^"]+(?:\.mp4|video)[^"]*)"'),
    ];

    for (final pattern in videoPatterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        String? url = match.group(1);
        if (url != null) {
          url = url.replaceAll(r'\u0026', '&').replaceAll(r'\\/', '/');
          if (_isValidMediaUrl(url)) {
            mediaList.add(MediaInfo(
              url: url,
              type: MediaInfoType.video,
              quality: 'SD',
            ));
          }
        }
      }
    }

    // Image patterns (if no videos found)
    if (mediaList.isEmpty) {
      final imagePatterns = [
        RegExp(r'(https?://[^\s"<>]+\.(?:jpg|jpeg|png|webp)[^\s"<>]*)'),
        RegExp(r'"display_url"\s*:\s*"([^"]+)"'),
      ];

      for (final pattern in imagePatterns) {
        final matches = pattern.allMatches(html);
        for (final match in matches) {
          String? url = match.group(1);
          if (url != null) {
            url = url.replaceAll(r'\u0026', '&').replaceAll(r'\\/', '/');
            if (_isValidMediaUrl(url)) {
              mediaList.add(MediaInfo(
                url: url,
                type: MediaInfoType.image,
                quality: 'Original',
              ));
            }
          }
        }
      }
    }

    // Remove duplicates
    final uniqueUrls = <String>{};
    mediaList.removeWhere((media) => !uniqueUrls.add(media.url));

    return mediaList;
  }

  String? _extractTwitterTweetId(String url) {
    final regex = RegExp(r'(?:twitter|x)\.com/\w+/status/(\d+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  List<MediaInfo> _parseTwitterSyndication(dynamic data) {
    final mediaList = <MediaInfo>[];
    
    try {
      final Map<String, dynamic> json;
      if (data is String) {
        json = jsonDecode(data);
      } else if (data is Map<String, dynamic>) {
        json = data;
      } else {
        return mediaList;
      }

      // Check for video in the response
      if (json.containsKey('video')) {
        final video = json['video'];
        if (video is Map && video.containsKey('variants')) {
          final variants = video['variants'] as List?;
          if (variants != null) {
            for (final variant in variants) {
              if (variant is Map && variant['type'] == 'video/mp4') {
                mediaList.add(MediaInfo(
                  url: variant['src'] ?? '',
                  type: MediaInfoType.video,
                  quality: 'HD',
                ));
              }
            }
          }
        }
      }

      // Check for images
      if (json.containsKey('photos')) {
        final photos = json['photos'] as List?;
        if (photos != null) {
          for (final photo in photos) {
            if (photo is Map && photo.containsKey('url')) {
              mediaList.add(MediaInfo(
                url: photo['url'],
                type: MediaInfoType.image,
                quality: 'Original',
              ));
            }
          }
        }
      }
    } catch (_) {
      // JSON parsing failed
    }

    return mediaList;
  }

  List<MediaInfo> _extractTikTokVideoUrl(String html) {
    final mediaList = <MediaInfo>[];

    // Look for video URL in TikTok's page data
    final patterns = [
      RegExp(r'"playAddr"\s*:\s*"([^"]+)"'),
      RegExp(r'"downloadAddr"\s*:\s*"([^"]+)"'),
      RegExp(r'(https?://[^\s"]+tiktokcdn[^\s"]+\.mp4[^\s"]*)'),
      RegExp(r'(https?://[^\s"]+(?:v16|v19)[^\s"]+\.mp4[^\s"]*)'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(html);
      for (final match in matches) {
        String? url = match.group(1);
        if (url != null) {
          url = url.replaceAll(r'\u0026', '&').replaceAll(r'\\/', '/');
          if (url.contains('.mp4') || url.contains('video')) {
            mediaList.add(MediaInfo(
              url: url,
              type: MediaInfoType.video,
              quality: 'HD',
            ));
            break; // TikTok videos are typically single
          }
        }
      }
      if (mediaList.isNotEmpty) break;
    }

    return mediaList;
  }

  bool _isValidMediaUrl(String url) {
    if (url.isEmpty) return false;
    if (!url.startsWith('http')) return false;
    // Filter out tracking pixels, avatars, etc.
    if (url.contains('avatar') || url.contains('profile')) return false;
    if (url.contains('logo') || url.contains('icon')) return false;
    return true;
  }

  /// Download file with progress tracking
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
          'Referer': Uri.parse(url).origin,
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

/// Information about extracted media
class MediaInfo {
  final String url;
  final MediaInfoType type;
  final String quality;
  final String? thumbnail;

  MediaInfo({
    required this.url,
    required this.type,
    required this.quality,
    this.thumbnail,
  });
}

enum MediaInfoType {
  video,
  image,
  audio,
}
