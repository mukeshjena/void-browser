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
    try {
      // Safely parse publishedAt
      DateTime publishedAt;
      try {
        if (json['publishedAt'] != null && json['publishedAt'].toString().isNotEmpty) {
          publishedAt = DateTime.parse(json['publishedAt'].toString());
        } else {
          publishedAt = DateTime.now();
        }
      } catch (e) {
        publishedAt = DateTime.now();
      }

      return NewsArticleModel(
        id: json['url']?.toString() ?? '', // Use URL as ID since API doesn't provide ID
        title: json['title']?.toString() ?? 'No Title',
        description: json['description']?.toString(),
        url: json['url']?.toString() ?? '',
        imageUrl: json['urlToImage']?.toString(),
        source: json['source']?['name']?.toString() ?? 'Unknown',
        author: json['author']?.toString(),
        publishedAt: publishedAt,
        category: 'general',
      );
    } catch (e) {
      // Return a default article if parsing fails
      return NewsArticleModel(
        id: '',
        title: 'Error loading article',
        description: null,
        url: '',
        imageUrl: null,
        source: 'Unknown',
        author: null,
        publishedAt: DateTime.now(),
        category: 'general',
      );
    }
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

