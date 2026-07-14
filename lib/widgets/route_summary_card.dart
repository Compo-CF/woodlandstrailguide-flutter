import 'package:flutter/material.dart';

import '../services/elevation_service.dart';
import '../services/router.dart';
import '../theme/natural_palette.dart';
import 'elevation_chart.dart';

/// Bottom card shown once a route is computed. Mirrors iOS
/// MapTabView's routeSummaryCard: distance, walking time estimate,
/// elevation profile, named segments ("Route" chips), parks passed
/// through, and the primary action buttons (Start walking / Clear).
class RouteSummaryCard extends StatelessWidget {
  final RouteResult route;
  final VoidCallback onStartWalking;
  final VoidCallback onClear;
  final VoidCallback? onAddWaypoint;
  final VoidCallback? onBuildLoop;
  final VoidCallback? onShare;
  final ElevationProfile? elevationProfile;

  const RouteSummaryCard({
    super.key,
    required this.route,
    required this.onStartWalking,
    required this.onClear,
    this.onAddWaypoint,
    this.onBuildLoop,
    this.onShare,
    this.elevationProfile,
  });

  /// Average walking speed ~3 mph -> minutes = miles / 3 * 60.
  int get _estimatedMinutes => (route.miles / 3.0 * 60).round();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NaturalPalette.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dragHandle(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    route.miles < 0.1
                        ? '${(route.lengthMeters * 3.28084).round()} ft'
                        : '${route.miles.toStringAsFixed(2)} mi',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: NaturalPalette.ink),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('~$_estimatedMinutes min walk',
                        style: const TextStyle(
                            color: NaturalPalette.inkMuted, fontSize: 14)),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close, color: NaturalPalette.inkMuted),
                  ),
                ],
              ),
              if (elevationProfile != null) ...[
                const SizedBox(height: 14),
                ElevationChartView(profile: elevationProfile!),
              ],
              if (route.namedSegments.isNotEmpty) ...[
                const SizedBox(height: 10),
                _chipSection('Route', route.namedSegments.map((s) => s.name).toList(),
                    Icons.route, NaturalPalette.forest),
              ],
              if (route.parks.isNotEmpty) ...[
                const SizedBox(height: 8),
                _chipSection('Parks', route.parks, Icons.park, const Color(0xFF228B45)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onStartWalking,
                      style: FilledButton.styleFrom(
                        backgroundColor: NaturalPalette.route,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Start walking',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (onShare != null) ...[
                    const SizedBox(width: 10),
                    _iconButton(Icons.share_outlined, onShare!),
                  ],
                  if (onAddWaypoint != null) ...[
                    const SizedBox(width: 10),
                    _iconButton(Icons.add_location_alt_outlined, onAddWaypoint!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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

  Widget _chipSection(String label, List<String> items, IconData icon, Color tint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: NaturalPalette.inkMuted,
                letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.take(6).map((name) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: tint),
                  const SizedBox(width: 5),
                  Text(name, style: TextStyle(fontSize: 12.5, color: tint)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: NaturalPalette.chipBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 20, color: NaturalPalette.forest),
        ),
      ),
    );
  }
}

/// Small hint card shown while the user is tapping to set start/end
/// points, before a route exists. Mirrors iOS's amber hint card.
class RoutingHintCard extends StatelessWidget {
  final int? startNode;
  final int? endNode;
  final bool addingWaypoint;
  final int waypointCount;
  final VoidCallback? onUseCurrentLocation;

  const RoutingHintCard({
    super.key,
    required this.startNode,
    required this.endNode,
    required this.addingWaypoint,
    required this.waypointCount,
    this.onUseCurrentLocation,
  });

  String get _message {
    if (addingWaypoint) return 'Tap the map to add a waypoint';
    if (startNode == null) return 'Tap a trail to set your starting point';
    if (endNode == null) return 'Tap a trail to set your destination';
    return 'Computing route…';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEFDA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8C99A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFFB07A2E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_message,
                    style: const TextStyle(
                        color: Color(0xFF6B4A1E), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (startNode == null && onUseCurrentLocation != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onUseCurrentLocation,
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('Use my location as start'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B4A1E),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          if (waypointCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$waypointCount waypoint${waypointCount == 1 ? '' : 's'} added',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A6A3D)),
            ),
          ],
        ],
      ),
    );
  }
}
