import 'package:dio/dio.dart';
import '../models/weather_model.dart';

abstract class WeatherRemoteDataSource {
  Future<WeatherModel> getCurrentWeather(double latitude, double longitude);
  Future<WeatherModel> getWeatherByCity(String city);
}

class WeatherRemoteDataSourceImpl implements WeatherRemoteDataSource {
  final Dio dio;

  WeatherRemoteDataSourceImpl({required this.dio});

  // Open-Meteo is completely free - no API key needed!
  static const String baseUrl = 'https://api.open-meteo.com/v1';
  static const String geocodingUrl = 'https://geocoding-api.open-meteo.com/v1';

  @override
  Future<WeatherModel> getCurrentWeather(double latitude, double longitude) async {
    try {
      // Get weather data
      final response = await dio.get(
        '$baseUrl/forecast',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'current_weather': true,
          'temperature_unit': 'celsius',
          'timezone': 'auto',
        },
      );

      if (response.statusCode == 200) {
        // Get location name using reverse geocoding (OpenStreetMap Nominatim)
        String? locationName;
        try {
          final reverseGeoResponse = await dio.get(
            'https://nominatim.openstreetmap.org/reverse',
            queryParameters: {
              'lat': latitude,
              'lon': longitude,
              'format': 'json',
              'addressdetails': 1,
            },
            options: Options(
              headers: {
                'User-Agent': 'VoidBrowser/1.0', // Required by Nominatim
              },
            ),
          );

          if (reverseGeoResponse.statusCode == 200 && 
              reverseGeoResponse.data['address'] != null) {
            final address = reverseGeoResponse.data['address'];
            // Try to get city name, fallback to other location identifiers
            locationName = address['city'] ?? 
                          address['town'] ?? 
                          address['village'] ?? 
                          address['municipality'] ?? 
                          address['county'] ?? 
                          address['state'] ?? 
                          address['country'];
          }
        } catch (e) {
          // If reverse geocoding fails, continue without location name
          // It will default to 'Unknown Location' in the model
        }

        return WeatherModel.fromJson(response.data, latitude, longitude, locationName: locationName);
      } else {
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      throw Exception('Error fetching weather: $e');
    }
  }

  @override
  Future<WeatherModel> getWeatherByCity(String city) async {
    try {
      // First, geocode the city name to get coordinates
      final geoResponse = await dio.get(
        '$geocodingUrl/search',
        queryParameters: {
          'name': city,
          'count': 1,
        },
      );

      if (geoResponse.statusCode == 200 && geoResponse.data['results'] != null) {
        final location = geoResponse.data['results'][0];
        final lat = location['latitude'];
        final lon = location['longitude'];
        final locationName = location['name'];

        // Get weather for coordinates
        final weatherResponse = await dio.get(
          '$baseUrl/forecast',
          queryParameters: {
            'latitude': lat,
            'longitude': lon,
            'current_weather': true,
            'temperature_unit': 'celsius',
            'timezone': 'auto',
          },
        );

        if (weatherResponse.statusCode == 200) {
          return WeatherModel.fromJson(weatherResponse.data, lat, lon, locationName: locationName);
        } else {
          throw Exception('Failed to load weather');
        }
      } else {
        throw Exception('City not found');
      }
    } catch (e) {
      throw Exception('Error fetching weather by city: $e');
    }
  }
}

