import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/news_remote_datasource.dart';
import '../../data/models/news_article_model.dart';
import '../../domain/entities/news_article_entity.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../main.dart';

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
  final SharedPreferences _prefs;
  String _currentCategory = 'general';

  NewsNotifier(this.remoteDataSource, this._prefs) : super(NewsState()) {
    // Load last state from cache and preferences on initialization
    _loadCachedState();
  }

  Future<void> _loadCachedState() async {
    // Load cache asynchronously to avoid blocking initialization
    Future.microtask(() async {
      try {
        // Load last selected category from preferences
        final lastCategory = _prefs.getString(StorageConstants.keyNewsLastCategory) ?? 'general';
        _currentCategory = lastCategory;
        
        // Try to load last viewed category from cache with metadata
        final cacheKey = 'news_headlines_$_currentCategory';
        final cacheResult = CacheService.getListWithMetadata<NewsArticleEntity>(
          cacheKey,
          (json) => NewsArticleModel.fromJson(json),
        );

        if (cacheResult != null && cacheResult.data.isNotEmpty) {
          // Update state asynchronously
          Future.microtask(() {
            state = state.copyWith(
              articles: cacheResult.data,
              lastFetched: cacheResult.fetchedAt, // Preserve original fetch time
              hasMore: cacheResult.data.length >= 10,
              isLoading: false,
            );
          });
        }
      } catch (e) {
        // Silently fail - will load fresh data
      }
    });
  }

  /// Save selected category to preferences
  Future<void> _saveSelectedCategory(String category) async {
    try {
      await _prefs.setString(StorageConstants.keyNewsLastCategory, category);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadTopHeadlines({String category = 'general', bool forceRefresh = false}) async {
    _currentCategory = category;
    await _saveSelectedCategory(category);
    final cacheKey = 'news_headlines_$category';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cacheResult = CacheService.getListWithMetadata<NewsArticleEntity>(
        cacheKey,
        (json) => NewsArticleModel.fromJson(json),
      );

      if (cacheResult != null && cacheResult.data.isNotEmpty) {
        state = state.copyWith(
          articles: cacheResult.data,
          isLoading: false,
          error: null,
          lastFetched: cacheResult.fetchedAt, // Preserve original fetch time
          hasMore: cacheResult.data.length >= 10,
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
        // Try to get the original fetch time from cache entry
        try {
          final entryJson = CacheService.cacheBox.get(cacheKey);
          if (entryJson != null) {
            final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
            state = state.copyWith(
              articles: staleArticles,
              isLoading: false,
              error: 'Showing cached content. ${e.toString()}',
              lastFetched: entry.fetchedAt,
            );
          } else {
            state = state.copyWith(
              articles: staleArticles,
              isLoading: false,
              error: 'Showing cached content. ${e.toString()}',
              lastFetched: DateTime.now(),
            );
          }
        } catch (_) {
          state = state.copyWith(
            articles: staleArticles,
            isLoading: false,
            error: 'Showing cached content. ${e.toString()}',
            lastFetched: DateTime.now(),
          );
        }
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
        
        // Update cache with new articles (non-blocking)
        final cacheKey = 'news_headlines_$_currentCategory';
        CacheService.setList(
          cacheKey,
          updatedArticles,
          ApiConstants.newsCacheTtl,
          toJson: (article) => NewsArticleModel.fromEntity(article).toJson(),
        ).catchError((_) {}); // Non-blocking cache write

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

  /// Clear all news cache
  Future<void> clearCache() async {
    try {
      await CacheService.clearCacheByPattern('news_headlines_*');
      state = state.copyWith(
        articles: [],
        lastFetched: null,
        currentPage: 1,
        hasMore: true,
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Get current category
  String get currentCategory => _currentCategory;
}

// Provider for news notifier
final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  // Get SharedPreferences from the provider defined in main.dart
  final prefs = ref.watch(sharedPreferencesProvider);
  return NewsNotifier(
    ref.watch(newsRemoteDataSourceProvider),
    prefs,
  );
});
