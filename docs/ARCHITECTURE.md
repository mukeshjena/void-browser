# Architecture Overview

This document provides an overview of Void Browser's architecture and design patterns.

---

## 📋 Table of Contents

1. [Architecture Pattern](#architecture-pattern)
2. [Project Structure](#project-structure)
3. [Layers](#layers)
4. [State Management](#state-management)
5. [Data Flow](#data-flow)
6. [Key Components](#key-components)
7. [Design Patterns](#design-patterns)

---

## Architecture Pattern

Void Browser follows **Clean Architecture** principles, organizing code into distinct layers with clear separation of concerns.

### Benefits

- **Testability**: Each layer can be tested independently
- **Maintainability**: Changes in one layer don't affect others
- **Scalability**: Easy to add new features
- **Reusability**: Business logic is independent of UI

### Layers

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│  (UI, Widgets, State Management)    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│        Domain Layer                  │
│  (Entities, Use Cases, Interfaces)   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Data Layer                   │
│  (Repositories, Data Sources, APIs) │
└──────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── core/                          # Core functionality
│   ├── constants/                 # App-wide constants
│   │   ├── api_constants.dart     # API endpoints
│   │   ├── app_constants.dart     # App constants
│   │   ├── route_constants.dart   # Route names
│   │   └── storage_constants.dart # Storage keys
│   ├── errors/                    # Error handling
│   ├── extensions/                # Dart extensions
│   ├── network/                   # Network layer
│   │   ├── api_client.dart        # HTTP client setup
│   │   └── interceptors.dart      # Request/response interceptors
│   ├── router/                    # Navigation
│   ├── storage/                   # Storage services
│   │   ├── cache_service.dart     # Caching layer
│   │   └── storage_service.dart   # Local storage
│   ├── theme/                    # Theme configuration
│   └── utils/                    # Utility functions
│       └── validators.dart       # Input validation
│
├── features/                     # Feature modules
│   ├── browser/                  # Browser feature
│   │   ├── data/
│   │   │   └── models/           # Data models
│   │   ├── domain/
│   │   │   └── entities/         # Domain entities
│   │   └── presentation/
│   │       ├── providers/        # State management
│   │       ├── screens/          # UI screens
│   │       └── utils/            # Feature utilities
│   ├── discover/                 # Discovery panel
│   ├── news/                     # News feature
│   ├── recipes/                  # Recipes feature
│   ├── weather/                  # Weather feature
│   ├── images/                   # Images feature
│   ├── bookmarks/                # Bookmarks
│   ├── downloads/                # Downloads
│   ├── settings/                 # Settings
│   └── adblock/                  # Ad-blocking
│
├── shared/                       # Shared components
│   ├── animations/               # Reusable animations
│   └── widgets/                  # Shared widgets
│       ├── chrome_search_bar.dart
│       └── chrome_webview.dart
│
└── main.dart                     # App entry point
```

---

## Layers

### 1. Presentation Layer

**Responsibility**: UI, user interactions, state management

**Components**:
- **Screens**: Full-page UI components
- **Widgets**: Reusable UI components
- **Providers**: Riverpod state management
- **ViewModels**: Business logic for UI

**Example**:
```dart
// lib/features/browser/presentation/screens/browser_tab_screen.dart
class BrowserTabScreen extends ConsumerStatefulWidget {
  // UI implementation
}
```

### 2. Domain Layer

**Responsibility**: Business logic, entities, use cases

**Components**:
- **Entities**: Pure Dart classes representing business objects
- **Use Cases**: Business logic operations
- **Interfaces**: Abstract contracts for data sources

**Example**:
```dart
// lib/features/browser/domain/entities/tab_entity.dart
class TabEntity {
  final String id;
  final String url;
  final String? title;
  // Pure Dart, no dependencies
}
```

### 3. Data Layer

**Responsibility**: Data sources, API calls, local storage

**Components**:
- **Models**: Data transfer objects (DTOs)
- **Repositories**: Data access abstraction
- **Data Sources**: API clients, local storage
- **Mappers**: Convert between models and entities

**Example**:
```dart
// lib/features/browser/data/models/tab_model.dart
class TabModel {
  // JSON serialization
  // Hive type adapter
  // Conversion to/from TabEntity
}
```

---

## State Management

### Riverpod

Void Browser uses **Riverpod** for state management.

**Why Riverpod?**
- Type-safe
- Testable
- Compile-time error checking
- Dependency injection built-in

### Provider Types

1. **StateNotifierProvider**: For complex state
   ```dart
   final tabsProvider = StateNotifierProvider<TabsNotifier, TabsState>((ref) {
     return TabsNotifier(ref);
   });
   ```

2. **FutureProvider**: For async data
   ```dart
   final newsProvider = FutureProvider<List<NewsArticle>>((ref) async {
     return await newsRepository.getTopHeadlines();
   });
   ```

3. **StateProvider**: For simple state
   ```dart
   final searchEngineProvider = StateProvider<String>((ref) => 'google');
   ```

### State Persistence

- **Hive**: For complex objects (tabs, bookmarks)
- **SharedPreferences**: For simple key-value pairs (settings, search engine)

---

## Data Flow

### Typical Flow

```
User Action
    ↓
UI Widget (Presentation)
    ↓
Provider (State Management)
    ↓
Repository (Data Layer)
    ↓
API Client / Local Storage
    ↓
Response
    ↓
Model → Entity (Mapping)
    ↓
Provider Update
    ↓
UI Rebuild
```

### Example: Loading News

1. **User opens News tab**
2. **UI calls**: `ref.watch(newsProvider)`
3. **Provider checks**: Cache first, then API
4. **Repository fetches**: From API or cache
5. **Model converts**: JSON → `NewsModel` → `NewsEntity`
6. **Provider updates**: State with news articles
7. **UI rebuilds**: Shows news list

---

## Key Components

### 1. Browser Tab System

**Location**: `lib/features/browser/`

**Components**:
- `TabEntity`: Domain model
- `TabModel`: Data model with Hive adapter
- `TabsProvider`: State management
- `BrowserTabScreen`: Main UI
- `TabSwitcherScreen`: Tab overview UI

**Flow**:
```
TabEntity (Domain)
    ↕
TabModel (Data, Hive)
    ↕
TabsProvider (State)
    ↕
BrowserTabScreen (UI)
```

### 2. Discovery Panel

**Location**: `lib/features/discover/`

**Components**:
- `DiscoverScreen`: Main discovery UI
- Integrates: News, Recipes, Weather, Images
- Uses: Multiple providers for each feature

### 3. WebView Integration

**Location**: `lib/shared/widgets/chrome_webview.dart`

**Features**:
- InAppWebView wrapper
- Ad-blocking integration
- Gesture support (swipe, pull-to-refresh)
- Auto-hide AppBar

### 4. Caching System

**Location**: `lib/core/storage/cache_service.dart`

**Features**:
- TTL-based caching
- Stale-while-revalidate
- Automatic cleanup
- Per-feature cache configuration

---

## Design Patterns

### 1. Repository Pattern

**Purpose**: Abstract data sources

**Implementation**:
```dart
abstract class NewsRepository {
  Future<List<NewsArticle>> getTopHeadlines();
}

class NewsRepositoryImpl implements NewsRepository {
  final ApiClient apiClient;
  final CacheService cacheService;
  
  // Implementation
}
```

### 2. Provider Pattern (Riverpod)

**Purpose**: Dependency injection and state management

**Implementation**:
```dart
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    cacheService: ref.watch(cacheServiceProvider),
  );
});
```

### 3. Factory Pattern

**Purpose**: Create objects with complex initialization

**Example**: `TabEntity` creation with default values

### 4. Observer Pattern

**Purpose**: React to state changes

**Implementation**: Riverpod's `ref.watch()` and `ref.listen()`

### 5. Strategy Pattern

**Purpose**: Interchangeable algorithms

**Example**: Search engine selection (Google, Bing, DuckDuckGo)

---

## Data Models

### Entity vs Model

**Entity** (Domain):
- Pure Dart class
- No dependencies
- Business logic
- Immutable

**Model** (Data):
- JSON serialization
- Hive adapters
- Data transfer
- Mutable (for serialization)

### Conversion

```dart
// Model to Entity
TabEntity tabEntity = tabModel.toEntity();

// Entity to Model
TabModel tabModel = TabModel.fromEntity(tabEntity);
```

---

## Error Handling

### Error Types

1. **Network Errors**: API failures, timeouts
2. **Cache Errors**: Storage failures
3. **Validation Errors**: Invalid input
4. **Business Logic Errors**: Domain-specific errors

### Error Flow

```
Error occurs
    ↓
Caught in Repository
    ↓
Converted to Failure/Exception
    ↓
Handled in Provider
    ↓
Displayed in UI (SnackBar, Dialog)
```

---

## Testing Strategy

### Unit Tests

- **Domain Layer**: Business logic
- **Data Layer**: Model conversion, repository logic
- **Utils**: Utility functions

### Widget Tests

- **Presentation Layer**: UI components
- **User Interactions**: Button clicks, form submissions

### Integration Tests

- **User Flows**: Complete feature workflows
- **Navigation**: Screen transitions

---

## Performance Optimizations

### 1. Caching

- API responses cached with TTL
- Stale data shown while fetching fresh data
- Automatic cache cleanup

### 2. Lazy Loading

- Images loaded on demand
- Infinite scroll for lists
- Tab WebViews created on demand

### 3. State Management

- Providers only rebuild when needed
- Computed values cached
- Debouncing for search

### 4. Build Optimizations

- Code splitting
- Tree shaking
- ProGuard/R8 optimization

---

## Future Improvements

- [ ] Add more comprehensive error handling
- [ ] Implement offline-first architecture
- [ ] Add dependency injection container
- [ ] Implement feature flags
- [ ] Add analytics (privacy-respecting)
- [ ] Add crash reporting

---

## Resources

- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter Architecture](https://docs.flutter.dev/development/data-and-backend/state-mgmt/options)

---

**This architecture ensures Void Browser is maintainable, testable, and scalable! 🏗️**

