import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/featured_walk.dart';

class FeaturedWalkStore extends ChangeNotifier {
  static final Uri remoteURL = Uri.parse(
      'https://compo-cf.github.io/woodlandstrailguide/FeaturedWalks.json');
  static const String bundledAsset = 'assets/data/FeaturedWalks.json';

  List<FeaturedWalk> walks = [];
  String? loadError;
  bool isLoading = false;

  Future<void> load() async {
    await _loadBundled();
    unawaited(refresh());
  }

  Future<void> _loadBundled() async {
    try {
      final raw = await rootBundle.loadString(bundledAsset);
      final decoded = jsonDecode(raw) as List<dynamic>;
      walks = decoded
          .map((w) => FeaturedWalk.fromJson(w as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      loadError = 'Bundled featured walks failed to load: $e';
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
        final decoded = jsonDecode(response.body) as List<dynamic>;
        walks = decoded
            .map((w) => FeaturedWalk.fromJson(w as Map<String, dynamic>))
            .toList();
        loadError = null;
      }
    } catch (_) {
      // Silent.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

