class ImageEntity {
  final String id;
  final String regularUrl;
  final String smallUrl;
  final String thumbUrl;
  final String? altDescription;
  final String photographerName;
  final String photographerUsername;
  final String photographerProfileUrl;

  const ImageEntity({
    required this.id,
    required this.regularUrl,
    required this.smallUrl,
    required this.thumbUrl,
    this.altDescription,
    required this.photographerName,
    required this.photographerUsername,
    required this.photographerProfileUrl,
  });
}

