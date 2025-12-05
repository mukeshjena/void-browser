import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_constants.dart';
import 'hive_config.dart';
import 'cache_manager.dart';

/// Centralized storage manager for coordinating Hive and SharedPreferences
/// Provides unified interface for all storage operations
class StorageManager {
  static StorageManager? _instance;
  static StorageManager get instance {
    _instance ??= StorageManager._internal();
    return _instance!;
  }

  StorageManager._internal();

  SharedPreferences? _prefs;
  final Map<String, Box> _openBoxes = {};
  bool _initialized = false;

  /// Initialize storage manager
  /// Must be called before using any storage operations
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Hive
      await HiveConfig.init();
      await HiveConfig.openAllBoxes();

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Initialize cache
      await CacheManager.init();

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize StorageManager: $e');
    }
  }

  /// Check if storage is initialized
  bool get isInitialized => _initialized;

  /// Get SharedPreferences instance
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageManager not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  /// Get Hive box by name
  Future<Box> getBox(String boxName) async {
    if (!_initialized) {
      await initialize();
    }

    if (_openBoxes.containsKey(boxName)) {
      return _openBoxes[boxName]!;
    }

    final box = await HiveConfig.openBox(boxName);
    _openBoxes[boxName] = box;
    return box;
  }

  /// Get specific boxes
  Future<Box> get bookmarksBox => getBox(StorageConstants.bookmarksBox);
  Future<Box> get tabsBox => getBox(StorageConstants.tabsBox);
  Future<Box> get downloadsBox => getBox(StorageConstants.downloadsBox);
  Future<Box> get settingsBox => getBox(StorageConstants.settingsBox);
  Future<Box> get cacheBox => getBox(StorageConstants.cacheBox);
  Future<Box> get historyBox => getBox(StorageConstants.historyBox);
  Future<Box> get filtersBox => getBox(StorageConstants.filtersBox);

  /// Save value to SharedPreferences
  Future<bool> savePref(String key, dynamic value) async {
    if (value is String) {
      return await prefs.setString(key, value);
    } else if (value is int) {
      return await prefs.setInt(key, value);
    } else if (value is double) {
      return await prefs.setDouble(key, value);
    } else if (value is bool) {
      return await prefs.setBool(key, value);
    } else if (value is List<String>) {
      return await prefs.setStringList(key, value);
    }
    return false;
  }

  /// Get value from SharedPreferences
  T? getPref<T>(String key, [T? defaultValue]) {
    if (T == String) {
      return (prefs.getString(key) ?? defaultValue) as T?;
    } else if (T == int) {
      return (prefs.getInt(key) ?? defaultValue) as T?;
    } else if (T == double) {
      return (prefs.getDouble(key) ?? defaultValue) as T?;
    } else if (T == bool) {
      return (prefs.getBool(key) ?? defaultValue) as T?;
    } else if (T == List<String>) {
      return (prefs.getStringList(key) ?? defaultValue) as T?;
    }
    return defaultValue;
  }

  /// Remove preference
  Future<bool> removePref(String key) async {
    return await prefs.remove(key);
  }

  /// Clear all preferences
  Future<bool> clearPrefs() async {
    return await prefs.clear();
  }

  /// Save to Hive box
  Future<void> saveToBox(String boxName, String key, dynamic value) async {
    final box = await getBox(boxName);
    await box.put(key, value);
  }

  /// Get from Hive box
  T? getFromBox<T>(String boxName, String key) {
    try {
      final box = _openBoxes[boxName];
      if (box == null) return null;
      return box.get(key) as T?;
    } catch (e) {
      return null;
    }
  }

  /// Delete from Hive box
  Future<void> deleteFromBox(String boxName, String key) async {
    final box = await getBox(boxName);
    await box.delete(key);
  }

  /// Clear Hive box
  Future<void> clearBox(String boxName) async {
    final box = await getBox(boxName);
    await box.clear();
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final stats = <String, dynamic>{};

    // Hive boxes stats
    final boxes = [
      StorageConstants.bookmarksBox,
      StorageConstants.tabsBox,
      StorageConstants.downloadsBox,
      StorageConstants.settingsBox,
      StorageConstants.cacheBox,
      StorageConstants.historyBox,
      StorageConstants.filtersBox,
    ];

    int totalHiveSize = 0;
    int totalHiveEntries = 0;

    for (final boxName in boxes) {
      try {
        final box = await getBox(boxName);
        final entries = box.length;
        totalHiveEntries += entries;

        // Estimate size (rough calculation)
        for (var key in box.keys) {
          final value = box.get(key);
          if (value != null) {
            totalHiveSize += value.toString().length;
          }
        }
      } catch (e) {
        // Skip boxes with errors
      }
    }

    // Cache stats
    final cacheStats = CacheManager.getCacheStats();
    final cacheSizeBytes = cacheStats['sizeBytes'] as int? ?? 0;
    final cacheEntryCount = cacheStats['entryCount'] as int? ?? 0;

    // SharedPreferences stats
    final prefsKeys = prefs.getKeys();
    int prefsSize = 0;
    for (var key in prefsKeys) {
      final value = prefs.get(key);
      if (value != null) {
        prefsSize += value.toString().length;
      }
    }

    stats['hive'] = {
      'totalSizeBytes': totalHiveSize,
      'totalSizeMB': (totalHiveSize / (1024 * 1024)).toStringAsFixed(2),
      'totalEntries': totalHiveEntries,
      'boxes': boxes.length,
    };

    stats['cache'] = cacheStats;

    stats['sharedPreferences'] = {
      'sizeBytes': prefsSize,
      'sizeMB': (prefsSize / (1024 * 1024)).toStringAsFixed(2),
      'entries': prefsKeys.length,
    };

    final totalSizeBytes = totalHiveSize + cacheSizeBytes + prefsSize;
    stats['total'] = {
      'sizeBytes': totalSizeBytes,
      'sizeMB': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      'entries': totalHiveEntries + cacheEntryCount + prefsKeys.length,
    };

    return stats;
  }

  /// Clear all storage
  Future<void> clearAllStorage() async {
    // Clear all Hive boxes
    final boxes = [
      StorageConstants.bookmarksBox,
      StorageConstants.tabsBox,
      StorageConstants.downloadsBox,
      StorageConstants.settingsBox,
      StorageConstants.cacheBox,
      StorageConstants.historyBox,
      StorageConstants.filtersBox,
    ];

    for (final boxName in boxes) {
      try {
        await clearBox(boxName);
      } catch (e) {
        // Continue even if one box fails
      }
    }

    // Clear cache
    await CacheManager.clearAllCache();

    // Clear SharedPreferences
    await clearPrefs();
  }

  /// Clear cache only
  Future<void> clearCache() async {
    await CacheManager.clearAllCache();
  }

  /// Clear old cache (older than specified days)
  Future<void> cleanOldCache([int days = 7]) async {
    await CacheManager.cleanOldCache();
  }

  /// Close all boxes (for cleanup)
  Future<void> closeAll() async {
    for (var box in _openBoxes.values) {
      await box.close();
    }
    _openBoxes.clear();
  }

  /// Dispose storage manager
  Future<void> dispose() async {
    await closeAll();
    _prefs = null;
    _initialized = false;
  }
}
