enum MediaPlatform {
  youtube,
  instagram,
  facebook,
  twitter,
  tiktok,
  other,
}

enum MediaType {
  video,
  image,
  audio,
  story,
  reel,
  post,
}

enum DownloadQuality {
  lowest,
  low,
  medium,
  high,
  highest,
}

class MediaDownloadEntity {
  final String id;
  final String url;
  final MediaPlatform platform;
  final MediaType type;
  final String? title;
  final String? thumbnailUrl;
  final DownloadQuality quality;
  final double progress;
  final String? filePath;
  final int? fileSize;
  final DateTime createdAt;
  final bool isCompleted;
  final String? error;

  MediaDownloadEntity({
    required this.id,
    required this.url,
    required this.platform,
    required this.type,
    this.title,
    this.thumbnailUrl,
    required this.quality,
    this.progress = 0.0,
    this.filePath,
    this.fileSize,
    DateTime? createdAt,
    this.isCompleted = false,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  MediaDownloadEntity copyWith({
    String? id,
    String? url,
    MediaPlatform? platform,
    MediaType? type,
    String? title,
    String? thumbnailUrl,
    DownloadQuality? quality,
    double? progress,
    String? filePath,
    int? fileSize,
    DateTime? createdAt,
    bool? isCompleted,
    String? error,
  }) {
    return MediaDownloadEntity(
      id: id ?? this.id,
      url: url ?? this.url,
      platform: platform ?? this.platform,
      type: type ?? this.type,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      quality: quality ?? this.quality,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

