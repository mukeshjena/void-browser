# State Management and Storage Implementation

## Overview
This document describes the state management and local storage implementation for all new features added to Void Browser.

## Architecture

### State Management: Riverpod
- **Framework**: `flutter_riverpod` (v2.4.0)
- **Pattern**: StateNotifierProvider for complex state management
- **Location**: `lib/features/*/presentation/providers/`

### Local Storage: Hive + SharedPreferences
- **Hive**: For structured data (bookmarks, downloads, tabs, search history)
- **SharedPreferences**: For simple key-value settings
- **Cache Service**: For API response caching with TTL

## New Features Implementation

### 1. Search History

#### Provider
- **File**: `lib/features/search/presentation/providers/search_history_provider.dart`
- **State**: `SearchHistoryState` - contains history list, loading state, errors
- **Notifier**: `SearchHistoryNotifier` - manages search history operations

#### Storage
- **Database**: Hive box `historyBox`
- **Model**: `SearchHistoryModel` (typeId: 2)
- **Entity**: `SearchHistoryEntity`
- **Location**: `lib/features/search/data/models/search_history_model.dart`

#### Features
- ✅ Add search queries to history
- ✅ Add URL navigations to history
- ✅ Get search suggestions based on query
- ✅ Delete individual history items
- ✅ Clear all history
- ✅ Auto-limit history to 100 items (most recent kept)

#### Usage
```dart
// Add to history
ref.read(searchHistoryProvider.notifier).addSearchQuery('flutter tutorial');

// Get suggestions
final suggestions = ref.read(searchHistoryProvider.notifier).getSuggestions('flut');

// Clear history
ref.read(searchHistoryProvider.notifier).clearHistory();
```

### 2. Search Suggestions

#### Provider
- **File**: `lib/features/search/presentation/providers/search_suggestions_provider.dart`
- **State**: `SearchSuggestionsState` - contains suggestions list, loading state
- **Notifier**: `SearchSuggestionsNotifier` - manages search suggestions

#### Caching
- **Cache Key**: `search_suggestions_cache_{query}`
- **TTL**: 60 minutes
- **Source**: Combines search history and cached suggestions

#### Features
- ✅ Get suggestions from search history
- ✅ Cache suggestions for faster retrieval
- ✅ Combine history and cached suggestions
- ✅ Limit to 10 suggestions

### 3. Biometric Authentication

#### State Management
- **Provider**: `settingsProvider` (existing)
- **Key**: `keyFingerprintLockEnabled` in SharedPreferences
- **Location**: `lib/features/settings/presentation/providers/settings_provider.dart`

#### Storage
- **Type**: SharedPreferences (boolean)
- **Default**: `false`
- **Service**: `BiometricService` - handles authentication logic

#### Features
- ✅ Enable/disable fingerprint lock
- ✅ Check biometric availability
- ✅ Authenticate on app start/resume
- ✅ Grace period after successful unlock (3 seconds)
- ✅ Cooldown after dismissal (1 second)

### 4. Download Notifications

#### State Management
- **Provider**: `downloadManagerProvider` (existing)
- **Service**: `NotificationService` - handles local notifications
- **Location**: `lib/core/services/notification_service.dart`

#### Storage
- **Downloads**: Hive box `downloadsBox` (existing)
- **Notifications**: Managed by `flutter_local_notifications`

#### Features
- ✅ Show notification when download starts
- ✅ Tappable notification opens downloads screen
- ✅ Notification ID based on download ID

### 5. QR Scanner & Voice Search

#### State Management
- **QR Scanner**: Direct state in `ExpandedSearchBarOverlay`
- **Voice Search**: Direct state in `ExpandedSearchBarOverlay` + `VoiceSearchService`
- **History**: Automatically added to search history when used

#### Storage
- **QR Codes**: Added to search history as URL navigation
- **Voice Queries**: Added to search history as search query

## Storage Constants

### New Keys Added
```dart
// Search & Cache
static const String keySearchSuggestionsCache = 'search_suggestions_cache';
static const String keyQRCodeHistory = 'qr_code_history';
```

