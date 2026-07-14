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

    final Map<String, List<Way>> buckets = {};
    for (final w in matching) {
      final key = w.village ?? w.park ?? w.system ?? 'Other';
      buckets.putIfAbsent(key, () => []).add(w);
    }
    final keys = buckets.keys.toList()..sort();

    return ListView(
      children: [
        if (favorites.isNotEmpty) _bucketSection('Favorites', favorites, userData),
        for (final k in keys)
          _bucketSection(
            k,
            buckets[k]!..sort((a, b) => (a.name ?? '').compareTo(b.name ?? '')),
            userData,
          ),
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

  Widget _bucketSection(String title, List<Way> ways, UserDataStore userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: NaturalPalette.ink)),
        ),
        ...ways.map((w) {
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
        }),
      ],
    );
  }
}
