import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/datasources/news_remote_datasource.dart';
import '../../data/models/news_article_model.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/constants/api_constants.dart';

// Provider for news remote data source
final newsRemoteDataSourceProvider = Provider<NewsRemoteDataSource>((ref) {
  final apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
  return NewsRemoteDataSourceImpl(dio: DioClient.instance, apiKey: apiKey);
});

// State for news with pagination
class NewsState {
  final List<NewsArticleEntity> articles;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final DateTime? lastFetched;
  final int currentPage;
  final bool hasMore;

  NewsState({
    this.articles = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastFetched,
    this.currentPage = 1,
    this.hasMore = true,
  });

  NewsState copyWith({
    List<NewsArticleEntity>? articles,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    DateTime? lastFetched,
    int? currentPage,
    bool? hasMore,
  }) {
    return NewsState(
      articles: articles ?? this.articles,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  // Check if cache is valid (within 30 minutes)
  bool get isCacheValid {
    if (lastFetched == null || articles.isEmpty) return false;
    return DateTime.now().difference(lastFetched!).inMinutes < 30;
  }
}

// News notifier with pagination support
class NewsNotifier extends StateNotifier<NewsState> {
  final NewsRemoteDataSource remoteDataSource;
  String _currentCategory = 'general';

  NewsNotifier(this.remoteDataSource) : super(NewsState()) {
    // Load last state from cache on initialization
    _loadCachedState();
  }

  void _loadCachedState() {
    // Try to load last viewed category from cache
    const cacheKey = 'news_headlines_general';
    final cachedArticles = CacheService.getList<NewsArticleEntity>(
      cacheKey,
      (json) => NewsArticleModel.fromJson(json),
    );

    if (cachedArticles != null && cachedArticles.isNotEmpty) {
      state = state.copyWith(
        articles: cachedArticles,
        lastFetched: DateTime.now(),
        hasMore: cachedArticles.length >= 10,
      );
    }
  }

  Future<void> loadTopHeadlines({String category = 'general', bool forceRefresh = false}) async {
    _currentCategory = category;
    final cacheKey = 'news_headlines_$category';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedArticles = CacheService.getList<NewsArticleEntity>(
        cacheKey,
        (json) => NewsArticleModel.fromJson(json),
      );

      if (cachedArticles != null && cachedArticles.isNotEmpty) {
        state = state.copyWith(
          articles: cachedArticles,
          isLoading: false,
          error: null,
          lastFetched: DateTime.now(),
          hasMore: cachedArticles.length >= 10,
          currentPage: 1,
        );
        return;
      }
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: 1,
      hasMore: true,
      articles: forceRefresh ? [] : state.articles, // Keep old articles during refresh
    );

    try {
      final articles = await remoteDataSource.getTopHeadlines(category: category);
      
      // Save to cache (non-blocking)
      CacheService.setList(
        cacheKey,
        articles,
        ApiConstants.newsCacheTtl,
        toJson: (article) => NewsArticleModel.fromEntity(article).toJson(),
      ).catchError((_) {});

      state = state.copyWith(
        articles: articles,
        isLoading: false,
        lastFetched: DateTime.now(),
        hasMore: articles.length >= 10,
      );
    } catch (e) {
      // Try to load stale cache on error
      final staleArticles = CacheService.getStaleList<NewsArticleEntity>(
        cacheKey,
        (json) => NewsArticleModel.fromJson(json),
      );

      if (staleArticles != null && staleArticles.isNotEmpty) {
        state = state.copyWith(
          articles: staleArticles,
          isLoading: false,
          error: 'Showing cached content. ${e.toString()}',
          lastFetched: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load news: ${e.toString()}',
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      // Load next page
      final newArticles = await remoteDataSource.getTopHeadlines(
        category: _currentCategory,
      );
      
      // Filter out duplicates
      final existingIds = state.articles.map((a) => a.url).toSet();
      final uniqueNewArticles = newArticles.where((a) => !existingIds.contains(a.url)).toList();

      if (uniqueNewArticles.isEmpty) {
        // No more unique articles
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
      } else {
        final updatedArticles = [...state.articles, ...uniqueNewArticles];
        
        // Update cache with new articles
        final cacheKey = 'news_headlines_$_currentCategory';
        await CacheService.setList(
          cacheKey,
          updatedArticles,
          ApiConstants.newsCacheTtl,
          toJson: (article) => NewsArticleModel.fromEntity(article).toJson(),
        );

        state = state.copyWith(
          articles: updatedArticles,
          isLoadingMore: false,
          currentPage: state.currentPage + 1,
          hasMore: uniqueNewArticles.length >= 5,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load more: ${e.toString()}',
      );
    }
  }

  Future<void> refresh() async {
    await loadTopHeadlines(category: _currentCategory, forceRefresh: true);
  }

  Future<void> loadNewsByCategory(String category, {bool forceRefresh = false}) async {
    await loadTopHeadlines(category: category, forceRefresh: forceRefresh);
  }
}

// Provider for news notifier
final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  return NewsNotifier(ref.watch(newsRemoteDataSourceProvider));
});
