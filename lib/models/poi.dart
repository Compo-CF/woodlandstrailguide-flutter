// POI catalog — parses the nested JSON format produced by
// scripts/fetch_pois.py in the iOS repo. Categories are a MAP
// (key -> category info + items), each category has a color tint
// (hex string with leading #), an SF-Symbols icon name (mapped to
// Material Icons at render time), and a list of items.

class POICatalog {
  final int version;
  final String source;
  final List<POICategory> categories;

  POICatalog({
    required this.version,
    required this.source,
    required this.categories,
  });

  factory POICatalog.fromJson(Map<String, dynamic> json) {
    final catMap = json['categories'] as Map<String, dynamic>;
    final cats = <POICategory>[];
    catMap.forEach((key, value) {
      final data = value as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const [])
          .map((p) => POI.fromJson(p as Map<String, dynamic>, key))
          .toList();
      cats.add(POICategory(
        key: key,
        label: (data['label'] as String?) ?? key,
        icon: data['icon'] as String?,
        tintHex: _parseTint(data['tint'] as String?),
        pois: items,
      ));
    });
    return POICatalog(
      version: (json['version'] as num?)?.toInt() ?? 1,
      source: (json['source'] as String?) ?? '',
      categories: cats,
    );
  }

  /// Flattened list of every POI across categories.
  List<POI> get allPOIs =>
      categories.expand((c) => c.pois).toList(growable: false);

  static int _parseTint(String? tint) {
    if (tint == null) return 0xAAAAAA;
    final hex = tint.replaceAll('#', '');
    return int.tryParse(hex, radix: 16) ?? 0xAAAAAA;
  }
}

class POICategory {
  final String key;
  final String label;
  final String? icon;
  final int tintHex;
  final List<POI> pois;

  const POICategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.tintHex,
    required this.pois,
  });
}

class POI {
  final String id;
  final String categoryKey;
  final String? name;
  final double lat;
  final double lon;
  final String? village;
  final String? park;

  const POI({
    required this.id,
    required this.categoryKey,
    required this.name,
    required this.lat,
    required this.lon,
    required this.village,
    required this.park,
  });

  factory POI.fromJson(Map<String, dynamic> json, String categoryKey) => POI(
        id: json['id']?.toString() ?? '',
        categoryKey: categoryKey,
        name: json['name'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        village: json['village'] as String?,
        park: json['park'] as String?,
      );
}