### Existing Keys Used
```dart
// Settings
static const String keyFingerprintLockEnabled = 'fingerprint_lock_enabled';

// Cache
static const String keyNewsCache = 'news_cache';
static const String keyRecipesCache = 'recipes_cache';
static const String keyWeatherCache = 'weather_cache';
static const String keyImagesCache = 'images_cache';
```

## Hive Configuration

### New Adapter Registered
- **TypeId**: 2
- **Model**: `SearchHistoryModel`
- **Location**: `lib/core/storage/hive_config.dart`

### Boxes Opened
- `bookmarksBox` - Bookmarks
- `tabsBox` - Browser tabs
- `downloadsBox` - Downloads
- `settingsBox` - Settings
- `cacheBox` - API cache
- `historyBox` - Search history (NEW)
- `filtersBox` - Ad-block filters

## Integration Points

### 1. Expanded Search Bar Overlay
- **File**: `lib/shared/widgets/expanded_search_bar_overlay.dart`
- **Changes**:
  - Converted to `ConsumerStatefulWidget`
  - Integrated `searchHistoryProvider`
  - Adds queries to history on submission
  - Adds QR codes to history
  - Adds voice search to history

### 2. Tab Utils
- **File**: `lib/features/browser/presentation/utils/tab_utils.dart`
- **Changes**:
  - Integrated `searchHistoryProvider`
  - Adds URL navigations to history when opening URLs

### 3. Settings Provider
- **File**: `lib/features/settings/presentation/providers/settings_provider.dart`
- **Changes**:
  - Added `fingerprintLockEnabled` field
  - Added `setFingerprintLockEnabled` method
  - Loads from SharedPreferences on init

## Cache Management

### Cache Service
- **File**: `lib/core/storage/cache_service.dart`
- **Features**:
  - TTL-based caching
  - Automatic expiration
  - Stale cache fallback
  - Cache size management

### Cache Manager
- **File**: `lib/core/storage/cache_manager.dart`
- **Features**:
  - Clean old cache (7+ days)
  - Get cache statistics
  - Clear all cache

## Data Flow

### Search History Flow
```
User enters query
  ↓
ExpandedSearchBarOverlay.onSubmitted
  ↓
searchHistoryProvider.notifier.addSearchQuery()
  ↓
Save to Hive (historyBox)
  ↓
Reload history state
  ↓
Limit to 100 items (if needed)
```

### Search Suggestions Flow
```
User types in search bar
  ↓
searchSuggestionsProvider.notifier.getSuggestions()
  ↓
Get from search history (via historyProvider)
  ↓
Get from cache (if available)
  ↓
Combine and return (max 10)
```

### Biometric Lock Flow
```
App starts/resumes
  ↓
AppLifecycleWrapper.didChangeAppLifecycleState()
  ↓
Check settingsProvider.fingerprintLockEnabled
  ↓
Check grace period & cooldown
  ↓
Show LockScreen
  ↓
BiometricService.authenticate()
  ↓
On success: Update lastSuccessfulUnlock
  ↓
On dismiss: Update lastLockScreenDismissed
```

## Best Practices

1. **State Management**
   - Use Riverpod providers for all state
   - Keep state immutable
   - Use StateNotifier for complex state

2. **Storage**
   - Use Hive for structured data
   - Use SharedPreferences for simple settings
   - Use CacheService for API responses

3. **Caching**
   - Set appropriate TTL values
   - Use stale cache as fallback
   - Clean old cache periodically

4. **History Management**
   - Limit history size to prevent bloat
   - Sort by timestamp (newest first)
   - Provide clear/delete options

## Future Enhancements

1. **Search Suggestions**
   - Integrate with search engine APIs
   - Add autocomplete suggestions
   - Cache popular searches

2. **History Management**
   - Add history search/filter
   - Group by date
   - Export history

3. **Biometric Lock**
   - Add timeout configuration
   - Support multiple biometric types
   - Add lock screen customization

4. **Analytics**
   - Track search patterns
   - Monitor cache hit rates
   - Analyze storage usage

