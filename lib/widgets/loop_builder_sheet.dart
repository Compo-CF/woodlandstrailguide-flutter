import 'package:flutter/material.dart';

import '../theme/natural_palette.dart';

/// Bottom sheet for generating an out-and-back loop of a chosen distance
/// from the user's current location. Direct port of iOS
/// LoopBuilderSheet.swift — segmented distance picker (1/2/3/5/8 mi),
/// "Generate loop" button. MapScreen resolves the actual start/far
/// nodes via Router.nearestNode + Router.farthestNode(atRouteDistance:
/// miles * 1609.344 / 2) and plugs them into RoutingState as
/// [start, far, start].
class LoopBuilderSheet extends StatefulWidget {
  final void Function(double miles) onGenerate;

  const LoopBuilderSheet({super.key, required this.onGenerate});

  static Future<void> show(BuildContext context,
      {required void Function(double miles) onGenerate}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LoopBuilderSheet(onGenerate: onGenerate),
    );
  }

  @override
  State<LoopBuilderSheet> createState() => _LoopBuilderSheetState();
}

class _LoopBuilderSheetState extends State<LoopBuilderSheet> {
  double _selectedMiles = 2;
  static const _options = <double>[1, 2, 3, 5, 8];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const SizedBox(height: 20),
            const Icon(Icons.all_inclusive, size: 56, color: NaturalPalette.forest),
            const SizedBox(height: 16),
            const Text('Loop from here',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: NaturalPalette.ink)),
            const SizedBox(height: 10),
            const Text(
              "Pick a rough distance. We'll route you to a point about halfway there and back.",
              textAlign: TextAlign.center,
              style: TextStyle(color: NaturalPalette.inkMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: _options.map((m) {
                final selected = m == _selectedMiles;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMiles = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? NaturalPalette.forest : NaturalPalette.chipBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${m.toInt()} mi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : NaturalPalette.forest)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onGenerate(_selectedMiles);
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: NaturalPalette.forest,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.directions_walk),
                label: const Text('Generate loop',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: NaturalPalette.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
