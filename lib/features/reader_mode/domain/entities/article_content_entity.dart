class ArticleContentEntity {
  final String title;
  final String content;
  final String? author;
  final String? excerpt;
  final String url;

  ArticleContentEntity({
    required this.title,
    required this.content,
    this.author,
    this.excerpt,
    required this.url,
  });
}

