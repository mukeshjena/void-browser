import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/weather_remote_datasource.dart';
import '../../data/models/weather_model.dart';
import '../../domain/entities/weather_entity.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/cache_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../main.dart';

// Provider for weather remote data source
final weatherRemoteDataSourceProvider = Provider<WeatherRemoteDataSource>((ref) {
  return WeatherRemoteDataSourceImpl(dio: DioClient.instance);
});

// State for weather
class WeatherState {
  final WeatherEntity? weather;
  final bool isLoading;
  final String? error;

  WeatherState({
    this.weather,
    this.isLoading = false,
    this.error,
  });

  WeatherState copyWith({
    WeatherEntity? weather,
    bool? isLoading,
    String? error,
  }) {
    return WeatherState(
      weather: weather ?? this.weather,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Weather notifier
class WeatherNotifier extends StateNotifier<WeatherState> {
  final WeatherRemoteDataSource remoteDataSource;
  final SharedPreferences _prefs;

  WeatherNotifier(this.remoteDataSource, this._prefs) : super(WeatherState()) {
    // Load last cached weather on initialization
    _loadCachedWeather();
  }

  void _loadCachedWeather() async {
    // Try to load last location from preferences
    final lastLat = _prefs.getDouble(StorageConstants.keyLastLatitude);
    final lastLon = _prefs.getDouble(StorageConstants.keyLastLongitude);

    if (lastLat != null && lastLon != null) {
      // Load cached weather for last known location
      final cacheKey = 'weather_location_${lastLat.toStringAsFixed(2)}_${lastLon.toStringAsFixed(2)}';
      final cachedWeather = CacheService.get<WeatherEntity>(
        cacheKey,
        (json) => WeatherModel.fromJson(json, lastLat, lastLon),
      );

      if (cachedWeather != null) {
        state = state.copyWith(
          weather: cachedWeather,
          isLoading: false,
          error: null,
        );
      }
    }
  }

  Future<void> _saveLocation(double latitude, double longitude) async {
    await _prefs.setDouble(StorageConstants.keyLastLatitude, latitude);
    await _prefs.setDouble(StorageConstants.keyLastLongitude, longitude);
  }

  Future<void> loadWeatherByLocation(double latitude, double longitude, {bool forceRefresh = false}) async {
    final cacheKey = 'weather_location_${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedWeather = CacheService.get<WeatherEntity>(
        cacheKey,
        (json) => WeatherModel.fromJson(json, latitude, longitude),
      );

      if (cachedWeather != null) {
        state = state.copyWith(
          weather: cachedWeather,
          isLoading: false,
          error: null,
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final weather = await remoteDataSource.getCurrentWeather(latitude, longitude);
      
      // Save to cache
      await CacheService.set(
        cacheKey,
        weather,
        ApiConstants.weatherCacheTtl,
        toJson: (w) => WeatherModel.fromEntity(w).toJson(),
      );

      // Save location for persistence
      await _saveLocation(latitude, longitude);

      state = state.copyWith(weather: weather, isLoading: false);
    } catch (e) {
      // Try to load stale cache on error
      final staleWeather = CacheService.getStale<WeatherEntity>(
        cacheKey,
        (json) => WeatherModel.fromJson(json, latitude, longitude),
      );

      if (staleWeather != null) {
        state = state.copyWith(
          weather: staleWeather,
          isLoading: false,
          error: 'Showing cached content. ${e.toString()}',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load weather: ${e.toString()}',
        );
      }
    }
  }

  Future<void> loadWeatherByCity(String city, {bool forceRefresh = false}) async {
    final cacheKey = 'weather_city_$city';

    // Try to load from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedWeather = CacheService.get<WeatherEntity>(
        cacheKey,
        (json) {
          // For city-based weather, we need lat/lon from cache or use defaults
          final lat = json['latitude'] as double? ?? 0.0;
          final lon = json['longitude'] as double? ?? 0.0;
          return WeatherModel.fromJson(json, lat, lon, locationName: city);
        },
      );

      if (cachedWeather != null) {
        state = state.copyWith(
          weather: cachedWeather,
          isLoading: false,
          error: null,
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final weather = await remoteDataSource.getWeatherByCity(city);
      
      // Save to cache
      await CacheService.set(
        cacheKey,
        weather,
        ApiConstants.weatherCacheTtl,
        toJson: (w) => WeatherModel.fromEntity(w).toJson(),
      );

      state = state.copyWith(weather: weather, isLoading: false);
    } catch (e) {
      // Try to load stale cache on error
      final staleWeather = CacheService.getStale<WeatherEntity>(
        cacheKey,
        (json) {
          final lat = json['latitude'] as double? ?? 0.0;
          final lon = json['longitude'] as double? ?? 0.0;
          return WeatherModel.fromJson(json, lat, lon, locationName: city);
        },
      );

      if (staleWeather != null) {
        state = state.copyWith(
          weather: staleWeather,
          isLoading: false,
          error: 'Showing cached content. ${e.toString()}',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load weather: ${e.toString()}',
        );
      }
    }
  }
}

// Weather provider
final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>((ref) {
  final remoteDataSource = ref.watch(weatherRemoteDataSourceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return WeatherNotifier(remoteDataSource, prefs);
});

