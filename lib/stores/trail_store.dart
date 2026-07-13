// TrailStore — same bundled-seed + Pages-refresh pattern as the iOS
// TrailStore.swift. Flutter equivalent of @Observable is
// ChangeNotifier; UI rebuilds when notifyListeners() is called.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/trail_graph.dart';

class TrailStore extends ChangeNotifier {
  static final Uri remoteURL = Uri.parse(
      'https://compo-cf.github.io/woodlandstrailguide/TrailGraph.json');
  static const String bundledAsset = 'assets/data/TrailGraph.json';

  TrailGraph? _graph;
  String? loadError;
  bool isLoading = false;

  TrailGraph? get graph => _graph;

  /// Loads the bundled JSON first for instant display, then fires a
  /// background refresh against GitHub Pages so the user gets the latest
  /// Township data without waiting.
  Future<void> load() async {
    await _loadBundled();
    unawaited(refresh());
  }

  Future<void> _loadBundled() async {
    try {
      final raw = await rootBundle.loadString(bundledAsset);
      _graph = TrailGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    } catch (e) {
      loadError = 'Bundled trail data failed to load: $e';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(remoteURL);
      if (response.statusCode == 200) {
        _graph = TrailGraph.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        loadError = null;
      }
    } catch (e) {
      // Silent — keep whatever bundled data we already have.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

/// Fire-and-forget helper (Dart doesn't have this built in).
