import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/travel_mode.dart';
import '../theme/natural_palette.dart';
import '../theme/natural_type.dart';

/// A shareable image summarizing a completed walk — the route traced out,
/// the distance, and where it was. Android half of iOS's
/// `WalkSummaryCard.swift` / `WalkSummarySheet.swift`.
///
/// This exists for reach, not for the person who just finished the walk: the
/// app's whole audience is one suburb, so the cheapest distribution we have
/// is an existing user posting a good-looking card to a local feed. That's
/// also why the card is deliberately branded and names the town.
///
/// Every colour in the card is hardcoded rather than pulled from
/// [NaturalPalette]. A shared PNG must look the same regardless of the
/// sharer's device appearance, and it leaves the app the moment it's shared.
class WalkSummary {
  const WalkSummary({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
    required this.segmentNames,
    required this.parks,
    required this.coordinates,
    required this.date,
  });

  final double distanceMeters;
  final double? durationSeconds;
  final TravelMode travelMode;

  /// Named trail/pathway runs along the route.
  final List<String> segmentNames;
  final List<String> parks;

  /// Route geometry, used to draw the trace. Plain lat/lon pairs rather than
  /// a maps type — nothing here touches Google Maps.
  final List<({double lat, double lon})> coordinates;
  final DateTime date;

  double get miles => distanceMeters / 1609.344;

  String get distanceText => miles.toStringAsFixed(2);

  String? get durationText {
    final s = durationSeconds;
    if (s == null || s <= 0) return null;
    final total = s.round();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes < 1 ? 1 : minutes} min';
  }

  /// Best single label for where this walk happened: a park if the route
  /// touched one (far more recognizable locally), otherwise the first named
  /// pathway run.
  String? get placeText => parks.isNotEmpty
      ? parks.first
      : (segmentNames.isNotEmpty ? segmentNames.first : null);
}

class WalkSummaryCard extends StatelessWidget {
  const WalkSummaryCard({super.key, required this.summary});

  final WalkSummary summary;

  /// Fixed 4:5 — the aspect most social feeds and stories crop kindly.
  static const Size size = Size(1080, 1350);

  static const Color _bg = Color(0xFF123320);
  static const Color _bgAccent = Color(0xFF1A4729);
  static const Color _cream = Color(0xFFF7F5E8);
  static const Color _trace = Color(0xFFFA9E3D);

  static final Color _creamDim = _cream.withValues(alpha: 0.62);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgAccent, _bg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const Spacer(),
              // The route itself — the only part of this card unique to the
              // walk, so it gets the most space.
              SizedBox(
                height: 520,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TracePainter(summary.coordinates, _trace),
                ),
              ),
              const Spacer(),
              _stats(),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Icon(Icons.hiking, size: 40, color: _creamDim),
        const SizedBox(width: 16),
        Text(
          'THE WOODLANDS TRAIL GUIDE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: _creamDim,
          ),
        ),
      ],
    );
  }

  Widget _stats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              summary.distanceText,
              style: NaturalType.display(150,
                  weight: FontWeight.w700, color: _cream),
            ),
            const SizedBox(width: 18),
            Text(
              'miles',
              style: TextStyle(
                  fontSize: 54, fontWeight: FontWeight.w600, color: _creamDim),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _label(
                summary.travelMode.label, _iconFor(summary.travelMode.iconName)),
            if (summary.durationText != null) ...[
              const SizedBox(width: 28),
              _label(summary.durationText!, Icons.schedule),
            ],
          ],
        ),
      ],
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: _creamDim),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
              fontSize: 40, fontWeight: FontWeight.w600, color: _creamDim),
        ),
      ],
    );
  }

  Widget _footer() {
    final place = summary.placeText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Container(height: 2, color: _creamDim.withValues(alpha: 0.35)),
        ),
        if (place != null)
          Text(
            place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NaturalType.display(40, color: _cream),
          ),
        const SizedBox(height: 6),
        Text(
          'The Woodlands, TX · ${DateFormat.yMMMd().format(summary.date)}',
          style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w500, color: _creamDim),
        ),
      ],
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'directions_run':
        return Icons.directions_run;
      case 'directions_bike':
        return Icons.directions_bike;
      default:
        return Icons.directions_walk;
    }
  }
}

/// Draws the route into the given rect, preserving its real shape.
class _TracePainter extends CustomPainter {
  _TracePainter(this.coordinates, this.color);

