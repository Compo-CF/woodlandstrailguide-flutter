// TrailGraph — parses the compact JSON format produced by
// scripts/fetch_township_data.py in the iOS repo. Nodes are `[lat, lon]`
// pairs (index = canonical node id), ways use short keys (`n`, `len_m`).
// `adj[nodeIndex]` is a precomputed adjacency list: each entry is
// `[neighborIndex, lengthMeters, wayIndex]`, used directly by Router's
// Dijkstra so we don't have to rebuild adjacency at runtime.

class TrailGraph {
  final int version;
  final String source;
  final BBox bbox;
  final List<Coord> nodes;
  final List<Way> ways;
  final List<List<Edge>> adj;

  TrailGraph({
    required this.version,
    required this.source,
    required this.bbox,
    required this.nodes,
    required this.ways,
    required this.adj,
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
        adj: (json['adj'] as List<dynamic>)
            .map((edges) => (edges as List<dynamic>)
                .map((e) => Edge.fromArray(e as List<dynamic>))
                .toList())
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

/// One adjacency entry: `[neighborNodeIndex, lengthMeters, wayIndex]`.
class Edge {
  final int neighbor;
  final double lengthMeters;
  final int wayIndex;

  const Edge({
    required this.neighbor,
    required this.lengthMeters,
    required this.wayIndex,
  });

  factory Edge.fromArray(List<dynamic> arr) => Edge(
        neighbor: (arr[0] as num).toInt(),
        lengthMeters: (arr[1] as num).toDouble(),
        wayIndex: (arr[2] as num).toInt(),
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
