import 'package:hive/hive.dart';
import '../../domain/entities/bookmark_entity.dart';

part 'bookmark_model.g.dart';

@HiveType(typeId: 0)
class BookmarkModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String url;

  @HiveField(3)
  final String? faviconUrl;

  @HiveField(4)
  final String? folderName;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  BookmarkModel({
    required this.id,
    required this.title,
    required this.url,
    this.faviconUrl,
    this.folderName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookmarkModel.fromEntity(BookmarkEntity entity) {
    return BookmarkModel(
      id: entity.id,
      title: entity.title,
      url: entity.url,
      faviconUrl: entity.faviconUrl,
      folderName: entity.folderName,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  BookmarkEntity toEntity() {
    return BookmarkEntity(
      id: id,
      title: title,
      url: url,
      faviconUrl: faviconUrl,
      folderName: folderName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'faviconUrl': faviconUrl,
      'folderName': folderName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'],
      title: json['title'],
      url: json['url'],
      faviconUrl: json['faviconUrl'],
      folderName: json['folderName'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

