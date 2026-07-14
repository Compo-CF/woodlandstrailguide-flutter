// Parses/builds woodlandstrailguide://route?start=LAT,LON&end=LAT,LON
// &via=LAT,LON|LAT,LON deep links. Direct port of iOS
// RoutingBridge.parse / buildShareURL.

import '../state/routing_state.dart';

class RoutingBridge {
  /// Parses a URI of the form
  ///   woodlandstrailguide://route?start=LAT,LON&end=LAT,LON&via=LAT,LON|LAT,LON
  /// Returns null on any parse failure — bad URLs are silently ignored.
  static PendingRoute? parse(Uri uri) {
    if (uri.scheme.toLowerCase() != 'woodlandstrailguide') return null;
    final isRouteHost = uri.host.toLowerCase() == 'route';
    final isRoutePath = uri.path.toLowerCase().endsWith('/route');
    if (!isRouteHost && !isRoutePath) return null;

    final params = uri.queryParameters;
    final start = _parseCoord(params['start']);
    final end = _parseCoord(params['end']);
    if (start == null || end == null) return null;

    var waypoints = <List<double>>[];
    final viaRaw = params['via'];
    if (viaRaw != null && viaRaw.isNotEmpty) {
      waypoints = viaRaw
          .split('|')
          .map(_parseCoord)
          .whereType<List<double>>()
          .toList();
    }

    return PendingRoute(
      startLat: start[0],
      startLon: start[1],
      endLat: end[0],
      endLon: end[1],
      waypoints: waypoints,
    );
  }

  static List<double>? _parseCoord(String? s) {
    if (s == null) return null;
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return [lat, lon];
  }

  /// Builds a share URL for a computed route so users can send it to
  /// someone else with the app installed.
  static Uri buildShareUrl({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    List<List<double>> waypoints = const [],
  }) {
    final params = <String, String>{
      'start': _coordString(startLat, startLon),
      'end': _coordString(endLat, endLon),
    };
    if (waypoints.isNotEmpty) {
      params['via'] = waypoints.map((w) => _coordString(w[0], w[1])).join('|');
    }
    return Uri(scheme: 'woodlandstrailguide', host: 'route', queryParameters: params);
  }

  static String _coordString(double lat, double lon) =>
      '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
}
