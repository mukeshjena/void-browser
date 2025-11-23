import '../../domain/entities/news_article_entity.dart';

class NewsArticleModel extends NewsArticleEntity {
  const NewsArticleModel({
    required super.id,
    required super.title,
    super.description,
    required super.url,
    super.imageUrl,
    required super.source,
    super.author,
    required super.publishedAt,
    required super.category,
  });

  factory NewsArticleModel.fromJson(Map<String, dynamic> json) {
    return NewsArticleModel(
      id: json['url'] ?? '', // Use URL as ID since API doesn't provide ID
      title: json['title'] ?? 'No Title',
      description: json['description'],
      url: json['url'] ?? '',
      imageUrl: json['urlToImage'],
      source: json['source']?['name'] ?? 'Unknown',
      author: json['author'],
      publishedAt: DateTime.parse(json['publishedAt'] ?? DateTime.now().toIso8601String()),
      category: 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'url': url,
      'urlToImage': imageUrl,
      'source': {'name': source},
      'author': author,
      'publishedAt': publishedAt.toIso8601String(),
    };
  }

  factory NewsArticleModel.fromEntity(NewsArticleEntity entity) {
    return NewsArticleModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      url: entity.url,
      imageUrl: entity.imageUrl,
      source: entity.source,
      author: entity.author,
      publishedAt: entity.publishedAt,
      category: entity.category,
    );
  }
}

