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
        return WeatherModel.fromJson(response.data, latitude, longitude);
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

