import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Dart mirror of Polygons.json — park outlines, lakes, village boundaries
/// and creek lines. Visual context drawn under the trails so the map has a
/// real sense of place without depending on Google's own POI layer.
///
/// Matches iOS's `PolygonCatalog` in POI.swift, including the per-group
/// colours: the file carries its own `fill` / `stroke` hex, so neither
/// platform hardcodes these in its palette. A group with no colour draws
/// outline-only (village boundaries, which would be far too loud as a fill).
class PolygonCatalog {
  const PolygonCatalog({
    required this.version,
    required this.source,
    required this.polygons,
    required this.lines,
  });

  final int version;
  final String? source;
  final Map<String, PolygonGroup> polygons;
  final Map<String, LineGroup> lines;

  factory PolygonCatalog.fromJson(Map<String, dynamic> json) {
    return PolygonCatalog(
      version: (json['version'] as num?)?.toInt() ?? 0,
      source: json['source'] as String?,
      polygons: (json['polygons'] as Map<String, dynamic>? ?? const {}).map(
        (k, v) =>
            MapEntry(k, PolygonGroup.fromJson(v as Map<String, dynamic>)),
      ),
      lines: (json['lines'] as Map<String, dynamic>? ?? const {}).map(
        (k, v) => MapEntry(k, LineGroup.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}

class PolygonGroup {
  const PolygonGroup({
    required this.label,
    required this.fill,
    required this.items,
  });

  final String label;

  /// Fill colour "#RRGGBB", or null to draw outline-only.
  final String? fill;
  final List<PolygonShape> items;

  factory PolygonGroup.fromJson(Map<String, dynamic> json) {
    return PolygonGroup(
      label: json['label'] as String? ?? '',
      fill: json['fill'] as String?,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => PolygonShape.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class PolygonShape {
  const PolygonShape({
    required this.rings,
    required this.name,
    required this.village,
  });

  /// Outer ring first, holes follow.
  final List<List<LatLng>> rings;
  final String? name;
  final String? village;

  factory PolygonShape.fromJson(Map<String, dynamic> json) {
    return PolygonShape(
      rings: (json['rings'] as List<dynamic>? ?? const [])
          .map((r) => decodeRing(r as List<dynamic>))
          .toList(growable: false),
      name: json['name'] as String?,
      village: json['village'] as String?,
    );
  }
}

class LineGroup {
  const LineGroup({
    required this.label,
    required this.stroke,
    required this.items,
  });

  final String label;

  /// Stroke colour "#RRGGBB", or null to fall back to a neutral blue.
  final String? stroke;
  final List<List<LatLng>> items;

  factory LineGroup.fromJson(Map<String, dynamic> json) {
    return LineGroup(
      label: json['label'] as String? ?? '',
      stroke: json['stroke'] as String?,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((l) => decodeRing(l as List<dynamic>))
          .toList(growable: false),
    );
  }
}

/// The JSON ships each coordinate as `[lat, lon]` rather than an object, for
/// byte savings — the file is ~1.1 MB even so.
List<LatLng> decodeRing(List<dynamic> raw) {
  return raw.map((p) {
    final pair = p as List<dynamic>;
    return LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
  }).toList(growable: false);
}

/// Parses "#RRGGBB" (or bare "RRGGBB") into an ARGB int at the given alpha.
///
/// Returns null for an unparseable or absent value so callers can apply
/// their own fallback rather than silently drawing something wrong.
int? argbFromHex(String? hex, double alpha) {
  if (hex == null) return null;
  final s = hex.startsWith('#') ? hex.substring(1) : hex;
  if (s.length != 6) return null;
  final rgb = int.tryParse(s, radix: 16);
  if (rgb == null) return null;
  return ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | rgb;
}
