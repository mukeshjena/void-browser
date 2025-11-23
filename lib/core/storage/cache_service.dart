import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/storage_constants.dart';

/// Cache entry model
class CacheEntry {
  final String key;
  final String value; // JSON string
  final DateTime fetchedAt;
  final int ttlMinutes;

  CacheEntry({
    required this.key,
    required this.value,
    required this.fetchedAt,
    required this.ttlMinutes,
  });

  bool get isExpired {
    final now = DateTime.now();
    return now.difference(fetchedAt).inMinutes > ttlMinutes;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'fetchedAt': fetchedAt.toIso8601String(),
        'ttlMinutes': ttlMinutes,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        key: json['key'] as String,
        value: json['value'] as String,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        ttlMinutes: json['ttlMinutes'] as int,
      );
}

/// Cache service for managing API response caching with Hive
class CacheService {
  static Box? _cacheBox;

  /// Initialize cache service
  static Future<void> init() async {
    _cacheBox = await Hive.openBox(StorageConstants.cacheBox);
    // Clean old cache on init
    await _cleanExpiredCache();
  }

  /// Get cache box
  static Box get cacheBox {
    if (_cacheBox == null) {
      throw Exception('CacheService not initialized. Call CacheService.init() first.');
    }
    return _cacheBox!;
  }

  /// Get cached data
  static T? get<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    try {
      final entryJson = cacheBox.get(key);
      if (entryJson == null) return null;

      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
      
      // Check if expired
      if (entry.isExpired) {
        // Delete asynchronously to avoid blocking
        cacheBox.delete(key).catchError((_) {});
        return null;
      }

      // Parse and return cached value
      final valueJson = jsonDecode(entry.value) as Map<String, dynamic>;
      return fromJson(valueJson);
    } catch (e) {
      // If parsing fails, remove invalid cache asynchronously
      cacheBox.delete(key).catchError((_) {});
      return null;
    }
  }

  /// Get cached list
  static List<T>? getList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    try {
      final entryJson = cacheBox.get(key);
      if (entryJson == null) return null;

      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
      
      // Check if expired
      if (entry.isExpired) {
        // Delete asynchronously to avoid blocking
        cacheBox.delete(key).catchError((_) {});
        return null;
      }

      // Parse and return cached list
      final valueJson = jsonDecode(entry.value) as List;
      return valueJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      // If parsing fails, remove invalid cache asynchronously
      cacheBox.delete(key).catchError((_) {});
      return null;
    }
  }

  /// Save data to cache
  static Future<void> set<T>(
    String key,
    T data,
    int ttlMinutes, {
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    try {
      String jsonString;
      
      if (toJson != null) {
        jsonString = jsonEncode(toJson(data));
      } else if (data is Map) {
        jsonString = jsonEncode(data);
      } else {
        jsonString = jsonEncode(data);
      }

      final entry = CacheEntry(
        key: key,
        value: jsonString,
        fetchedAt: DateTime.now(),
        ttlMinutes: ttlMinutes,
      );

      await cacheBox.put(key, entry.toJson());
    } catch (e) {
      // Silently fail cache write
      //print('CacheService: Failed to cache $key: $e');
    }
  }

  /// Save list to cache
  static Future<void> setList<T>(
    String key,
    List<T> data,
    int ttlMinutes, {
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    try {
      String jsonString;
      
      if (toJson != null) {
        final jsonList = data.map((item) => toJson(item)).toList();
        jsonString = jsonEncode(jsonList);
      } else {
        jsonString = jsonEncode(data);
      }

      final entry = CacheEntry(
        key: key,
        value: jsonString,
        fetchedAt: DateTime.now(),
        ttlMinutes: ttlMinutes,
      );

      await cacheBox.put(key, entry.toJson());
    } catch (e) {
      // Silently fail cache write
      print('CacheService: Failed to cache $key: $e');
    }
  }

  /// Check if cache exists and is valid
  static bool hasValidCache(String key) {
    try {
      final entryJson = cacheBox.get(key);
      if (entryJson == null) return false;

      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
      return !entry.isExpired;
    } catch (e) {
      return false;
    }
  }

  /// Get stale cache (even if expired)
  static T? getStale<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    try {
      final entryJson = cacheBox.get(key);
      if (entryJson == null) return null;

      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
      final valueJson = jsonDecode(entry.value) as Map<String, dynamic>;
      return fromJson(valueJson);
    } catch (e) {
      return null;
    }
  }

  /// Get stale list (even if expired)
  static List<T>? getStaleList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    try {
      final entryJson = cacheBox.get(key);
      if (entryJson == null) return null;

      final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
      final valueJson = jsonDecode(entry.value) as List;
      return valueJson.map((item) => fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  /// Delete cache entry
  static Future<void> delete(String key) async {
    await cacheBox.delete(key);
  }

  /// Clear all cache
  static Future<void> clear() async {
    await cacheBox.clear();
  }

  /// Clean expired cache entries
  static Future<void> _cleanExpiredCache() async {
    try {
      final keysToDelete = <String>[];
      
      // Batch process keys to avoid blocking
      final keys = cacheBox.keys.toList();
      for (var key in keys) {
        try {
          final entryJson = cacheBox.get(key);
          if (entryJson == null) {
            keysToDelete.add(key.toString());
            continue;
          }

          final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
          if (entry.isExpired) {
            keysToDelete.add(key.toString());
          }
        } catch (e) {
          // Invalid entry, delete it
          keysToDelete.add(key.toString());
        }
      }

      // Delete in batches to avoid blocking
      if (keysToDelete.isNotEmpty) {
        for (var key in keysToDelete) {
          cacheBox.delete(key).catchError((_) {});
        }
      }
    } catch (e) {
      // Silently fail - don't block app startup
    }
  }

  /// Clean cache older than specified days
  static Future<void> cleanOldCache(int daysOld) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final keysToDelete = <String>[];
      
      // Batch process keys
      final keys = cacheBox.keys.toList();
      for (var key in keys) {
        try {
          final entryJson = cacheBox.get(key);
          if (entryJson == null) {
            keysToDelete.add(key.toString());
            continue;
          }

          final entry = CacheEntry.fromJson(Map<String, dynamic>.from(entryJson as Map));
          if (entry.fetchedAt.isBefore(cutoffDate)) {
            keysToDelete.add(key.toString());
          }
        } catch (e) {
          keysToDelete.add(key.toString());
        }
      }

      // Delete in batches to avoid blocking
      if (keysToDelete.isNotEmpty) {
        for (var key in keysToDelete) {
          cacheBox.delete(key).catchError((_) {});
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Get cache size in bytes
  static int getCacheSize() {
    int size = 0;
    for (var key in cacheBox.keys) {
      final value = cacheBox.get(key);
      if (value != null) {
        size += value.toString().length;
      }
    }
    return size;
  }
}

