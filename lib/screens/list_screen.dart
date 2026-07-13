import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trail_graph.dart';
import '../stores/trail_store.dart';
import '../theme/natural_palette.dart';

/// Trails tab — grouped list of named trails, keyed by village/park.
/// Mirrors iOS ListTabView.swift.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TrailStore>();
    final graph = store.graph;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trails'),
        backgroundColor: NaturalPalette.cardBg,
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
                : _groupedList(graph),
          ),
        ],
      ),
    );
  }

  Widget _groupedList(TrailGraph graph) {
    final q = _query.trim().toLowerCase();
    final named = graph.ways.where((w) => w.name != null).where((w) {
      if (q.isEmpty) return true;
      return (w.name ?? '').toLowerCase().contains(q) ||
          (w.village ?? '').toLowerCase().contains(q) ||
          (w.park ?? '').toLowerCase().contains(q);
    }).toList();

    final Map<String, List<Way>> buckets = {};
    for (final w in named) {
      final key = w.village ?? w.park ?? w.system ?? 'Other';
      buckets.putIfAbsent(key, () => []).add(w);
    }
    final keys = buckets.keys.toList()..sort();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final k = keys[i];
        final ways = buckets[k]!..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        return _bucketSection(k, ways);
      },
    );
  }

  Widget _bucketSection(String title, List<Way> ways) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: NaturalPalette.ink)),
        ),
        ...ways.map((w) => ListTile(
              title: Text(w.name ?? 'Unnamed segment'),
              subtitle: w.surface != null ? Text(w.surface!) : null,
              trailing: Text('${w.miles.toStringAsFixed(2)} mi',
                  style: const TextStyle(color: NaturalPalette.inkMuted)),
              onTap: () {
                // TODO: TrailDetailSheet
              },
            )),
      ],
    );
  }
}
