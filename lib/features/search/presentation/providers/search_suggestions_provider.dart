import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/constants/storage_constants.dart';
import 'search_history_provider.dart';

/// Search suggestions state
class SearchSuggestionsState {
  final List<String> suggestions;
  final bool isLoading;
  final String? error;

  SearchSuggestionsState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  SearchSuggestionsState copyWith({
    List<String>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return SearchSuggestionsState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Search suggestions notifier
class SearchSuggestionsNotifier extends StateNotifier<SearchSuggestionsState> {
  final Ref _ref;

  SearchSuggestionsNotifier(this._ref) : super(SearchSuggestionsState());

  /// Get suggestions for a query
  Future<void> getSuggestions(String query) async {
    if (query.trim().isEmpty) {
      // Return recent searches from history
      final historyState = _ref.read(searchHistoryProvider);
      final recentSearches = historyState.history
          .take(10)
          .map((item) => item.query)
          .toList();
      state = state.copyWith(suggestions: recentSearches);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      // First, try to get from search history
      final historyNotifier = _ref.read(searchHistoryProvider.notifier);
      final historySuggestions = historyNotifier
          .getSuggestions(query)
          .map((item) => item.query)
          .toList();

      // Try to get cached suggestions
      final cacheKey = '${StorageConstants.keySearchSuggestionsCache}_${query.toLowerCase()}';
      final cachedSuggestions = CacheService.getList<String>(
        cacheKey,
        (json) => json['suggestion'] as String,
      );

      // Combine history and cached suggestions, remove duplicates
      final allSuggestions = <String>{};
      allSuggestions.addAll(historySuggestions);
      if (cachedSuggestions != null) {
        allSuggestions.addAll(cachedSuggestions);
      }

      // Limit to 10 suggestions
      final suggestions = allSuggestions.take(10).toList();

      state = state.copyWith(
        suggestions: suggestions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get suggestions: $e',
      );
    }
  }

  /// Cache suggestions for a query
  Future<void> cacheSuggestions(String query, List<String> suggestions) async {
    try {
      final cacheKey = '${StorageConstants.keySearchSuggestionsCache}_${query.toLowerCase()}';
      await CacheService.setList(
        cacheKey,
        suggestions,
        60, // Cache for 60 minutes
        toJson: (suggestion) => {'suggestion': suggestion},
      );
    } catch (e) {
      // Silently fail cache write
    }
  }

  /// Clear suggestions
  void clearSuggestions() {
    state = state.copyWith(suggestions: []);
  }
}

/// Provider for search suggestions
final searchSuggestionsProvider =
    StateNotifierProvider<SearchSuggestionsNotifier, SearchSuggestionsState>(
        (ref) {
  return SearchSuggestionsNotifier(ref);
});