  final List<({double lat, double lon})> coordinates;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = projectedPoints(coordinates, size);
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  /// Map coordinates into the drawing rect, preserving the route's real
  /// shape. Longitude degrees get narrower as latitude increases, so they
  /// are scaled by cos(latitude) first — without that correction a
  /// north-south route renders noticeably stretched.
  static List<Offset> projectedPoints(
      List<({double lat, double lon})> coords, Size size) {
    if (coords.length < 2 || size.width <= 0 || size.height <= 0) {
      return const [];
    }

    final midLat =
        coords.map((c) => c.lat).reduce((a, b) => a + b) / coords.length;
    final lonScale = math.cos(midLat * math.pi / 180);

    final xs = coords.map((c) => c.lon * lonScale).toList(growable: false);
    final ys = coords.map((c) => c.lat).toList(growable: false);

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    // A route that doubles back on itself can be ~zero-width in one axis;
    // fall back to a nonzero span so the divide stays finite.
    final spanX = (maxX - minX) > 0 ? (maxX - minX) : 1.0;
    final spanY = (maxY - minY) > 0 ? (maxY - minY) : 1.0;

    const inset = 12.0;
    final drawW = math.max(size.width - inset * 2, 1.0);
    final drawH = math.max(size.height - inset * 2, 1.0);
    // One scale for both axes keeps the shape true rather than stretching it
    // to fill the box.
    final scale = math.min(drawW / spanX, drawH / spanY);

    final offsetX = inset + (drawW - spanX * scale) / 2;
    final offsetY = inset + (drawH - spanY * scale) / 2;

    return List<Offset>.generate(coords.length, (i) {
      return Offset(
        offsetX + (xs[i] - minX) * scale,
        // Flip: latitude grows north, screen y grows down.
        offsetY + (maxY - ys[i]) * scale,
      );
    });
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.coordinates != coordinates || old.color != color;
}

/// Shown once a walk is completed: a preview of the shareable card plus the
/// share action.
///
/// Appears automatically on arrival, so it has to stay dismissible without
/// doing anything — somebody who just finished a 5-mile walk in August heat
/// should not have to fight a modal. Hence a plain "Done" and no gating.
class WalkSummarySheet extends StatefulWidget {
  const WalkSummarySheet({super.key, required this.summary});

  final WalkSummary summary;

  static Future<void> show(BuildContext context, WalkSummary summary) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NaturalMetrics.radiusLarge),
        ),
      ),
      builder: (_) => WalkSummarySheet(summary: summary),
    );
  }

  @override
  State<WalkSummarySheet> createState() => _WalkSummarySheetState();
}

class _WalkSummarySheetState extends State<WalkSummarySheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  /// Fit the full-size card into roughly a phone's width.
  static const double _previewScale = 0.28;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Nice walk',
                    style: NaturalType.title(color: NaturalPalette.ink)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scaled-down preview of exactly what gets shared. The card is
            // laid out at its full 1080x1350 inside the RepaintBoundary and
            // only the *presentation* is scaled down, so the captured PNG is
            // full resolution rather than an upscaled thumbnail.
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: WalkSummaryCard.size.width * _previewScale,
                height: WalkSummaryCard.size.height * _previewScale,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: WalkSummaryCard(summary: widget.summary),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                label: Text(_sharing ? 'Preparing…' : 'Share this walk'),
                style: FilledButton.styleFrom(
                  backgroundColor: NaturalPalette.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(NaturalMetrics.radiusMedium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final file = await _renderPNG();
      if (!mounted) return;
      if (file == null) {
        // Rendering failed — say so rather than failing silently. The walk
        // itself is already logged either way.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't build the share image.")),
        );
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${widget.summary.distanceText} mi in The Woodlands',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Render to a PNG on disk and hand back the file.
  ///
  /// Shares a file rather than raw bytes because every share destination
  /// (Messages, Photos, Instagram) handles a real file consistently.
  Future<File?> _renderPNG() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // pixelRatio 1: the card is already laid out at its final pixel size,
      // so capturing at the device ratio would render it at 3x (~10 MB).
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/woodlands-walk-'
        '${widget.summary.date.millisecondsSinceEpoch ~/ 1000}.png',
      );
      await file.writeAsBytes(
          Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes));
      return file;
    } catch (_) {
      return null;
    }
  }
}
