// Fetches current weather from Open-Meteo (free, no API key, unlimited
// use for a hobby-scale app). Direct port of iOS WeatherService.swift —
// same fields, same WMO weather-code mapping, same walking-advisory
// thresholds (Texas heat + active precipitation are what actually
// change a walk).

import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherSnapshot {
  final double temperatureF;
  final int weatherCode;
  final double windMph;
  final int windDirectionDegrees;

  const WeatherSnapshot({
    required this.temperatureF,
    required this.weatherCode,
    required this.windMph,
    required this.windDirectionDegrees,
  });

  String get conditionLabel {
    switch (weatherCode) {
      case 0: return 'Clear';
      case 1: return 'Mainly clear';
      case 2: return 'Partly cloudy';
      case 3: return 'Overcast';
      case 45: case 48: return 'Fog';
      case 51: case 53: case 55: return 'Drizzle';
      case 56: case 57: return 'Freezing drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 66: case 67: return 'Freezing rain';
      case 71: case 73: case 75: case 77: return 'Snow';
      case 80: case 81: case 82: return 'Showers';
      case 85: case 86: return 'Snow showers';
      case 95: return 'Thunderstorm';
      case 96: case 99: return 'Thunderstorm with hail';
      default: return '—';
    }
  }

  /// Material icon matching the SF Symbol iOS uses for each condition.
  String get conditionIconName {
    switch (weatherCode) {
      case 0: return 'wb_sunny';
      case 1: case 2: return 'wb_cloudy';
      case 3: return 'cloud';
      case 45: case 48: return 'foggy';
      case 51: case 53: case 55: case 80: case 81: case 82: return 'grain';
      case 56: case 57: case 66: case 67: return 'ac_unit';
      case 61: case 63: case 65: return 'water_drop';
      case 71: case 73: case 75: case 77: case 85: case 86: return 'ac_unit';
      case 95: case 96: case 99: return 'thunderstorm';
      default: return 'cloud';
    }
  }

  String get windCardinal {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((windDirectionDegrees + 22.5) / 45.0).floor() % 8;
    return dirs[index];
  }

  String get summary {
    final temp = temperatureF.round();
    final wind = windMph.round();
    return '$temp°F · $conditionLabel · Wind $wind mph $windCardinal';
  }

  /// Recommend caution when hiking conditions are meaningfully off. Null
  /// if it's fine.
  String? get walkingAdvisory {
    if ({95, 96, 99}.contains(weatherCode)) return 'Thunderstorm — head indoors';
    if ((weatherCode >= 61 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      return 'Rain — pathways may be slippery';
    }
    if (temperatureF >= 100) return 'Extreme heat — bring water';
    if (temperatureF >= 90) return 'Hot — bring water';
    return null;
  }
}

class WeatherService {
  static Future<WeatherSnapshot> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m,weather_code,wind_speed_10m,wind_direction_10m',
      'temperature_unit': 'fahrenheit',
      'wind_speed_unit': 'mph',
      'timezone': 'auto',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Weather request failed: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final current = decoded['current'] as Map<String, dynamic>;
    return WeatherSnapshot(
      temperatureF: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      windMph: (current['wind_speed_10m'] as num).toDouble(),
      windDirectionDegrees: (current['wind_direction_10m'] as num).toInt(),
    );
  }
}
