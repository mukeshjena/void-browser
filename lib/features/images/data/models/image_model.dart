import '../../domain/entities/image_entity.dart';

class ImageModel extends ImageEntity {
  const ImageModel({
    required super.id,
    required super.regularUrl,
    required super.smallUrl,
    required super.thumbUrl,
    super.altDescription,
    required super.photographerName,
    required super.photographerUsername,
    required super.photographerProfileUrl,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'] ?? '',
      regularUrl: json['urls']?['regular'] ?? '',
      smallUrl: json['urls']?['small'] ?? '',
      thumbUrl: json['urls']?['thumb'] ?? '',
      altDescription: json['alt_description'],
      photographerName: json['user']?['name'] ?? 'Unknown',
      photographerUsername: json['user']?['username'] ?? '',
      photographerProfileUrl: json['user']?['links']?['html'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'urls': {
        'regular': regularUrl,
        'small': smallUrl,
        'thumb': thumbUrl,
      },
      'alt_description': altDescription,
      'user': {
        'name': photographerName,
        'username': photographerUsername,
        'links': {
          'html': photographerProfileUrl,
        },
      },
    };
  }

  factory ImageModel.fromEntity(ImageEntity entity) {
    return ImageModel(
      id: entity.id,
      regularUrl: entity.regularUrl,
      smallUrl: entity.smallUrl,
      thumbUrl: entity.thumbUrl,
      altDescription: entity.altDescription,
      photographerName: entity.photographerName,
      photographerUsername: entity.photographerUsername,
      photographerProfileUrl: entity.photographerProfileUrl,
    );
  }
}

