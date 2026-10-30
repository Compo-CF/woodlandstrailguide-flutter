import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trail_graph.dart';
import '../stores/trail_store.dart';
import '../stores/user_data_store.dart';
import '../theme/natural_palette.dart';
import '../widgets/trail_detail_sheet.dart';

/// Trails tab — grouped list of named trails, keyed by village/park.
/// Toolbar heart toggles a favorites-only filter. Mirrors iOS
/// ListTabView.swift.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _query = '';
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TrailStore>();
    final userData = context.watch<UserDataStore>();
    final graph = store.graph;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trails'),
        backgroundColor: NaturalPalette.cardBg,
        actions: [
          IconButton(
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            icon: Icon(
              _favoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _favoritesOnly ? NaturalPalette.route : NaturalPalette.forest,
            ),
            tooltip: _favoritesOnly ? 'Show all trails' : 'Show favorites only',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search trails, villages, parks',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(
            child: graph == null
                ? const Center(child: CircularProgressIndicator())
                : _buildList(graph, userData),
          ),
        ],
      ),
    );
  }

  Widget _buildList(TrailGraph graph, UserDataStore userData) {
    final matching = _matching(graph);
    final favorites = matching.where((w) => userData.isFavorite(w.favoriteKey)).toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    if (_favoritesOnly) {
      return favorites.isEmpty
          ? _emptyFavoritesState()
          : ListView(
              children: [_bucketSection('Favorites', favorites, userData)],
            );
    }

    // An empty result used to render nothing at all below the search box,
    // which reads as "still loading" or "broken" rather than "nothing matched"
    // (QA M-03). Gated on an active query: an empty graph is a different
    // failure, and TrailStore reports that one itself.
    if (matching.isEmpty && _query.trim().isNotEmpty) {
      return _noMatchesState();
    }

    final Map<String, List<Way>> buckets = {};
    for (final w in matching) {
      final key = w.village ?? w.park ?? w.system ?? 'Other';
      buckets.putIfAbsent(key, () => []).add(w);
    }
    final keys = buckets.keys.toList()..sort();

    return ListView(
      children: [
        // Favorites stay per-segment: the user saved one specific stretch,
        // and collapsing it would hide which of the 51 "Ridgewood Park"
        // pieces they actually picked.
        if (favorites.isNotEmpty) _bucketSection('Favorites', favorites, userData),
        for (final k in keys)
          _groupedBucketSection(k, _namedGroups(buckets[k]!), userData),
      ],
    );
  }

  List<Way> _matching(TrailGraph graph) {
    final q = _query.trim().toLowerCase();
    return graph.ways.where((w) => w.name != null).where((w) {
      if (q.isEmpty) return true;
      return (w.name ?? '').toLowerCase().contains(q) ||
          (w.village ?? '').toLowerCase().contains(q) ||
          (w.park ?? '').toLowerCase().contains(q);
    }).toList();
  }

  /// Shown when a search matches nothing. Names the query back, because the
  /// most common cause is a typo and seeing it repeated is what makes that
  /// obvious.
  Widget _noMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off,
                size: 48, color: NaturalPalette.inkMuted),
            const SizedBox(height: 12),
            const Text('No trails match',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: NaturalPalette.ink)),
            const SizedBox(height: 6),
            Text(
              'Nothing found for "${_query.trim()}". Try a village, a park, '
              'or part of a pathway name.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: NaturalPalette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFavoritesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.heart_broken_outlined,
                size: 48, color: NaturalPalette.inkMuted),
            const SizedBox(height: 12),
            const Text('No favorites yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: NaturalPalette.ink)),
            const SizedBox(height: 6),
            const Text(
              'Tap the heart on any trail to save it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NaturalPalette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// One row per segment. Used for Favorites, where the user picked a
  /// specific stretch and collapsing it would hide which one they saved.
  Widget _bucketSection(String title, List<Way> ways, UserDataStore userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        ...ways.map((w) => _segmentTile(w, userData)),
      ],
    );
  }

  /// One row per *name*, collapsing the Township's many same-named segments
  /// into a single entry (QA M-02).
  ///
  /// The GIS splits a named pathway into as many pieces as it has nodes:
  /// "Ridgewood Park" is 51 separate ways, "Lake Woodlands Dr" is 48. Listed
  /// raw, that is row after identical row told apart only by length, which is
  /// exactly what QA reported. iOS has collapsed these since it shipped
  /// (NamedTrailGroup in ListTabView); this brings Android in line.
  Widget _groupedBucketSection(
      String title, List<_NamedGroup> groups, UserDataStore userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        ...groups.map((g) {
          // A lone segment behaves exactly as before: no reason to make
          // someone tap through a list of one.
          if (g.ways.length == 1) return _segmentTile(g.ways.first, userData);

          final anyFav =
              g.ways.any((w) => userData.isFavorite(w.favoriteKey));
          return ListTile(
            leading: anyFav
                ? const Icon(Icons.favorite,
                    size: 18, color: NaturalPalette.route)
                : null,
            title: Text(g.name),
            subtitle: Text('${g.ways.length} segments'),
            trailing: Text('${g.totalMiles.toStringAsFixed(2)} mi',
                style: const TextStyle(color: NaturalPalette.inkMuted)),
            onTap: () => _showSegments(g, userData),
          );
        }),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: NaturalPalette.ink)),
    );
  }

  Widget _segmentTile(Way w, UserDataStore userData) {
    final isFav = userData.isFavorite(w.favoriteKey);
    return ListTile(
      leading: isFav
          ? const Icon(Icons.favorite, size: 18, color: NaturalPalette.route)
          : null,
      title: Text(w.name ?? 'Unnamed segment'),
      subtitle: w.surface != null ? Text(w.surface!) : null,
      trailing: Text('${w.miles.toStringAsFixed(2)} mi',
          style: const TextStyle(color: NaturalPalette.inkMuted)),
      onTap: () => TrailDetailSheet.show(context, w),
    );
  }

  /// The segments behind a grouped row, longest first.
  ///
  /// Ordering by length rather than by the graph's arbitrary order gives the
  /// list some meaning: the long runs are the ones somebody is likely looking
  /// for, and the 0.01 mi connectors sink to the bottom where they belong.
  void _showSegments(_NamedGroup group, UserDataStore userData) {
    final ways = [...group.ways]
      ..sort((a, b) => b.lengthMeters.compareTo(a.lengthMeters));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) => ListView(
            controller: controller,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Text(group.name,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: NaturalPalette.ink)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '${ways.length} segments · '
                  '${group.totalMiles.toStringAsFixed(2)} mi total',
                  style: const TextStyle(color: NaturalPalette.inkMuted),
                ),
              ),
              ...ways.map((w) => _segmentTile(w, userData)),
            ],
          ),
        ),
      ),
    );
  }

  /// Collapses every Way sharing a name into one entry. `_matching` already
  /// filters to named ways, so `name` is non-null here.
  List<_NamedGroup> _namedGroups(List<Way> ways) {
    final byName = <String, List<Way>>{};
    for (final w in ways) {
      byName.putIfAbsent(w.name ?? '', () => []).add(w);
    }
    final groups = byName.entries
        .map((e) => _NamedGroup(e.key, e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }
}

/// Way segments that share a display name.
class _NamedGroup {
  _NamedGroup(this.name, this.ways);

  final String name;
  final List<Way> ways;

  double get totalMiles =>
      ways.fold<double>(0, (sum, w) => sum + w.lengthMeters) / 1609.344;
}
