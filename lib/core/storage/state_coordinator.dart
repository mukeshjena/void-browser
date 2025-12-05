import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_manager.dart';
import 'cache_manager.dart';

/// State coordinator for managing all state providers
/// Provides centralized state management coordination
class StateCoordinator {
  static StateCoordinator? _instance;
  static StateCoordinator get instance {
    _instance ??= StateCoordinator._internal();
    return _instance!;
  }

  StateCoordinator._internal();

  final List<String> _initializedProviders = [];
  bool _initialized = false;

  /// Initialize state coordinator
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize storage manager first
    await StorageManager.instance.initialize();

    _initialized = true;
  }

  /// Check if coordinator is initialized
  bool get isInitialized => _initialized;

  /// Register a provider as initialized
  void registerProvider(String providerName) {
    if (!_initializedProviders.contains(providerName)) {
      _initializedProviders.add(providerName);
    }
  }

  /// Get list of initialized providers
  List<String> get initializedProviders => List.unmodifiable(_initializedProviders);

  /// Clear all state (useful for logout or reset)
  Future<void> clearAllState() async {
    // Clear all storage
    await StorageManager.instance.clearAllStorage();

    // Clear provider registrations
    _initializedProviders.clear();
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final storageStats = await StorageManager.instance.getStorageStats();
    final cacheStats = CacheManager.getCacheStats();

    return {
      'storage': storageStats,
      'cache': cacheStats,
      'providers': {
        'initialized': _initializedProviders.length,
        'list': _initializedProviders,
      },
      'status': {
        'initialized': _initialized,
        'storageInitialized': StorageManager.instance.isInitialized,
      },
    };
  }

  /// Dispose coordinator
  Future<void> dispose() async {
    await StorageManager.instance.dispose();
    _initializedProviders.clear();
    _initialized = false;
  }
}

/// Provider for StateCoordinator
final stateCoordinatorProvider = Provider<StateCoordinator>((ref) {
  return StateCoordinator.instance;
});

/// Provider for StorageManager
final storageManagerProvider = Provider<StorageManager>((ref) {
  return StorageManager.instance;
});
