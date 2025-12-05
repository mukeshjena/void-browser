# Storage Management System

## Overview

The Void Browser application uses a comprehensive storage management system that coordinates state management (Riverpod), local database (Hive), and caching. This document describes the architecture and usage.

## Architecture

### Components

1. **StorageManager** - Centralized storage coordinator
2. **StateCoordinator** - State management coordinator
3. **CacheService** - API response caching
4. **CacheLifecycleManager** - Automatic cache maintenance
5. **StorageMigration** - Database schema migration
6. **StorageMonitor** - Storage health monitoring
7. **StorageErrorHandler** - Error recovery and handling

## StorageManager

The `StorageManager` provides a unified interface for all storage operations.

### Features

- Coordinates Hive and SharedPreferences
- Provides unified API for storage operations
- Automatic box management
- Storage statistics
- Lifecycle management

### Usage

```dart
// Get instance
final storage = StorageManager.instance;

// Initialize (called automatically in main.dart)
await storage.initialize();

// Access SharedPreferences
final theme = storage.prefs.getString('theme_mode');

// Access Hive boxes
final bookmarksBox = await storage.bookmarksBox;
final tabsBox = await storage.tabsBox;

// Save to SharedPreferences
await storage.savePref('theme_mode', 'dark');

// Save to Hive
await storage.saveToBox('bookmarks', 'key', data);

// Get storage statistics
final stats = await storage.getStorageStats();
```

## StateCoordinator

Manages all state providers and coordinates initialization.

### Usage

```dart
// Get instance
final coordinator = StateCoordinator.instance;

// Initialize
await coordinator.initialize();

// Get statistics
final stats = await coordinator.getStatistics();

// Clear all state
await coordinator.clearAllState();
```

## CacheService

Manages API response caching with TTL (Time To Live).

### Features

- Automatic expiration
- TTL-based invalidation
- Metadata support
- Pattern-based clearing

### Usage

```dart
// Save to cache
await CacheService.set(
  'news_headlines',
  newsData,
  30, // TTL in minutes
  toJson: (data) => data.toJson(),
);

// Get from cache
final cached = CacheService.get<NewsData>(
  'news_headlines',
  (json) => NewsData.fromJson(json),
);

// Check if cache exists
if (CacheService.hasValidCache('news_headlines')) {
  // Use cache
}

// Clear by pattern
await CacheService.clearCacheByPattern('news_*');
```

## CacheLifecycleManager

Automatically maintains cache health.

### Features

- Hourly expired cache cleanup
- Daily old cache cleanup (7+ days)
- Periodic statistics updates

### Usage

```dart
// Start automatic management (called in CacheManager.init())
CacheLifecycleManager.instance.start();

// Stop management
CacheLifecycleManager.instance.stop();
```

## StorageMigration

Handles database schema migrations.

### Features

- Version-based migrations
- Automatic migration on app start
- Data validation and cleanup

### Adding a Migration

```dart
// In storage_migration.dart
static const int _currentVersion = 2; // Increment version

// Add migration function
static Future<void> _runMigration(int version) async {
  switch (version) {
    case 1:
      await _migrationV1();
      break;
    case 2:
      await _migrationV2(); // New migration
      break;
  }
}

static Future<void> _migrationV2() async {
  // Migration logic
}
```

## StorageMonitor

Monitors storage usage and health.

### Features

- Real-time statistics
- Health status monitoring
- Automatic updates

### Usage

```dart
// In a widget
final monitor = ref.watch(storageMonitorProvider);

// Get cache health
final cacheHealth = monitor.getCacheHealth();
// Returns: { status: 'healthy'|'warning'|'critical', message: '...', ... }

// Get storage health
final storageHealth = monitor.getStorageHealth();

// Force refresh
await ref.read(storageMonitorProvider.notifier).refresh();
```

## StorageErrorHandler

Handles storage errors with recovery strategies.

### Features

- Automatic retry with exponential backoff
- Box integrity validation
- Automatic repair
- Health checking

### Usage

```dart
final handler = StorageErrorHandler.instance;

// Wrap operations with error handling
final result = await handler.handleError(
  () async {
    // Storage operation
    return await storage.getFromBox('bookmarks', 'key');
  },
  defaultValue: null,
  retry: true,
  maxRetries: 3,
);

// Check storage health
final health = await handler.checkHealth();

// Auto-repair
await handler.autoRepair();
```

## Storage Statistics

Get comprehensive storage statistics:

```dart
final stats = await StorageManager.instance.getStorageStats();

// Returns:
// {
//   'hive': { 'totalSizeBytes': ..., 'totalSizeMB': ..., 'totalEntries': ..., 'boxes': ... },
//   'cache': { 'sizeBytes': ..., 'sizeMB': ..., 'entryCount': ..., 'lifecycleRunning': ... },
//   'sharedPreferences': { 'sizeBytes': ..., 'sizeMB': ..., 'entries': ... },
//   'total': { 'sizeBytes': ..., 'sizeMB': ..., 'entries': ... }
// }
```

## Best Practices

1. **Always use StorageManager** for storage operations
2. **Use error handling** for critical operations
3. **Monitor storage health** periodically
4. **Clear cache** when needed to free space
5. **Use migrations** for schema changes
6. **Handle errors gracefully** with defaults

## Migration Guide

### From Direct Hive/SharedPreferences Access

**Before:**
```dart
final prefs = await SharedPreferences.getInstance();
final box = await Hive.openBox('bookmarks');
```

**After:**
```dart
final storage = StorageManager.instance;
final prefs = storage.prefs;
final box = await storage.bookmarksBox;
```

### From Direct CacheService Access

**Before:**
```dart
await CacheService.set('key', data, 30);
```

**After:**
```dart
// Still works, but now managed by StorageManager
await CacheService.set('key', data, 30);
```

## Troubleshooting

### Storage Not Initialized

Ensure `StorageManager.instance.initialize()` is called in `main.dart`.

### Cache Not Clearing

Check if `CacheLifecycleManager` is running:
```dart
final stats = CacheManager.getCacheStats();
print(stats['lifecycleRunning']); // Should be true
```

### Box Corruption

Use error handler to repair:
```dart
await StorageErrorHandler.instance.autoRepair();
```

### High Storage Usage

Check statistics and clear if needed:
```dart
final stats = await StorageManager.instance.getStorageStats();
if (stats['total']['sizeMB'] > 500) {
  await StorageManager.instance.clearCache();
}
```
