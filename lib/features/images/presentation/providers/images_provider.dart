import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/image_remote_datasource.dart';
import '../../data/models/image_model.dart';
import '../../domain/entities/image_entity.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Provider for image remote data source
final imageRemoteDataSourceProvider = Provider<ImageRemoteDataSource>((ref) {
  final accessKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
  return ImageRemoteDataSourceImpl(dio: DioClient.instance, accessKey: accessKey);
});

// State for images with pagination
class ImagesState {
  final List<ImageEntity> images;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final DateTime? lastFetched;
  final int currentPage;
  final bool hasMore;
  final String currentQuery;

  ImagesState({
    this.images = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastFetched,
    this.currentPage = 1,
    this.hasMore = true,
    this.currentQuery = '',
  });

  ImagesState copyWith({
    List<ImageEntity>? images,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    DateTime? lastFetched,
    int? currentPage,
    bool? hasMore,
    String? currentQuery,
  }) {
    return ImagesState(
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }

  // Check if cache is valid (within 24 hours for images)
  bool get isCacheValid {
    if (lastFetched == null || images.isEmpty) return false;
    return DateTime.now().difference(lastFetched!).inHours < 24;
  }
}

// Images notifier with pagination
class ImagesNotifier extends StateNotifier<ImagesState> {
  final ImageRemoteDataSource remoteDataSource;

  ImagesNotifier(this.remoteDataSource) : super(ImagesState()) {
    // Load last state from cache on initialization
    _loadCachedState();
  }

  void _loadCachedState() {
    const cacheKey = 'images_random';
    final cachedImages = CacheService.getList<ImageEntity>(
      cacheKey,
      (json) => ImageModel.fromJson(json),
    );

    if (cachedImages != null && cachedImages.isNotEmpty) {
      state = state.copyWith(
        images: cachedImages,
        lastFetched: DateTime.now(),
        hasMore: true,
        currentQuery: '',
        currentPage: 1,
      );
    }
  }

  Future<void> loadRandomImages({bool forceRefresh = false}) async {
    const cacheKey = 'images_random';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedImages = CacheService.getList<ImageEntity>(
        cacheKey,
        (json) => ImageModel.fromJson(json),
      );

      if (cachedImages != null && cachedImages.isNotEmpty) {
        state = state.copyWith(
          images: cachedImages,
          isLoading: false,
          error: null,
          lastFetched: DateTime.now(),
          hasMore: true,
          currentQuery: '',
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
      currentQuery: '',
      images: forceRefresh ? [] : state.images, // Keep old images during refresh
    );

    try {
      final images = await remoteDataSource.getRandomImages(count: 30);
      
      // Save to cache
      await CacheService.setList(
        cacheKey,
        images,
        ApiConstants.imagesCacheTtl,
        toJson: (image) => ImageModel.fromEntity(image).toJson(),
      );

      state = state.copyWith(
        images: images,
        isLoading: false,
        lastFetched: DateTime.now(),
        hasMore: true,
      );
    } catch (e) {
      // Try to load stale cache on error
      final staleImages = CacheService.getStaleList<ImageEntity>(
        cacheKey,
        (json) => ImageModel.fromJson(json),
      );

      if (staleImages != null && staleImages.isNotEmpty) {
        state = state.copyWith(
          images: staleImages,
          isLoading: false,
          error: 'Showing cached content. ${e.toString()}',
          lastFetched: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load images: ${e.toString()}',
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      List<ImageEntity> newImages;
      String cacheKey;
      
      if (state.currentQuery.isEmpty) {
        // Load more random images
        cacheKey = 'images_random';
        newImages = await remoteDataSource.getRandomImages(count: 30);
      } else {
        // Load next page of search results
        cacheKey = 'images_search_${state.currentQuery}';
        newImages = await remoteDataSource.searchImages(
          state.currentQuery,
          perPage: 30,
          page: state.currentPage + 1,
        );
      }

      // Filter out duplicates
      final existingIds = state.images.map((img) => img.id).toSet();
      final uniqueNewImages = newImages.where((img) => !existingIds.contains(img.id)).toList();

      if (uniqueNewImages.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
      } else {
        final updatedImages = [...state.images, ...uniqueNewImages];
        
        // Update cache with new images
        await CacheService.setList(
          cacheKey,
          updatedImages,
          ApiConstants.imagesCacheTtl,
          toJson: (image) => ImageModel.fromEntity(image).toJson(),
        );

        state = state.copyWith(
          images: updatedImages,
          isLoadingMore: false,
          currentPage: state.currentPage + 1,
          hasMore: uniqueNewImages.length >= 10,
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
    if (state.currentQuery.isEmpty) {
      await loadRandomImages(forceRefresh: true);
    } else {
      await searchImages(state.currentQuery, forceRefresh: true);
    }
  }

  Future<void> searchImages(String query, {bool forceRefresh = false}) async {
    if (query.isEmpty) {
      await loadRandomImages(forceRefresh: forceRefresh);
      return;
    }

    final cacheKey = 'images_search_$query';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedImages = CacheService.getList<ImageEntity>(
        cacheKey,
        (json) => ImageModel.fromJson(json),
      );

      if (cachedImages != null && cachedImages.isNotEmpty) {
        state = state.copyWith(
          images: cachedImages,
          isLoading: false,
          error: null,
          lastFetched: DateTime.now(),
          hasMore: cachedImages.length >= 30,
          currentQuery: query,
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
      currentQuery: query,
      images: forceRefresh ? [] : state.images, // Keep old images during refresh
    );

    try {
      final images = await remoteDataSource.searchImages(query, perPage: 30);
      
      // Save to cache
      await CacheService.setList(
        cacheKey,
        images,
        ApiConstants.imagesCacheTtl,
        toJson: (image) => ImageModel.fromEntity(image).toJson(),
      );

      state = state.copyWith(
        images: images,
        isLoading: false,
        hasMore: images.length >= 30,
      );
    } catch (e) {
      // Try to load stale cache on error
      final staleImages = CacheService.getStaleList<ImageEntity>(
        cacheKey,
        (json) => ImageModel.fromJson(json),
      );

      if (staleImages != null && staleImages.isNotEmpty) {
        state = state.copyWith(
          images: staleImages,
          isLoading: false,
          error: 'Showing cached content. ${e.toString()}',
          lastFetched: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to search images: ${e.toString()}',
        );
      }
    }
  }
}

// Images provider
final imagesProvider = StateNotifierProvider<ImagesNotifier, ImagesState>((ref) {
  final remoteDataSource = ref.watch(imageRemoteDataSourceProvider);
  return ImagesNotifier(remoteDataSource);
});
