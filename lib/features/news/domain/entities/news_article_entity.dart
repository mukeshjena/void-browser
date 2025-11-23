class NewsArticleEntity {
  final String id;
  final String title;
  final String? description;
  final String url;
  final String? imageUrl;
  final String source;
  final String? author;
  final DateTime publishedAt;
  final String category;

  const NewsArticleEntity({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    this.imageUrl,
    required this.source,
    this.author,
    required this.publishedAt,
    required this.category,
  });
}

