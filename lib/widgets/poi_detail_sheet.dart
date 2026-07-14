import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/poi.dart';
import '../theme/natural_palette.dart';

/// Detail sheet shown when the user taps a POI marker on the map.
/// Surfaces name, category, park/village, and distance from the user.
/// Photos-on-POI land in a later batch (parity task #46); this covers
/// the core "what is this pin" information iOS shows today.
class POIDetailSheet extends StatelessWidget {
  final POI poi;
  final POICategory category;
  final Position? userLocation;
  final VoidCallback? onRouteHere;

  const POIDetailSheet({
    super.key,
    required this.poi,
    required this.category,
    required this.userLocation,
    this.onRouteHere,
  });

  static Future<void> show(
    BuildContext context, {
    required POI poi,
    required POICategory category,
    required Position? userLocation,
    VoidCallback? onRouteHere,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => POIDetailSheet(
        poi: poi,
        category: category,
        userLocation: userLocation,
        onRouteHere: onRouteHere,
      ),
    );
  }

  Color get _tint => Color(0xFF000000 | category.tintHex);

  String? get _distanceText {
    final u = userLocation;
    if (u == null) return null;
    final meters = Geolocator.distanceBetween(u.latitude, u.longitude, poi.lat, poi.lon);
    final miles = meters / 1609.344;
    if (miles >= 0.1) return '${miles.toStringAsFixed(2)} mi from you';
    return '${(meters * 3.28084).round()} ft from you';
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceText;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dragHandle(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: _tint, shape: BoxShape.circle),
                  child: const Icon(Icons.place, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poi.name ?? category.label,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: NaturalPalette.ink)),
                      Text(category.label,
                          style: const TextStyle(
                              fontSize: 13, color: NaturalPalette.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            if (poi.park != null || poi.village != null || distance != null) ...[
              const SizedBox(height: 18),
              if (poi.park != null) _infoRow('Park', poi.park!),
              if (poi.village != null) _infoRow('Village', poi.village!),
              if (distance != null) _infoRow('Distance', distance),
            ],
            if (onRouteHere != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRouteHere!();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NaturalPalette.forest,
                    side: const BorderSide(color: NaturalPalette.forest),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Route here'),
                ),
              ),
            ],
          ],
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

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: NaturalPalette.inkMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: NaturalPalette.ink)),
            ),
          ],
        ),
      );
}
