import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/poi.dart';
import '../services/poi_photo_store.dart';
import '../theme/natural_palette.dart';

/// Detail sheet shown when the user taps a POI marker on the map.
/// Surfaces name, category, park/village, distance from the user, a
/// personal-photos section (local-only, never uploaded), and a "Route
/// here" action. Direct port of iOS POIDetailSheet.
class POIDetailSheet extends StatefulWidget {
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
      isScrollControlled: true,
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

  @override
  State<POIDetailSheet> createState() => _POIDetailSheetState();
}

class _POIDetailSheetState extends State<POIDetailSheet> {
  bool _isPicking = false;

  PhotoKey get _photoKey =>
      PhotoKey(categoryKey: widget.category.key, poiID: widget.poi.id);

  Color get _tint => Color(0xFF000000 | widget.category.tintHex);

  String? get _distanceText {
    final u = widget.userLocation;
    if (u == null) return null;
    final meters =
        Geolocator.distanceBetween(u.latitude, u.longitude, widget.poi.lat, widget.poi.lon);
    final miles = meters / 1609.344;
    if (miles >= 0.1) return '${miles.toStringAsFixed(2)} mi from you';
    return '${(meters * 3.28084).round()} ft from you';
  }

  @override
  Widget build(BuildContext context) {
    final distance = _distanceText;
    final photoStore = context.watch<POIPhotoStore>();
    final photos = photoStore.photoURLs(_photoKey);

    return SafeArea(
      child: SingleChildScrollView(
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
                      Text(widget.poi.name ?? widget.category.label,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: NaturalPalette.ink)),
                      Text(widget.category.label,
                          style: const TextStyle(
                              fontSize: 13, color: NaturalPalette.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.poi.park != null || widget.poi.village != null || distance != null) ...[
              const SizedBox(height: 18),
              if (widget.poi.park != null) _infoRow('Park', widget.poi.park!),
              if (widget.poi.village != null) _infoRow('Village', widget.poi.village!),
              if (distance != null) _infoRow('Distance', distance),
            ],
            const SizedBox(height: 20),
            const Text('YOUR PHOTOS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NaturalPalette.inkMuted,
                    letterSpacing: 0.6)),
            const SizedBox(height: 8),
            if (photos.isEmpty)
              const Text(
                'Attach a photo of this spot to remember what it looks like. '
                'Stored on your device only — not shared.',
                style: TextStyle(fontSize: 12.5, color: NaturalPalette.inkMuted),
              )
            else
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final file = photos[i];
                    return GestureDetector(
                      onTap: () => _viewPhoto(context, file),
                      onLongPress: () => _confirmDelete(context, photoStore, file),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(file, width: 88, height: 88, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            if (photos.length < POIPhotoStore.maxPhotosPerPOI) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isPicking ? null : () => _addPhoto(photoStore),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NaturalPalette.forest,
                  side: const BorderSide(color: NaturalPalette.forest),
                ),
                icon: _isPicking
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text('Add photo (${photos.length}/${POIPhotoStore.maxPhotosPerPOI})'),
              ),
            ],
            if (widget.onRouteHere != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onRouteHere!();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: NaturalPalette.forest,
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

  Future<void> _addPhoto(POIPhotoStore photoStore) async {
    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked != null) {
        photoStore.addPhoto(picked.path, _photoKey);
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _viewPhoto(BuildContext context, File file) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.file(file)),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, POIPhotoStore photoStore, File file) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              photoStore.deletePhoto(file);
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: NaturalPalette.route)),
          ),
        ],
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
