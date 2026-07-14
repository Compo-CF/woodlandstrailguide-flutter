// Wraps WeatherService with debounced refresh + cached snapshot.
// Direct port of iOS WeatherStore — refreshes no more than once per 15
// minutes at roughly the same location, unless force:true.

import 'package:flutter/foundation.dart';

import '../services/weather_service.dart';

class WeatherStore extends ChangeNotifier {
  WeatherSnapshot? snapshot;
  DateTime? lastFetch;
  ({double lat, double lon})? _lastFetchLocation;
  bool isFetching = false;

  static const _refreshInterval = Duration(minutes: 15);

  /// The Woodlands centroid — fallback when we don't have user location.
  static const _fallbackLat = 30.1658;
  static const _fallbackLon = -95.4613;

  Future<void> refresh({double? latitude, double? longitude, bool force = false}) async {
    final lat = latitude ?? _fallbackLat;
    final lon = longitude ?? _fallbackLon;

    if (!force &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch!) < _refreshInterval &&
        _lastFetchLocation != null &&
        (_lastFetchLocation!.lat - lat).abs() < 0.02 &&
        (_lastFetchLocation!.lon - lon).abs() < 0.02) {
      return;
    }

    isFetching = true;
    notifyListeners();
    try {
      final snap = await WeatherService.fetch(latitude: lat, longitude: lon);
      snapshot = snap;
      lastFetch = DateTime.now();
      _lastFetchLocation = (lat: lat, lon: lon);
    } catch (_) {
      // Keep the previous snapshot on failure — silently swallow.
    } finally {
      isFetching = false;
      notifyListeners();
    }
  }
}
