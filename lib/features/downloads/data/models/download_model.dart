import 'package:hive/hive.dart';
import '../../domain/entities/download_entity.dart';

part 'download_model.g.dart';

@HiveType(typeId: 1)
class DownloadModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final String filename;

  @HiveField(3)
  final String? savedPath;

  @HiveField(4)
  final int totalBytes;

  @HiveField(5)
  final int downloadedBytes;

  @HiveField(6)
  final int statusIndex; // DownloadStatus enum index

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime? completedAt;

  @HiveField(9)
  final String? errorMessage;

  DownloadModel({
    required this.id,
    required this.url,
    required this.filename,
    this.savedPath,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.statusIndex,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  DownloadStatus get status => DownloadStatus.values[statusIndex];

  factory DownloadModel.fromEntity(DownloadEntity entity) {
    return DownloadModel(
      id: entity.id,
      url: entity.url,
      filename: entity.filename,
      savedPath: entity.savedPath,
      totalBytes: entity.totalBytes,
      downloadedBytes: entity.downloadedBytes,
      statusIndex: entity.status.index,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
      errorMessage: entity.errorMessage,
    );
  }

  DownloadEntity toEntity() {
    return DownloadEntity(
      id: id,
      url: url,
      filename: filename,
      savedPath: savedPath,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      status: status,
      createdAt: createdAt,
      completedAt: completedAt,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'savedPath': savedPath,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'statusIndex': statusIndex,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory DownloadModel.fromMap(Map<String, dynamic> map) {
    return DownloadModel(
      id: map['id'] as String,
      url: map['url'] as String,
      filename: map['filename'] as String,
      savedPath: map['savedPath'] as String?,
      totalBytes: map['totalBytes'] as int,
      downloadedBytes: map['downloadedBytes'] as int,
      statusIndex: map['statusIndex'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt'] as String) : null,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

