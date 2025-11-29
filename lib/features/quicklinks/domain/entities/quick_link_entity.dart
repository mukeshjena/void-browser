class QuickLinkEntity {
  final String id;
  final String name;
  final String url;
  final String? iconUrl;
  final DateTime createdAt;

  const QuickLinkEntity({
    required this.id,
    required this.name,
    required this.url,
    this.iconUrl,
    required this.createdAt,
  });

  QuickLinkEntity copyWith({
    String? id,
    String? name,
    String? url,
    String? iconUrl,
    DateTime? createdAt,
  }) {
    return QuickLinkEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      iconUrl: iconUrl ?? this.iconUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

