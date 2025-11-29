import '../../domain/entities/quick_link_entity.dart';

class QuickLinkModel extends QuickLinkEntity {
  const QuickLinkModel({
    required super.id,
    required super.name,
    required super.url,
    super.iconUrl,
    required super.createdAt,
  });

  factory QuickLinkModel.fromJson(Map<String, dynamic> json) {
    return QuickLinkModel(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      iconUrl: json['iconUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'iconUrl': iconUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QuickLinkModel.fromEntity(QuickLinkEntity entity) {
    return QuickLinkModel(
      id: entity.id,
      name: entity.name,
      url: entity.url,
      iconUrl: entity.iconUrl,
      createdAt: entity.createdAt,
    );
  }

  static String getFaviconUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host;
      // Use Google's favicon service for reliable icon fetching
      return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
    } catch (e) {
      // Fallback to a default icon if URL parsing fails
      return 'https://www.google.com/s2/favicons?domain=example.com&sz=64';
    }
  }
}

