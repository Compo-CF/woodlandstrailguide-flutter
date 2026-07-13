import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/featured_walk.dart';
import '../stores/featured_walk_store.dart';
import '../theme/natural_palette.dart';

/// Featured tab — curator-managed walks, cards laid out like the iOS
/// FeaturedTabView.swift.
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
                itemBuilder: (context, i) => _walkCard(store.walks[i]),
              ),
            ),
    );
  }

  Widget _walkCard(FeaturedWalk walk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NaturalPalette.cardBg,
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
