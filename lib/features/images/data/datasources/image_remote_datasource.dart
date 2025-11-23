import 'package:dio/dio.dart';
import '../models/image_model.dart';

abstract class ImageRemoteDataSource {
  Future<List<ImageModel>> getRandomImages({int count = 20});
  Future<List<ImageModel>> searchImages(String query, {int perPage = 20, int page = 1});
}

class ImageRemoteDataSourceImpl implements ImageRemoteDataSource {
  final Dio dio;
  final String accessKey;

  ImageRemoteDataSourceImpl({required this.dio, required this.accessKey});

  static const String baseUrl = 'https://api.unsplash.com';

  @override
  Future<List<ImageModel>> getRandomImages({int count = 20}) async {
    try {
      final response = await dio.get(
        '$baseUrl/photos/random',
        queryParameters: {'count': count},
        options: Options(
          headers: {'Authorization': 'Client-ID $accessKey'},
        ),
      );

      if (response.statusCode == 200) {
        final images = (response.data as List)
            .map((json) => ImageModel.fromJson(json))
            .toList();
        return images;
      } else {
        throw Exception('Failed to load images');
      }
    } catch (e) {
      throw Exception('Error fetching random images: $e');
    }
  }

  @override
  Future<List<ImageModel>> searchImages(String query, {int perPage = 20, int page = 1}) async {
    try {
      final response = await dio.get(
        '$baseUrl/search/photos',
        queryParameters: {
          'query': query,
          'per_page': perPage,
          'page': page,
        },
        options: Options(
          headers: {'Authorization': 'Client-ID $accessKey'},
        ),
      );

      if (response.statusCode == 200) {
        final images = (response.data['results'] as List)
            .map((json) => ImageModel.fromJson(json))
            .toList();
        return images;
      } else {
        throw Exception('Failed to search images');
      }
    } catch (e) {
      throw Exception('Error searching images: $e');
    }
  }
}

