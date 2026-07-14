// Fetches elevation samples along a route from Open-Elevation
// (open-elevation.com — free public API, no key, batch POST endpoint).
// Direct port of iOS ElevationService.swift: same 100m sample spacing
// capped at 100 samples, same coordinate-hash cache key, same on-disk
// cache trimmed to 50 entries. Cache miss or failed fetch just hides
// the profile — routing doesn't need elevation to be usable.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/trail_graph.dart';
import '../services/router.dart';

class ElevationProfile {
  /// Cumulative distance along the route, meters.
  final List<double> distancesMeters;
  /// Elevation at each sample, meters above sea level.
  final List<double> elevationsMeters;

  const ElevationProfile({required this.distancesMeters, required this.elevationsMeters});

  double get gainMeters {
    var g = 0.0;
    for (var i = 1; i < elevationsMeters.length; i++) {
      final d = elevationsMeters[i] - elevationsMeters[i - 1];
      if (d > 0) g += d;
    }
    return g;
  }

  double get lossMeters {
    var l = 0.0;
    for (var i = 1; i < elevationsMeters.length; i++) {
      final d = elevationsMeters[i] - elevationsMeters[i - 1];
      if (d < 0) l -= d;
    }
    return l;
  }

  double get minMeters => elevationsMeters.isEmpty
      ? 0
      : elevationsMeters.reduce((a, b) => a < b ? a : b);
  double get maxMeters => elevationsMeters.isEmpty
      ? 0
      : elevationsMeters.reduce((a, b) => a > b ? a : b);

  double get gainFeet => gainMeters * 3.28084;
  double get lossFeet => lossMeters * 3.28084;
}

class _Sample {
  final double distance;
  final double lat;
  final double lon;
  const _Sample(this.distance, this.lat, this.lon);
}

class ElevationService extends ChangeNotifier {
  static const _sampleSpacingMeters = 100.0;
  static const _maxSamples = 100;

  /// route-hash -> elevations (meters), parallel to that hash's samples.
  final Map<String, List<double>> _cache = {};
  final Set<String> _inflight = {};

  Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/elevation_cache.json');
  }

  Future<void> load() async {
    try {
      final file = await _cacheFile;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        _cache[key] = (value as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      });
    } catch (_) {
      // Corrupt or missing cache — start fresh.
    }
  }

  /// Returns a cached profile if available; otherwise kicks off a
  /// background fetch (caller re-checks after the next notifyListeners)
  /// and returns null in the meantime.
  ElevationProfile? profile(RouteResult route, TrailGraph graph) {
    final samples = _sample(route, graph);
    if (samples.isEmpty) return null;
    final key = _hashKey(samples);
    final cached = _cache[key];
    if (cached != null && cached.length == samples.length) {
      return ElevationProfile(
        distancesMeters: samples.map((s) => s.distance).toList(),
        elevationsMeters: cached,
      );
    }
    if (!_inflight.contains(key)) {
      _inflight.add(key);
      unawaited(_fetch(key, samples));
    }
    return null;
  }

  List<_Sample> _sample(RouteResult route, TrailGraph graph) {
    if (route.nodes.length < 2) return const [];
    final cum = <double>[0];
    for (var i = 1; i < route.nodes.length; i++) {
      final a = graph.nodes[route.nodes[i - 1]];
      final b = graph.nodes[route.nodes[i]];
      cum.add(cum[i - 1] + _haversine(a.lat, a.lon, b.lat, b.lon));
    }
    final total = cum.last;
    if (total <= 0) return const [];
    final count = math.min(_maxSamples, math.max(2, (total / _sampleSpacingMeters).toInt() + 1));
    final step = total / (count - 1);

    final out = <_Sample>[];
    var segIdx = 0;
    for (var i = 0; i < count; i++) {
      final target = i * step;
      while (segIdx + 1 < cum.length - 1 && cum[segIdx + 1] < target) {
        segIdx++;
      }
      final d0 = cum[segIdx];
      final d1 = cum[segIdx + 1];
      final t = d1 > d0 ? (target - d0) / (d1 - d0) : 0.0;
      final a = graph.nodes[route.nodes[segIdx]];
      final b = graph.nodes[route.nodes[segIdx + 1]];
      final lat = a.lat + (b.lat - a.lat) * t;
      final lon = a.lon + (b.lon - a.lon) * t;
      out.add(_Sample(target, lat, lon));
    }
    return out;
  }

  String _hashKey(List<_Sample> samples) {
    var hash = 0;
    for (final s in samples) {
      hash = 0x1fffffff & (hash + (s.lat * 1e5).round());
      hash = 0x1fffffff & (hash + ((hash << 10) & 0x3fffff));
      hash ^= hash >> 6;
      hash = 0x1fffffff & (hash + (s.lon * 1e5).round());
      hash = 0x1fffffff & (hash + ((hash << 10) & 0x3fffff));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + (hash << 3));
    hash ^= hash >> 11;
    hash = 0x3fffffff & (hash + (hash << 15));
    return '$hash-${samples.length}';
  }

  Future<void> _fetch(String key, List<_Sample> samples) async {
    try {
      final uri = Uri.parse('https://api.open-elevation.com/api/v1/lookup');
      final body = jsonEncode({
        'locations': samples.map((s) => {'latitude': s.lat, 'longitude': s.lon}).toList(),
      });
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>;
      final elevations = results
          .map((r) => ((r as Map<String, dynamic>)['elevation'] as num).toDouble())
          .toList();
      if (elevations.length != samples.length) return;
      _cache[key] = elevations;
      await _persist();
      notifyListeners();
    } catch (_) {
      // Open-Elevation is occasionally flaky — swallow silently.
    } finally {
      _inflight.remove(key);
    }
  }

  Future<void> _persist() async {
    // Cap on-disk cache to the 50 most-recent entries.
    Map<String, List<double>> trimmed = _cache;
    if (_cache.length > 50) {
      final entries = _cache.entries.toList();
      trimmed = Map.fromEntries(entries.sublist(entries.length - 50));
    }
    try {
      final file = await _cacheFile;
      await file.writeAsString(jsonEncode(trimmed));
    } catch (_) {}
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

void unawaited(Future<void> future) {}
