import 'package:shared_preferences/shared_preferences.dart';
import 'storage_manager.dart';
import '../constants/storage_constants.dart';

/// Storage migration manager for handling database schema changes
class StorageMigration {
  static const String _migrationVersionKey = 'storage_migration_version';
  static const int _currentVersion = 1;

  /// Run migrations if needed
  static Future<void> migrate() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt(_migrationVersionKey) ?? 0;

    if (currentVersion < _currentVersion) {
      // Run migrations in order
      for (int version = currentVersion + 1; version <= _currentVersion; version++) {
        await _runMigration(version);
      }

      // Update version
      await prefs.setInt(_migrationVersionKey, _currentVersion);
    }
  }

  /// Run specific migration version
  static Future<void> _runMigration(int version) async {
    switch (version) {
      case 1:
        await _migrationV1();
        break;
      // Add more migrations as needed
      // case 2:
      //   await _migrationV2();
      //   break;
    }
  }

  /// Migration version 1: Initial migration
  /// Sets up default values and cleans up any invalid data
  static Future<void> _migrationV1() async {
    try {
      final storage = StorageManager.instance;
      
      // Ensure storage is initialized
      if (!storage.isInitialized) {
        await storage.initialize();
      }

      // Clean up invalid cache entries
      await _cleanInvalidCacheEntries();

      // Set default preferences if not set
      await _setDefaultPreferences();

      // Validate and fix Hive boxes
      await _validateHiveBoxes();
    } catch (e) {
      // Log error but don't fail migration
      print('Migration V1 error: $e');
    }
  }

  /// Clean invalid cache entries
  static Future<void> _cleanInvalidCacheEntries() async {
    try {
      final cacheBox = await StorageManager.instance.cacheBox;
      final keysToDelete = <String>[];

      for (var key in cacheBox.keys) {
        try {
          final entry = cacheBox.get(key);
          if (entry == null) {
            keysToDelete.add(key.toString());
            continue;
          }

          // Validate entry structure
          if (entry is! Map) {
            keysToDelete.add(key.toString());
            continue;
          }

          final entryMap = entry as Map;
          if (!entryMap.containsKey('key') || 
              !entryMap.containsKey('value') || 
              !entryMap.containsKey('fetchedAt') ||
              !entryMap.containsKey('ttlMinutes')) {
            keysToDelete.add(key.toString());
          }
        } catch (e) {
          keysToDelete.add(key.toString());
        }
      }

      // Delete invalid entries
      for (var key in keysToDelete) {
        await cacheBox.delete(key).catchError((_) {});
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Set default preferences
  static Future<void> _setDefaultPreferences() async {
    try {
      final prefs = StorageManager.instance.prefs;

      // Set defaults only if not already set
      if (!prefs.containsKey(StorageConstants.keySearchEngine)) {
        await prefs.setString(StorageConstants.keySearchEngine, StorageConstants.defaultSearchEngine);
      }

      if (!prefs.containsKey(StorageConstants.keyUserAgent)) {
        await prefs.setString(StorageConstants.keyUserAgent, StorageConstants.defaultUserAgent);
      }

      if (!prefs.containsKey(StorageConstants.keyJavascriptEnabled)) {
        await prefs.setBool(StorageConstants.keyJavascriptEnabled, StorageConstants.defaultJavascriptEnabled);
      }

      if (!prefs.containsKey(StorageConstants.keyAdBlockEnabled)) {
        await prefs.setBool(StorageConstants.keyAdBlockEnabled, StorageConstants.defaultAdBlockEnabled);
      }

      if (!prefs.containsKey(StorageConstants.keyDoNotTrack)) {
        await prefs.setBool(StorageConstants.keyDoNotTrack, StorageConstants.defaultDoNotTrack);
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Validate and fix Hive boxes
  static Future<void> _validateHiveBoxes() async {
    try {
      final boxes = [
        StorageConstants.bookmarksBox,
        StorageConstants.tabsBox,
        StorageConstants.downloadsBox,
        StorageConstants.historyBox,
      ];

      for (final boxName in boxes) {
        try {
          final box = await StorageManager.instance.getBox(boxName);
          
          // Check if box is corrupted
          if (box.isOpen) {
            // Try to read all keys to check for corruption
            final keys = box.keys.toList();
            for (var key in keys) {
              try {
                box.get(key);
              } catch (e) {
                // Invalid entry, delete it
                await box.delete(key).catchError((_) {});
              }
            }
          }
        } catch (e) {
          // Box might be corrupted, try to recreate it
          try {
            final box = await StorageManager.instance.getBox(boxName);
            // If we can't open it, it will be recreated on next access
          } catch (e) {
            // Silently fail - box will be recreated when needed
          }
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Get current migration version
  static Future<int> getCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_migrationVersionKey) ?? 0;
  }

  /// Force migration to specific version (for testing)
  static Future<void> setVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_migrationVersionKey, version);
  }
}
