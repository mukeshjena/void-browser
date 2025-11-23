import 'cache_service.dart';

/// Cache manager for periodic cleanup and maintenance
class CacheManager {
  /// Clean old cache entries (older than 7 days)
  static Future<void> cleanOldCache() async {
    await CacheService.cleanOldCache(7);
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final size = CacheService.getCacheSize();
    return {
      'sizeBytes': size,
      'sizeMB': (size / (1024 * 1024)).toStringAsFixed(2),
      'entryCount': CacheService.cacheBox.length,
    };
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    await CacheService.clear();
  }

  /// Initialize cache manager (called on app start)
  static Future<void> init() async {
    // Clean expired cache on startup
    await CacheService.init();
    // Clean cache older than 7 days
    await cleanOldCache();
  }
}

