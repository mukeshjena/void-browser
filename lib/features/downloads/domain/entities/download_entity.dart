enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }

class DownloadEntity {
  final String id;
  final String url;
  final String filename;
  final String? savedPath;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  DownloadEntity({
    required this.id,
    required this.url,
    required this.filename,
    this.savedPath,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  double get progress {
    if (totalBytes == 0) return 0;
    return (downloadedBytes / totalBytes) * 100;
  }

  DownloadEntity copyWith({
    String? id,
    String? url,
    String? filename,
    String? savedPath,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return DownloadEntity(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      savedPath: savedPath ?? this.savedPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

