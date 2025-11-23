class WeatherEntity {
  final String location;
  final double temperature;
  final String unit;
  final int weatherCode;
  final String weatherDescription;
  final double windSpeed;
  final int? humidity;
  final DateTime fetchedAt;
  final double latitude;
  final double longitude;

  const WeatherEntity({
    required this.location,
    required this.temperature,
    required this.unit,
    required this.weatherCode,
    required this.weatherDescription,
    required this.windSpeed,
    this.humidity,
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
  });
}

