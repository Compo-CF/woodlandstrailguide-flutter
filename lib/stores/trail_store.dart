// TrailStore — same bundled-seed + Pages-refresh pattern as the iOS
// TrailStore.swift. Flutter equivalent of @Observable is
// ChangeNotifier; UI rebuilds when notifyListeners() is called.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/trail_graph.dart';
import '../services/debug_log.dart';

class TrailStore extends ChangeNotifier {
  static final Uri remoteURL = Uri.parse(
      'https://compo-cf.github.io/woodlandstrailguide/TrailGraph.json');
  static const String bundledAsset = 'assets/data/TrailGraph.json';

  TrailGraph? _graph;
  String? loadError;
  bool isLoading = false;

  /// Raw JSON text behind the current `_graph`. Kept so the background
  /// refresh() below doesn't replace `_graph` with a brand-new object
  /// instance when the remote data is byte-for-byte identical to what's
  /// already loaded (the common case — Township GIS data doesn't change
  /// often). MapScreen caches its ~1,500 trail polylines + ~3,400 POI
  /// markers keyed on `identical(graph, ...)`; swapping in an
  /// equal-but-different-identity object forced a full, expensive
  /// second rebuild of the entire trail network moments after the
  /// first one — on a real device this showed up as a very slow map
  /// load that could run long enough to trip an ANR.
  String? _rawJson;

  TrailGraph? get graph => _graph;

  /// Loads the bundled JSON first for instant display, then fires a
  /// background refresh against GitHub Pages so the user gets the latest
  /// Township data without waiting.
  Future<void> load() async {
    await _loadBundled();
    unawaited(refresh());
  }

  Future<void> _loadBundled() async {
    await DebugLog.log('TrailStore._loadBundled() start');
    try {
      final raw = await rootBundle.loadString(bundledAsset);
      await DebugLog.log(
          'TrailStore._loadBundled() asset read, ${raw.length} chars, calling _applyRaw');
      _applyRaw(raw);
      await DebugLog.log('TrailStore._loadBundled() done');
    } catch (e) {
      loadError = 'Bundled trail data failed to load: $e';
      await DebugLog.log('TrailStore._loadBundled() FAILED: $e');
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    await DebugLog.log('TrailStore.refresh() start (fetching $remoteURL)');
    try {
      final response = await http.get(remoteURL);
      await DebugLog.log(
          'TrailStore.refresh() got HTTP ${response.statusCode}, ${response.body.length} chars');
      if (response.statusCode == 200) {
        _applyRaw(response.body);
        loadError = null;
      }
    } catch (e) {
      await DebugLog.log('TrailStore.refresh() FAILED: $e');
      // Silent — keep whatever bundled data we already have.
    } finally {
      isLoading = false;
      notifyListeners();
      await DebugLog.log('TrailStore.refresh() done');
    }
  }

  /// Parses and assigns new trail data ONLY if the raw JSON actually
  /// differs from what's already loaded — see `_rawJson` doc comment.
  void _applyRaw(String raw) {
    if (raw == _rawJson) {
      unawaited(DebugLog.log(
          'TrailStore._applyRaw: raw JSON unchanged, skipping reparse'));
      return;
    }
    final sw = Stopwatch()..start();
    _graph = TrailGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _rawJson = raw;
    unawaited(DebugLog.log(
        'TrailStore._applyRaw: parsed NEW graph in ${sw.elapsedMilliseconds}ms '
        '(${_graph!.ways.length} ways, ${_graph!.nodes.length} nodes)'));
    notifyListeners();
  }
}

/// Fire-and-forget helper (Dart doesn't have this built in).
