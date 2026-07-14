import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/featured_walk.dart';
import '../state/routing_state.dart';
import '../stores/featured_walk_store.dart';
import '../theme/natural_palette.dart';

/// Featured tab — curator-managed walks, cards laid out like the iOS
/// FeaturedTabView.swift. Tapping a card opens a detail sheet with a
/// "Walk this route" button that pushes the walk's waypoints into
/// RoutingState.pending — RootTabShell watches for that and switches
/// to the Map tab, where MapScreen resolves + applies it.
class FeaturedScreen extends StatelessWidget {
  const FeaturedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FeaturedWalkStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Featured Walks'),
        backgroundColor: NaturalPalette.cardBg,
      ),
      body: store.walks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => store.refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: store.walks.length,
                itemBuilder: (context, i) =>
                    _walkCard(context, store.walks[i]),
              ),
            ),
    );
  }

  Widget _walkCard(BuildContext context, FeaturedWalk walk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: NaturalPalette.cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(context, walk),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NaturalPalette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(walk.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: NaturalPalette.ink)),
                    ),
                    _difficultyChip(walk.difficulty),
                  ],
                ),
                const SizedBox(height: 8),
                Text(walk.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NaturalPalette.inkMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  _metaLabel(Icons.directions_walk,
                      '${walk.distanceMiles.toStringAsFixed(1)} mi'),
                  if ((walk.elevationGainFeet ?? 0) > 0) ...[
                    const SizedBox(width: 12),
                    _metaLabel(Icons.trending_up,
                        '${walk.elevationGainFeet!.toInt()} ft up'),
                  ],
                  if (walk.village != null) ...[
                    const SizedBox(width: 12),
                    _metaLabel(Icons.place, walk.village!),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, FeaturedWalk walk) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _FeaturedWalkDetailSheet(walk: walk),
    );
  }

  Widget _difficultyChip(DifficultyRating d) {
    final color = switch (d) {
      DifficultyRating.easy => const Color(0xFF5CA857),
      DifficultyRating.moderate => const Color(0xFFD9A826),
      DifficultyRating.strenuous => const Color(0xFFD3603D),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(d.label.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  Widget _metaLabel(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: NaturalPalette.inkMuted),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(color: NaturalPalette.inkMuted, fontSize: 12)),
    ]);
  }
}

class _FeaturedWalkDetailSheet extends StatelessWidget {
  final FeaturedWalk walk;
  const _FeaturedWalkDetailSheet({required this.walk});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NaturalPalette.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(walk.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: NaturalPalette.ink)),
            const SizedBox(height: 8),
            Text(walk.description,
                style: const TextStyle(color: NaturalPalette.ink, fontSize: 14)),
            if (walk.highlights.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('HIGHLIGHTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: NaturalPalette.inkMuted,
                      letterSpacing: 0.6)),
              const SizedBox(height: 6),
              ...walk.highlights.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 14, color: NaturalPalette.forest),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(h,
                              style: const TextStyle(
                                  color: NaturalPalette.ink, fontSize: 13.5)),
                        ),
                      ],
                    ),
                  )),
            ],
            if (walk.bestTime != null || walk.seasonality != null) ...[
              const SizedBox(height: 16),
              if (walk.bestTime != null)
                Text('Best time: ${walk.bestTime}',
                    style: const TextStyle(
                        fontSize: 12.5, color: NaturalPalette.inkMuted)),
              if (walk.seasonality != null)
                Text('Season: ${walk.seasonality}',
                    style: const TextStyle(
                        fontSize: 12.5, color: NaturalPalette.inkMuted)),
            ],
            if (walk.curatedBy != null) ...[
              const SizedBox(height: 8),
              Text('Curated by ${walk.curatedBy}',
                  style: const TextStyle(
                      fontSize: 11, color: NaturalPalette.inkMuted)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: walk.waypoints.length >= 2
                    ? () => _walkThisRoute(context)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: NaturalPalette.route,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Walk this route',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _walkThisRoute(BuildContext context) {
    final stops = walk.waypoints;
    final start = stops.first;
    final end = stops.last;
    final via = stops
        .sublist(1, stops.length - 1)
        .map((w) => [w.lat, w.lon])
        .toList();
    context.read<RoutingState>().requestRoute(
          startLat: start.lat,
          startLon: start.lon,
          endLat: end.lat,
          endLon: end.lon,
          waypoints: via,
        );
    Navigator.of(context).pop();
  }
}
