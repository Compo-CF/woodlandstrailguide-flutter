// TrailGraph — parses the compact JSON format produced by
// scripts/fetch_township_data.py in the iOS repo. Nodes are `[lat, lon]`
// pairs (index = canonical node id), ways use short keys (`n`, `len_m`).
// Adjacency data is present in the JSON but not parsed here — we don't
// need it for v0.1 (routing arrives in a later phase).

class TrailGraph {
  final int version;
  final String source;
  final BBox bbox;
  final List<Coord> nodes;
  final List<Way> ways;

  TrailGraph({
    required this.version,
    required this.source,
    required this.bbox,
    required this.nodes,
    required this.ways,
  });

  factory TrailGraph.fromJson(Map<String, dynamic> json) => TrailGraph(
        version: (json['version'] as num?)?.toInt() ?? 1,
        source: (json['source'] as String?) ?? 'unknown',
        bbox: BBox.fromJson(json['bbox'] as Map<String, dynamic>),
        nodes: (json['nodes'] as List<dynamic>)
            .map((n) => Coord.fromArray(n as List<dynamic>))
            .toList(),
        ways: (json['ways'] as List<dynamic>)
            .map((w) => Way.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

class BBox {
  final double south, west, north, east;
  const BBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  factory BBox.fromJson(Map<String, dynamic> j) => BBox(
        south: (j['south'] as num).toDouble(),
        west: (j['west'] as num).toDouble(),
        north: (j['north'] as num).toDouble(),
        east: (j['east'] as num).toDouble(),
      );

  double get centerLat => (south + north) / 2;
  double get centerLon => (west + east) / 2;
}

/// A graph node. Stored as `[lat, lon]` in JSON to halve byte count.
class Coord {
  final double lat;
  final double lon;
  const Coord(this.lat, this.lon);

  factory Coord.fromArray(List<dynamic> arr) => Coord(
        (arr[0] as num).toDouble(),
        (arr[1] as num).toDouble(),
      );
}

class Way {
  final List<int> nodeIndices;
  final String kind;
  final String? name;
  final double lengthMeters;
  final String? village;
  final String? park;
  final String? system;
  final String? surface;
  final String? pathwayID;
  final List<String>? parks;

  const Way({
    required this.nodeIndices,
    required this.kind,
    required this.name,
    required this.lengthMeters,
    required this.village,
    required this.park,
    required this.system,
    required this.surface,
    required this.pathwayID,
    required this.parks,
  });

  factory Way.fromJson(Map<String, dynamic> json) => Way(
        nodeIndices: (json['n'] as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList(),
        kind: (json['kind'] as String?) ?? 'pathway',
        name: json['name'] as String?,
        lengthMeters: (json['len_m'] as num?)?.toDouble() ?? 0.0,
        village: json['village'] as String?,
        park: json['park'] as String?,
        system: json['system'] as String?,
        surface: json['surface'] as String?,
        pathwayID: json['pathway_id'] as String?,
        parks: (json['parks'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );

  double get miles => lengthMeters / 1609.344;
}
