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
        final articlesData = response.data['articles'];
        if (articlesData == null || articlesData is! List) {
          return [];
        }
        
        final articles = (articlesData as List)
            .where((json) => json != null && json is Map<String, dynamic>)
            .map((json) {
              try {
                return NewsArticleModel.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                // Skip invalid articles
                return null;
              }
            })
            .whereType<NewsArticleModel>()
            .where((article) => article.url.isNotEmpty && article.title.isNotEmpty)
            .toList();
        return articles;
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
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

