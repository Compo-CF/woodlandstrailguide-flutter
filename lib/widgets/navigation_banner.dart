import 'package:flutter/material.dart';

import '../services/router.dart';
import '../theme/natural_palette.dart';

/// Turn-by-turn instruction card shown during live navigation. Direct
/// port of iOS MapTabView.navigationBanner: big icon + verb + street
/// name + distance-to-next, a divider, then remaining distance/time +
/// End button, with an off-route warning row that appears past 30m
/// drift (a lighter early-warning threshold than the 100m/8s that
/// triggers an actual reroute).
class NavigationBanner extends StatelessWidget {
  final RouteResult route;
  final RouteProgress? progress;
  final VoidCallback onEnd;

  const NavigationBanner({
    super.key,
    required this.route,
    required this.progress,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = progress?.upcomingInstruction ??
        (route.turnInstructions.isNotEmpty ? route.turnInstructions.first : null);
    final isArrived = progress?.isArrived ?? false;
    final remaining = progress?.remainingMeters ?? route.lengthMeters;
    final distanceToNext = progress?.distanceToNext ??
        (route.turnInstructions.isNotEmpty ? route.turnInstructions.first.legMeters : 0);
    final offRoute = (progress?.distanceFromRoute ?? 0) > 30;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NaturalPalette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NaturalPalette.hairline, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isArrived ? NaturalPalette.forest : NaturalPalette.route,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isArrived ? Icons.check_circle : _iconFor(upcoming?.kind),
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isArrived) ...[
                      const Text("You've arrived",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: NaturalPalette.ink)),
                      const Text('End of the route.',
                          style: TextStyle(
                              fontSize: 12, color: NaturalPalette.inkMuted)),
                    ] else if (upcoming != null) ...[
                      Text(upcoming.kind.verb,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: NaturalPalette.ink)),
                      if (upcoming.streetName != null)
                        Text(
                          '${upcoming.kind == TurnKind.arrive ? "at" : "onto"} ${upcoming.streetName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: NaturalPalette.ink),
                        ),
                      Text('in ${_distanceText(distanceToNext)}',
                          style: const TextStyle(
                              fontSize: 12, color: NaturalPalette.inkMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(height: 1, color: NaturalPalette.hairline),
          ),
          Row(
            children: [
              Text(_distanceText(remaining),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NaturalPalette.ink)),
              const SizedBox(width: 6),
              Text('· ${_walkingTime(remaining)} remaining',
                  style: const TextStyle(
                      fontSize: 14, color: NaturalPalette.inkMuted)),
              const Spacer(),
              GestureDetector(
                onTap: onEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: NaturalPalette.route,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('End',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
          if (offRoute) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 15, color: NaturalPalette.route),
                const SizedBox(width: 6),
                Text(
                  'Off route by ${_distanceText(progress?.distanceFromRoute ?? 0)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: NaturalPalette.route),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(TurnKind? kind) {
    switch (kind) {
      case TurnKind.start:
        return Icons.directions_walk;
      case TurnKind.continueStraight:
        return Icons.arrow_upward;
      case TurnKind.slightLeft:
        return Icons.north_west;
      case TurnKind.left:
        return Icons.turn_left;
      case TurnKind.sharpLeft:
        return Icons.south_west;
      case TurnKind.slightRight:
        return Icons.north_east;
      case TurnKind.right:
        return Icons.turn_right;
      case TurnKind.sharpRight:
        return Icons.south_east;
      case TurnKind.uTurn:
        return Icons.u_turn_left;
      case TurnKind.arrive:
        return Icons.place;
      case null:
        return Icons.arrow_upward;
    }
  }

  String _walkingTime(double meters) {
    final minutes = meters / 1609.344 / 3.0 * 60.0;
    if (minutes < 1) return '<1 min';
    if (minutes < 60) return '${minutes.round()} min';
    final h = minutes ~/ 60;
    final m = minutes.round() % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  String _distanceText(double meters) {
    final miles = meters / 1609.344;
    if (miles >= 0.1) return '${miles.toStringAsFixed(2)} mi';
    return '${(meters * 3.28084).round()} ft';
  }
}

/// Brief 'Rerouted' toast shown after an off-route auto-reroute fires.
/// Mirrors iOS's showingReroutedToast overlay.
class RerouteToast extends StatelessWidget {
  const RerouteToast({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: NaturalPalette.ink.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Rerouted', style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
