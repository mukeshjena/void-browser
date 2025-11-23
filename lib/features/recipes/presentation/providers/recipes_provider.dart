import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/recipe_remote_datasource.dart';
import '../../data/models/recipe_model.dart';
import '../../domain/entities/recipe_entity.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/constants/api_constants.dart';

// Provider for recipe remote data source
final recipeRemoteDataSourceProvider = Provider<RecipeRemoteDataSource>((ref) {
  return RecipeRemoteDataSourceImpl(dio: DioClient.instance);
});

// State for recipes with pagination
class RecipesState {
  final List<RecipeEntity> recipes;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final DateTime? lastFetched;
  final bool hasMore;

  RecipesState({
    this.recipes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastFetched,
    this.hasMore = true,
  });

  RecipesState copyWith({
    List<RecipeEntity>? recipes,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    DateTime? lastFetched,
    bool? hasMore,
  }) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  // Check if cache is valid (within 24 hours for recipes)
  bool get isCacheValid {
    if (lastFetched == null || recipes.isEmpty) return false;
    return DateTime.now().difference(lastFetched!).inHours < 24;
  }
}

// Recipes notifier with pagination
class RecipesNotifier extends StateNotifier<RecipesState> {
  final RecipeRemoteDataSource remoteDataSource;

  RecipesNotifier(this.remoteDataSource) : super(RecipesState()) {
    // Load last state from cache on initialization
    _loadCachedState();
  }

  void _loadCachedState() {
    const cacheKey = 'recipes_random';
    final cachedRecipes = CacheService.getList<RecipeEntity>(
      cacheKey,
      (json) => RecipeModel.fromJson(json),
    );

    if (cachedRecipes != null && cachedRecipes.isNotEmpty) {
      state = state.copyWith(
        recipes: cachedRecipes,
        lastFetched: DateTime.now(),
        hasMore: true,
      );
    }
  }

  Future<void> loadRandomRecipes({bool forceRefresh = false}) async {
    const cacheKey = 'recipes_random';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedRecipes = CacheService.getList<RecipeEntity>(
        cacheKey,
        (json) => RecipeModel.fromJson(json),
      );

      if (cachedRecipes != null && cachedRecipes.isNotEmpty) {
        state = state.copyWith(
          recipes: cachedRecipes,
          isLoading: false,
          error: null,
          lastFetched: DateTime.now(),
          hasMore: true,
        );
        return;
      }
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      hasMore: true,
      recipes: forceRefresh ? [] : state.recipes, // Keep old recipes during refresh
    );

    try {
      final recipes = await remoteDataSource.getRandomRecipes();
      
      // Save to cache
      await CacheService.setList(
        cacheKey,
        recipes,
        ApiConstants.recipesCacheTtl,
        toJson: (recipe) => RecipeModel.fromEntity(recipe).toJson(),
      );

      state = state.copyWith(
        recipes: recipes,
        isLoading: false,
        lastFetched: DateTime.now(),
        hasMore: true,
      );
    } catch (e) {
      // Try to load stale cache on error
      final staleRecipes = CacheService.getStaleList<RecipeEntity>(
        cacheKey,
        (json) => RecipeModel.fromJson(json),
      );

      if (staleRecipes != null && staleRecipes.isNotEmpty) {
        state = state.copyWith(
          recipes: staleRecipes,
          isLoading: false,
          error: 'Showing cached content. ${e.toString()}',
          lastFetched: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load recipes: ${e.toString()}',
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      // TheMealDB API returns 10 random recipes each call
      final newRecipes = await remoteDataSource.getRandomRecipes();

      // Filter out duplicates
      final existingIds = state.recipes.map((r) => r.id).toSet();
      final uniqueNewRecipes = newRecipes.where((r) => !existingIds.contains(r.id)).toList();

      if (uniqueNewRecipes.isEmpty) {
        // Very unlikely, but handle it
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
      } else {
        final updatedRecipes = [...state.recipes, ...uniqueNewRecipes];
        
        // Update cache with new recipes
        const cacheKey = 'recipes_random';
        await CacheService.setList(
          cacheKey,
          updatedRecipes,
          ApiConstants.recipesCacheTtl,
          toJson: (recipe) => RecipeModel.fromEntity(recipe).toJson(),
        );

        state = state.copyWith(
          recipes: updatedRecipes,
          isLoadingMore: false,
          hasMore: true, // Always more random recipes available
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
    await loadRandomRecipes(forceRefresh: true);
  }

  Future<void> searchRecipes(String query) async {
    if (query.isEmpty) {
      await loadRandomRecipes();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      hasMore: false, // No pagination for search
      recipes: [],
    );

    try {
      final recipes = await remoteDataSource.searchRecipes(query);
      state = state.copyWith(
        recipes: recipes,
        isLoading: false,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to search recipes: ${e.toString()}',
      );
    }
  }

  Future<void> loadRecipesByCategory(String category) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      hasMore: false, // No pagination for category
      recipes: [],
    );

    try {
      final recipes = await remoteDataSource.getRecipesByCategory(category);
      state = state.copyWith(
        recipes: recipes,
        isLoading: false,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load recipes: ${e.toString()}',
      );
    }
  }
}

// Recipes provider
final recipesProvider = StateNotifierProvider<RecipesNotifier, RecipesState>((ref) {
  final remoteDataSource = ref.watch(recipeRemoteDataSourceProvider);
  return RecipesNotifier(remoteDataSource);
});
