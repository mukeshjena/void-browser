import 'package:dio/dio.dart';
import '../models/news_article_model.dart';

abstract class NewsRemoteDataSource {
  Future<List<NewsArticleModel>> getTopHeadlines({String category = 'general'});
  Future<List<NewsArticleModel>> searchNews(String query);
}

class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  final Dio dio;
  final String apiKey;

  NewsRemoteDataSourceImpl({required this.dio, required this.apiKey});

  @override
  Future<List<NewsArticleModel>> getTopHeadlines({String category = 'general'}) async {
    try {
      // Using NewsAPI.org - Free tier: 100 requests/day
      final response = await dio.get(
        'https://newsapi.org/v2/top-headlines',
        queryParameters: {
          'apiKey': apiKey,
          'country': 'us',
          'category': category,
          'pageSize': 20,
        },
      );

      if (response.statusCode == 200) {
        final articles = (response.data['articles'] as List)
            .map((json) => NewsArticleModel.fromJson(json))
            .toList();
        return articles;
      } else {
        throw Exception('Failed to load news');
      }
    } catch (e) {
      throw Exception('Error fetching news: $e');
    }
  }

  @override
  Future<List<NewsArticleModel>> searchNews(String query) async {
    try {
      final response = await dio.get(
        'https://newsapi.org/v2/everything',
        queryParameters: {
          'apiKey': apiKey,
          'q': query,
          'pageSize': 20,
          'sortBy': 'publishedAt',
        },
      );

      if (response.statusCode == 200) {
        final articles = (response.data['articles'] as List)
            .map((json) => NewsArticleModel.fromJson(json))
            .toList();
        return articles;
      } else {
        throw Exception('Failed to search news');
      }
    } catch (e) {
      throw Exception('Error searching news: $e');
    }
  }
}

