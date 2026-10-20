import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/polygon_catalog.dart';

/// Park / lake / village outlines and creek lines. Same bundled-seed +
/// Pages-refresh pattern as TrailStore and POIStore, mirroring iOS, where
/// POIStore owns this file.
///
/// Parsing runs on a background isolate via [compute]. That is not
/// premature: Polygons.json is ~1.1 MB and decodes to ~53,000 coordinates
/// across 372 rings and 221 creek lines. Decoding that on the main isolate
/// lands on exactly the launch path that previously produced an ANR on a
/// slow device, and it would do so while TrailStore is parsing its own
/// 3 MB graph.
class PolygonStore extends ChangeNotifier {
  static final Uri remoteURL =
      Uri.parse('https://compo-cf.github.io/woodlandstrailguide/Polygons.json');
  static const String bundledAsset = 'assets/data/Polygons.json';

  PolygonCatalog? _catalog;
  String? loadError;
  bool isLoading = false;

  PolygonCatalog? get catalog => _catalog;

  Future<void> load() async {
    await _loadBundled();
    unawaited(refresh());
  }

  Future<void> _loadBundled() async {
    try {
      final raw = await rootBundle.loadString(bundledAsset);
      _catalog = await compute(_parse, raw);
      notifyListeners();
    } catch (e) {
      // Context overlays are decoration, not function — the map is fully
      // usable without them, so a failure here is recorded and swallowed
      // rather than surfaced as an error state the way a missing trail
      // graph is.
      loadError = 'Bundled polygon data failed to load: $e';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    try {
      final response = await http.get(remoteURL);
      if (response.statusCode == 200) {
        final fresh = await compute(_parse, response.body);
        // Only swap if the Township actually published something newer.
        // Replacing the catalog with an equal-but-different instance would
        // invalidate the map's overlay cache (which is keyed on identity)
        // and force a full rebuild of 331 polygons for no visible change —
        // the same trap TrailStore documents for its own refresh.
        if (fresh.version > (_catalog?.version ?? -1)) {
          _catalog = fresh;
          loadError = null;
          notifyListeners();
        }
      }
    } catch (_) {
      // Keep bundled data.
    } finally {
      isLoading = false;
    }
  }
}

/// Top-level so it can be handed to [compute] — closures and instance
/// methods can't cross an isolate boundary.
PolygonCatalog _parse(String raw) =>
    PolygonCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
