import 'package:hive_flutter/hive_flutter.dart';
import 'storage_manager.dart';
import '../constants/storage_constants.dart';

/// Storage error handler for recovery and error management
class StorageErrorHandler {
  static StorageErrorHandler? _instance;
  static StorageErrorHandler get instance {
    _instance ??= StorageErrorHandler._internal();
    return _instance!;
  }

  StorageErrorHandler._internal();

  /// Handle storage errors with recovery strategies
  Future<T?> handleError<T>(
    Future<T> Function() operation, {
    T? defaultValue,
    bool retry = true,
    int maxRetries = 3,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } on HiveError catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          // Last attempt failed, try recovery
          await _attemptRecovery(e);
          if (retry) {
            // Try one more time after recovery
            try {
              return await operation();
            } catch (e) {
              return defaultValue;
            }
          }
          return defaultValue;
        }

        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(milliseconds: 100 * attempts));
      } catch (e) {
        // Non-Hive errors, return default
        return defaultValue;
      }
    }

    return defaultValue;
  }

  /// Attempt to recover from Hive errors
  Future<void> _attemptRecovery(HiveError error) async {
    try {
      // Try to close and reopen boxes
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
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.close();
          }
          // Box will be reopened on next access
        } catch (e) {
          // Continue with other boxes
        }
      }
    } catch (e) {
      // Recovery failed, but don't throw
    }
  }

  /// Validate box integrity
  Future<bool> validateBox(String boxName) async {
    try {
      final box = await StorageManager.instance.getBox(boxName);
      
      // Try to read all keys
      final keys = box.keys.toList();
      for (var key in keys) {
        try {
          box.get(key);
        } catch (e) {
          // Invalid entry found
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Repair corrupted box by removing invalid entries
  Future<void> repairBox(String boxName) async {
    try {
      final box = await StorageManager.instance.getBox(boxName);
      final keysToDelete = <String>[];

      for (var key in box.keys) {
        try {
          box.get(key);
        } catch (e) {
          // Invalid entry, mark for deletion
          keysToDelete.add(key.toString());
        }
      }

      // Delete invalid entries
      for (var key in keysToDelete) {
        await box.delete(key).catchError((_) {});
      }
    } catch (e) {
      // Repair failed
    }
  }

  /// Check storage health
  Future<Map<String, dynamic>> checkHealth() async {
    final health = <String, dynamic>{
      'overall': 'healthy',
      'issues': <String>[],
      'boxes': <String, bool>{},
    };

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
        final isValid = await validateBox(boxName);
        health['boxes'][boxName] = isValid;
        
        if (!isValid) {
          health['overall'] = 'degraded';
          health['issues'].add('Box $boxName has integrity issues');
        }
      } catch (e) {
        health['boxes'][boxName] = false;
        health['overall'] = 'unhealthy';
        health['issues'].add('Box $boxName is inaccessible: $e');
      }
    }

    return health;
  }

  /// Auto-repair all boxes
  Future<void> autoRepair() async {
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
        final isValid = await validateBox(boxName);
        if (!isValid) {
          await repairBox(boxName);
        }
      } catch (e) {
        // Continue with other boxes
      }
    }
  }
}
