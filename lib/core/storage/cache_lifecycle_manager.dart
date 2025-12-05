import 'dart:async';
import 'cache_service.dart';
import 'cache_manager.dart';

/// Cache lifecycle manager for automatic cache maintenance
class CacheLifecycleManager {
  static CacheLifecycleManager? _instance;
  static CacheLifecycleManager get instance {
    _instance ??= CacheLifecycleManager._internal();
    return _instance!;
  }

  CacheLifecycleManager._internal();

  Timer? _cleanupTimer;
  Timer? _oldCacheTimer;
  Timer? _statsTimer;
  bool _isRunning = false;

  /// Start automatic cache lifecycle management
  /// - Cleans expired cache every hour
  /// - Cleans old cache (7+ days) daily
  /// - Updates statistics periodically
  void start() {
    if (_isRunning) return;

    _isRunning = true;

    // Clean expired cache every hour
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanExpiredCache();
    });

    // Clean old cache daily
    _oldCacheTimer = Timer.periodic(const Duration(days: 1), (timer) {
      CacheManager.cleanOldCache();
    });

    // Update stats every 5 minutes (for monitoring)
    _statsTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateStats();
    });
  }

  /// Stop automatic cache lifecycle management
  void stop() {
    _cleanupTimer?.cancel();
    _oldCacheTimer?.cancel();
    _statsTimer?.cancel();
    _cleanupTimer = null;
    _oldCacheTimer = null;
    _statsTimer = null;
    _isRunning = false;
  }

  /// Clean expired cache entries
  Future<void> _cleanExpiredCache() async {
    try {
      final keysToDelete = <String>[];
      final keys = CacheService.cacheBox.keys.toList();

      for (var key in keys) {
        try {
          final entryJson = CacheService.cacheBox.get(key);
          if (entryJson == null) {
            keysToDelete.add(key.toString());
            continue;
          }

          final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
          if (entry.isExpired) {
            keysToDelete.add(key.toString());
          }
        } catch (e) {
          keysToDelete.add(key.toString());
        }
      }

      // Delete expired entries in batches
      if (keysToDelete.isNotEmpty) {
        for (var key in keysToDelete) {
          await CacheService.cacheBox.delete(key).catchError((_) {});
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Update cache statistics (for monitoring)
  void _updateStats() {
    try {
      //final stats = CacheManager.getCacheStats();
      // Stats are available via CacheManager.getCacheStats()
      // This can be extended to notify listeners or update UI
    } catch (e) {
      // Silently fail
    }
  }

  /// Get current status
  bool get isRunning => _isRunning;

  /// Dispose lifecycle manager
  void dispose() {
    stop();
  }
}
