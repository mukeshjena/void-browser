import '../../domain/entities/weather_entity.dart';

class WeatherModel extends WeatherEntity {
  const WeatherModel({
    required super.location,
    required super.temperature,
    required super.unit,
    required super.weatherCode,
    required super.weatherDescription,
    required super.windSpeed,
    super.humidity,
    required super.fetchedAt,
    required super.latitude,
    required super.longitude,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json, double lat, double lon, {String? locationName}) {
    final currentWeather = json['current_weather'];
    final weatherCode = currentWeather['weathercode'] as int;

    return WeatherModel(
      location: locationName ?? 'Unknown Location',
      temperature: (currentWeather['temperature'] as num).toDouble(),
      unit: 'celsius',
      weatherCode: weatherCode,
      weatherDescription: _getWeatherDescription(weatherCode),
      windSpeed: (currentWeather['windspeed'] as num).toDouble(),
      humidity: null, // Open-Meteo doesn't provide humidity in current_weather
      fetchedAt: DateTime.parse(currentWeather['time']),
      latitude: lat,
      longitude: lon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'temperature': temperature,
      'unit': unit,
      'weatherCode': weatherCode,
      'weatherDescription': weatherDescription,
      'windSpeed': windSpeed,
      'humidity': humidity,
      'fetchedAt': fetchedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // WMO Weather interpretation codes
  static String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }

  static String getWeatherIcon(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 55) return '🌧️';
    if (code <= 67) return '🌨️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    if (code <= 86) return '🌨️';
    if (code >= 95) return '⛈️';
    return '🌤️';
  }

  factory WeatherModel.fromEntity(WeatherEntity entity) {
    return WeatherModel(
      location: entity.location,
      temperature: entity.temperature,
      unit: entity.unit,
      weatherCode: entity.weatherCode,
      weatherDescription: entity.weatherDescription,
      windSpeed: entity.windSpeed,
      humidity: entity.humidity,
      fetchedAt: entity.fetchedAt,
      latitude: entity.latitude,
      longitude: entity.longitude,
    );
  }
}

