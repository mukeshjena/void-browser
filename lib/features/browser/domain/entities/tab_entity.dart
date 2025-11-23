class TabEntity {
  final String id;
  final String url;
  final String? title;
  final String? favicon;
  final DateTime createdAt;
  final bool isIncognito;

  const TabEntity({
    required this.id,
    required this.url,
    this.title,
    this.favicon,
    required this.createdAt,
    this.isIncognito = false,
  });

  TabEntity copyWith({
    String? id,
    String? url,
    String? title,
    String? favicon,
    DateTime? createdAt,
    bool? isIncognito,
  }) {
    return TabEntity(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      favicon: favicon ?? this.favicon,
      createdAt: createdAt ?? this.createdAt,
      isIncognito: isIncognito ?? this.isIncognito,
    );
  }
}

