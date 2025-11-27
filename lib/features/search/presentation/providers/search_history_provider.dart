import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/storage/hive_config.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../data/models/search_history_model.dart';
import '../../domain/entities/search_history_entity.dart';

/// Search history state
class SearchHistoryState {
  final List<SearchHistoryEntity> history;
  final bool isLoading;
  final String? error;

  SearchHistoryState({
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  SearchHistoryState copyWith({
    List<SearchHistoryEntity>? history,
    bool? isLoading,
    String? error,
  }) {
    return SearchHistoryState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Search history notifier
class SearchHistoryNotifier extends StateNotifier<SearchHistoryState> {
  final Box _historyBox;
  static const int _maxHistoryItems = 100; // Limit history to 100 items
  final _uuid = const Uuid();

  SearchHistoryNotifier(this._historyBox) : super(SearchHistoryState()) {
    _loadHistory();
  }

  /// Load history from Hive (optimized with batching)
  Future<void> _loadHistory() async {
    try {
      state = state.copyWith(isLoading: true);
      
      // Load in batches to avoid blocking UI
      final historyList = <SearchHistoryEntity>[];
      final keys = _historyBox.keys.toList();
      
      // Process in batches of 50 to avoid blocking
      const batchSize = 50;
      for (int i = 0; i < keys.length; i += batchSize) {
        final batch = keys.skip(i).take(batchSize);
        
        for (var key in batch) {
          try {
            final modelJson = _historyBox.get(key) as Map<String, dynamic>?;
            if (modelJson != null) {
              final model = SearchHistoryModel.fromJson(modelJson);
              historyList.add(SearchHistoryEntity(
                id: model.id,
                query: model.query,
                url: model.url,
                timestamp: model.timestamp,
                type: model.type,
              ));
            }
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
        
        // Yield control to UI thread every batch
        if (i + batchSize < keys.length) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      // Sort by timestamp (newest first) - this is fast for < 100 items
      historyList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = state.copyWith(
        history: historyList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load history: $e',
      );
    }
  }

  /// Add search query to history (optimized - doesn't reload full history)
  Future<void> addSearchQuery(String query) async {
    if (query.trim().isEmpty) return;

    try {
      // Check if it's a URL
      final isUrl = query.startsWith('http://') || query.startsWith('https://');
      final type = isUrl ? 'url' : 'search';

      final entity = SearchHistoryEntity(
        id: _uuid.v4(),
        query: query.trim(),
        url: isUrl ? query.trim() : null,
        timestamp: DateTime.now(),
        type: type,
      );

      // Save to Hive (non-blocking)
      final model = SearchHistoryModel(
        id: entity.id,
        query: entity.query,
        url: entity.url,
        timestamp: entity.timestamp,
        type: entity.type,
      );

      // Save asynchronously without blocking
      _historyBox.put(entity.id, model.toJson()).catchError((_) {});

      // Update state immediately (optimistic update)
      final updatedHistory = [entity, ...state.history];
      updatedHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      state = state.copyWith(history: updatedHistory);

      // Limit history size in background
      _limitHistorySize().catchError((_) {});
    } catch (e) {
      // Silently fail - don't block UI
    }
  }

  /// Add URL navigation to history
  Future<void> addUrlNavigation(String url) async {
    if (url.trim().isEmpty) return;
    await addSearchQuery(url);
  }

  /// Delete a history item (optimized - optimistic update)
  Future<void> deleteHistoryItem(String id) async {
    try {
      // Delete from storage (non-blocking)
      _historyBox.delete(id).catchError((_) {});
      
      // Update state immediately (optimistic update)
      final updatedHistory = state.history.where((item) => item.id != id).toList();
      state = state.copyWith(history: updatedHistory);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete: $e');
    }
  }

  /// Clear all history (optimized)
  Future<void> clearHistory() async {
    try {
      // Clear storage in background (non-blocking)
      _historyBox.clear().catchError((_) {
        // Silently fail - return 0 as fallback
        return 0;
      });
      
      // Update state immediately (optimistic update)
      state = state.copyWith(history: []);
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear history: $e');
    }
  }

  /// Get search suggestions based on query
  List<SearchHistoryEntity> getSuggestions(String query) {
    if (query.trim().isEmpty) {
      // Return recent searches (last 10)
      return state.history.take(10).toList();
    }

    final lowerQuery = query.toLowerCase();
    return state.history
        .where((item) =>
            item.query.toLowerCase().contains(lowerQuery) ||
            (item.url != null && item.url!.toLowerCase().contains(lowerQuery)))
        .take(10)
        .toList();
  }

  /// Limit history size to max items (optimized)
  Future<void> _limitHistorySize() async {
    if (state.history.length <= _maxHistoryItems) return;

    // Delete old items (keep only the most recent)
    final itemsToDelete = state.history.skip(_maxHistoryItems).toList();

    // Delete old items in background (non-blocking)
    for (var item in itemsToDelete) {
      _historyBox.delete(item.id).catchError((_) {
        // Silently fail
        return;
      });
    }

    // Update state to reflect trimmed history
    final trimmedHistory = state.history.take(_maxHistoryItems).toList();
    state = state.copyWith(history: trimmedHistory);
  }
}

/// Provider for search history box
final searchHistoryBoxProvider = FutureProvider<Box>((ref) async {
  return await HiveConfig.openBox(StorageConstants.historyBox);
});

/// Provider for search history notifier
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, SearchHistoryState>((ref) {
  final boxAsync = ref.watch(searchHistoryBoxProvider);
  
  return boxAsync.when(
    data: (box) => SearchHistoryNotifier(box),
    loading: () => throw Exception('History box not loaded'),
    error: (error, stack) => throw Exception('Failed to load history box: $error'),
  );
});

