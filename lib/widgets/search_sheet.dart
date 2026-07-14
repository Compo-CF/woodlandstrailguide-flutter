import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/poi.dart';
import '../models/trail_graph.dart';
import '../theme/natural_palette.dart';

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final double lat;
  final double lon;
  final double score;
  /// Non-null when this result is a POI — lets the caller open the full
  /// POI detail sheet instead of just panning the map.
  final POI? poi;
  final POICategory? category;
  /// Non-null when this result is a trail — lets the caller open
  /// TrailDetailSheet directly instead of just panning the map.
  final Way? way;

  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.lat,
    required this.lon,
    required this.score,
    this.poi,
    this.category,
    this.way,
  });
}

/// Search across trails, parks, and POIs. Direct port of iOS
/// MapSearchSheet — same relevance scoring (exact > prefix > contains,
/// plus a distance-from-user bump), same 40-result cap.
class SearchSheet extends StatefulWidget {
  final TrailGraph graph;
  final List<POICategory> categories;
  final Position? userLocation;
  final void Function(SearchResult) onSelect;

  const SearchSheet({
    super.key,
    required this.graph,
    required this.categories,
    required this.userLocation,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required TrailGraph graph,
    required List<POICategory> categories,
    required Position? userLocation,
    required void Function(SearchResult) onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SearchSheet(
          graph: graph,
          categories: categories,
          userLocation: userLocation,
          onSelect: onSelect,
        ),
      ),
    );
  }

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty ? const <SearchResult>[] : _search(q);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Trails, parks, amenities',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: NaturalPalette.chipBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Search for a trail, park, or amenity by name — 'Sawmill', "
                      "'Bear Branch', 'restroom', 'bridge'.",
                      style: TextStyle(color: NaturalPalette.inkMuted),
                    ),
                  )
                : results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No matches for "$_query"',
                            style: const TextStyle(color: NaturalPalette.inkMuted)),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final r = results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: r.tint,
                              child: Icon(r.icon, size: 16, color: Colors.white),
                            ),
                            title: Text(r.title),
                            subtitle: Text(r.subtitle),
                            onTap: () {
                              widget.onSelect(r);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  List<SearchResult> _search(String q) {
    final results = <SearchResult>[];
    final seenTrailKeys = <String>{};

    for (final way in widget.graph.ways) {
      final name = way.name;
      if (name == null) continue;
      final lowered = name.toLowerCase();
      if (!lowered.contains(q)) continue;
      if (!seenTrailKeys.add(lowered)) continue;
      if (way.nodeIndices.isEmpty) continue;
      final firstIdx = way.nodeIndices.first;
      if (firstIdx >= widget.graph.nodes.length) continue;
      final coord = widget.graph.nodes[firstIdx];
      final subtitleParts = [way.village, way.park].whereType<String>();
      final subtitle = subtitleParts.isEmpty ? 'Pathway' : subtitleParts.join(' · ');
      results.add(SearchResult(
        id: 'trail:$lowered',
        title: name,
        subtitle: subtitle,
        icon: Icons.route,
        tint: NaturalPalette.forest,
        lat: coord.lat,
        lon: coord.lon,
        score: _relevance(lowered, q, _distanceFromUser(coord.lat, coord.lon)),
        way: way,
      ));
    }

    for (final cat in widget.categories) {
      final categoryMatches = cat.label.toLowerCase().contains(q);
      final tint = Color(0xFF000000 | cat.tintHex);
      for (final poi in cat.pois) {
        final name = (poi.name ?? '').toLowerCase();
        final park = (poi.park ?? '').toLowerCase();
        final village = (poi.village ?? '').toLowerCase();
        final hit = name.contains(q) ||
            park.contains(q) ||
            village.contains(q) ||
            categoryMatches;
        if (!hit) continue;
        final title = poi.name ?? cat.label;
        final subtitle = poi.park ?? poi.village ?? cat.label;
        results.add(SearchResult(
          id: 'poi:${cat.key}:${poi.id}',
          title: title,
          subtitle: subtitle,
          icon: Icons.place,
          tint: tint,
          lat: poi.lat,
          lon: poi.lon,
          score: _relevance(title.toLowerCase(), q, _distanceFromUser(poi.lat, poi.lon)),
          poi: poi,
          category: cat,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(40).toList();
  }

  double _relevance(String candidate, String q, double? distance) {
    var score = 0.0;
    if (candidate == q) {
      score += 100;
    } else if (candidate.startsWith(q)) {
      score += 60;
    } else if (candidate.contains(q)) {
      score += 20;
    }
    if (distance != null) {
      score += (15 - distance / 500).clamp(0, 15);
    }
    return score;
  }

  double? _distanceFromUser(double lat, double lon) {
    final u = widget.userLocation;
    if (u == null) return null;
    return Geolocator.distanceBetween(u.latitude, u.longitude, lat, lon);
  }
}
