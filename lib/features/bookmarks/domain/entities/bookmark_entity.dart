class BookmarkEntity {
  final String id;
  final String title;
  final String url;
  final String? faviconUrl;
  final String? folderName;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookmarkEntity({
    required this.id,
    required this.title,
    required this.url,
    this.faviconUrl,
    this.folderName,
    required this.createdAt,
    required this.updatedAt,
  });

  BookmarkEntity copyWith({
    String? id,
    String? title,
    String? url,
    String? faviconUrl,
    String? folderName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookmarkEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      folderName: folderName ?? this.folderName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

