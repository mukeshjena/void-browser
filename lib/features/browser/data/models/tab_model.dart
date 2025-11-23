import '../../domain/entities/tab_entity.dart';

class TabModel {
  final String id;
  final String url;
  final String? title;
  final String? favicon;
  final DateTime createdAt;
  final bool isIncognito;

  TabModel({
    required this.id,
    required this.url,
    this.title,
    this.favicon,
    required this.createdAt,
    this.isIncognito = false,
  });

  factory TabModel.fromEntity(TabEntity entity) {
    return TabModel(
      id: entity.id,
      url: entity.url,
      title: entity.title,
      favicon: entity.favicon,
      createdAt: entity.createdAt,
      isIncognito: entity.isIncognito,
    );
  }

  TabEntity toEntity() {
    return TabEntity(
      id: id,
      url: url,
      title: title,
      favicon: favicon,
      createdAt: createdAt,
      isIncognito: isIncognito,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'favicon': favicon,
      'createdAt': createdAt.toIso8601String(),
      'isIncognito': isIncognito,
    };
  }

  factory TabModel.fromJson(Map<String, dynamic> json) {
    return TabModel(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String?,
      favicon: json['favicon'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isIncognito: json['isIncognito'] as bool? ?? false,
    );
  }
}

