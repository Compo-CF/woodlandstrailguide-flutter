import 'package:flutter/material.dart';

import '../models/trail_graph.dart';
import '../theme/natural_palette.dart';

/// Modal bottom sheet showing a Way's details. Mirrors iOS
/// TrailDetailSheet.swift.
class TrailDetailSheet extends StatelessWidget {
  final Way way;
  const TrailDetailSheet({super.key, required this.way});

  /// Convenience helper — call from anywhere with a BuildContext to
  /// present the sheet.
  static Future<void> show(BuildContext context, Way way) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TrailDetailSheet(way: way),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = way.name ?? 'Trail segment';
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dragHandle(),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: NaturalPalette.ink)),
              const SizedBox(height: 4),
              Text(way.kind == 'trail' ? 'Natural trail' : 'Paved pathway',
                  style: const TextStyle(
                      color: NaturalPalette.inkMuted, fontSize: 13)),
              const SizedBox(height: 20),
              _row('Length', '${way.miles.toStringAsFixed(2)} mi'),
              if (way.surface != null) _row('Surface', _capitalize(way.surface!)),
              if (way.village != null) _row('Village', way.village!),
              if (way.park != null) _row('Park', way.park!),
              if (way.system != null) _row('System', way.system!),
              if (way.parks != null && way.parks!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Connects to',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: NaturalPalette.ink)),
                const SizedBox(height: 6),
                ...way.parks!.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.park_outlined,
                              size: 16, color: Color(0xFF228B45)),
                          const SizedBox(width: 8),
                          Text(p, style: const TextStyle(color: NaturalPalette.ink)),
                        ],
                      ),
                    )),
              ],
              if (way.pathwayID != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: NaturalPalette.chipBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Township ref: ${way.pathwayID}',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: NaturalPalette.inkMuted)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: NaturalPalette.hairline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: NaturalPalette.inkMuted, fontSize: 14)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: NaturalPalette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
