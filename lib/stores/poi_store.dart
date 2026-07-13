import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/poi.dart';

/// POI catalog + categories. Bundled JSON + optional Pages refresh.
class POIStore extends ChangeNotifier {
  static final Uri remoteURL =
      Uri.parse('https://compo-cf.github.io/woodlandstrailguide/POIs.json');
  static const String bundledAsset = 'assets/data/POIs.json';

  POICatalog? _catalog;
  String? loadError;
  bool isLoading = false;

  POICatalog? get catalog => _catalog;
  List<POI> get pois => _catalog?.allPOIs ?? const [];
  List<POICategory> get categories => _catalog?.categories ?? const [];

  Future<void> load() async {
    await _loadBundled();
    unawaited(refresh());
  }

  Future<void> _loadBundled() async {
    try {
      final raw = await rootBundle.loadString(bundledAsset);
      _catalog = POICatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    } catch (e) {
      loadError = 'Bundled POI data failed to load: $e';
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
        _catalog = POICatalog.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        loadError = null;
      }
    } catch (_) {
      // Keep bundled data.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

