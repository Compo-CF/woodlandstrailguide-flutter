// Client-side shortest-path routing over the TrailGraph. Direct port of
// iOS Router.swift — same binary-heap Dijkstra, same turn-instruction
// classification, same live-progress projection math. Kept as close to
// a line-for-line translation as Dart idiom allows so future iOS
// changes are easy to port across.
//
// The Woodlands pathway network has ~1,500 segments and ~44K nodes —
// tiny for a binary-heap Dijkstra. A query from any node to any other
// returns in single-digit milliseconds.

import 'dart:math' as math;

import '../models/trail_graph.dart';

enum TurnKind {
  start,
  continueStraight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  arrive;

  /// Material icon name — mapped in the nav banner widget.
  String get iconName {
    switch (this) {
      case TurnKind.start: return 'directions_walk';
      case TurnKind.continueStraight: return 'arrow_upward';
      case TurnKind.slightLeft: return 'north_west';
      case TurnKind.left: return 'turn_left';
      case TurnKind.sharpLeft: return 'south_west';
      case TurnKind.slightRight: return 'north_east';
      case TurnKind.right: return 'turn_right';
      case TurnKind.sharpRight: return 'south_east';
      case TurnKind.uTurn: return 'u_turn_left';
      case TurnKind.arrive: return 'place';
    }
  }

  String get verb {
    switch (this) {
      case TurnKind.start: return 'Head out';
      case TurnKind.continueStraight: return 'Continue';
      case TurnKind.slightLeft: return 'Bear left';
      case TurnKind.left: return 'Turn left';
      case TurnKind.sharpLeft: return 'Sharp left';
      case TurnKind.slightRight: return 'Bear right';
      case TurnKind.right: return 'Turn right';
      case TurnKind.sharpRight: return 'Sharp right';
      case TurnKind.uTurn: return 'Make a U-turn';
      case TurnKind.arrive: return 'Arrive';
    }
  }
}

class TurnInstruction {
  final TurnKind kind;
  final String? streetName;
  final double legMeters;
  final double cumulativeMeters;
  final int nodeIndex;

  const TurnInstruction({
    required this.kind,
    required this.streetName,
    required this.legMeters,
    required this.cumulativeMeters,
    required this.nodeIndex,
  });
}

class RouteResult {
  final List<int> nodes;
  final double lengthMeters;
  final List<NamedSegment> namedSegments;
  final List<String> parks;
  final List<TurnInstruction> turnInstructions;

  const RouteResult({
    required this.nodes,
    required this.lengthMeters,
    required this.namedSegments,
    required this.parks,
    required this.turnInstructions,
  });

  double get miles => lengthMeters / 1609.344;
}

class NamedSegment {
  final String name;
  final double lengthMeters;
  const NamedSegment(this.name, this.lengthMeters);
}

/// Live state of the user's walk against a given route.
class RouteProgress {
  final double distanceAlongRoute;
  final double distanceFromRoute;
  final double remainingMeters;
  final int currentInstructionIndex;
  final TurnInstruction? upcomingInstruction;
  final double distanceToNext;
  final bool isArrived;

  const RouteProgress({
    required this.distanceAlongRoute,
    required this.distanceFromRoute,
    required this.remainingMeters,
    required this.currentInstructionIndex,
    required this.upcomingInstruction,
    required this.distanceToNext,
    required this.isArrived,
  });
}

class TrailRouter {
  final TrailGraph graph;
  const TrailRouter(this.graph);

  /// Find a graph node approximately [targetMeters] away from [start] by
  /// route distance. Used for loop generation: route(through: [start,
  /// farNode, start]) yields a walk of roughly 2x targetMeters.
  int? farthestNode(int start, double target) {
    final n = graph.nodes.length;
    if (start < 0 || start >= n || target <= 0) return null;

    final dist = List<double>.filled(n, double.infinity);
    dist[start] = 0;
    final heap = _MinHeap();
    heap.push(_HeapEntry(start, 0));

    while (heap.isNotEmpty) {
      final cur = heap.pop()!;
      if (cur.dist > dist[cur.node]) continue;
      if (cur.dist > target * 1.5) continue;
      for (final edge in graph.adj[cur.node]) {
        final nd = cur.dist + edge.lengthMeters;
        if (nd < dist[edge.neighbor]) {
          dist[edge.neighbor] = nd;
          heap.push(_HeapEntry(edge.neighbor, nd));
        }
      }
    }

    var bestIdx = -1;
    var bestDelta = double.infinity;
    for (var i = 0; i < n; i++) {
      if (!dist[i].isFinite || i == start) continue;
      final delta = (dist[i] - target).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIdx = i;
      }
    }
    return bestIdx >= 0 ? bestIdx : null;
  }

  /// Nearest node to an arbitrary point. Linear scan — fine at this graph
  /// size (~44K nodes, sub-millisecond).
  int? nearestNode(double lat, double lon) {
    if (graph.nodes.isEmpty) return null;
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < graph.nodes.length; i++) {
      final n = graph.nodes[i];
      final dLat = n.lat - lat;
      final dLon = n.lon - lon;
      final d = dLat * dLat + dLon * dLon;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Dijkstra from [start] to [end]. Returns null if no path exists.
  RouteResult? route(int start, int end) => routeThrough([start, end]);

  /// Route through an ordered sequence of stops. Each adjacent pair is
  /// computed with an independent Dijkstra run and stitched together.
  RouteResult? routeThrough(List<int> stops) {
    if (stops.length < 2) {
      if (stops.length == 1) {
        return RouteResult(
          nodes: [stops[0]],
          lengthMeters: 0,
          namedSegments: const [],
          parks: const [],
          turnInstructions: const [],
        );
      }
      return null;
    }

    var combinedPath = <int>[];
    var combinedEdgeWays = <int>[];
    var totalMeters = 0.0;

    for (var i = 0; i < stops.length - 1; i++) {
      final segment = _pathFrom(stops[i], stops[i + 1]);
      if (segment == null) return null;
      if (combinedPath.isEmpty) {
        combinedPath = segment.path;
      } else if (combinedPath.last == segment.path.first) {
        combinedPath.addAll(segment.path.skip(1));
      } else {
        combinedPath.addAll(segment.path);
      }
      combinedEdgeWays.addAll(segment.edgeWays);
      totalMeters += segment.lengthMeters;
    }

    return RouteResult(
      nodes: combinedPath,
      lengthMeters: totalMeters,
      namedSegments: _collapseSegments(combinedEdgeWays, combinedPath),
      parks: _uniqueParks(combinedEdgeWays),
      turnInstructions: _buildTurnInstructions(combinedEdgeWays, combinedPath),
    );
  }

  _PathResult? _pathFrom(int start, int end) {
    final n = graph.nodes.length;
    if (start < 0 || start >= n || end < 0 || end >= n) return null;
    if (start == end) {
      return _PathResult(path: [start], edgeWays: const [], lengthMeters: 0);
    }

    final dist = List<double>.filled(n, double.infinity);
    final prev = List<int>.filled(n, -1);
    final prevEdgeWay = List<int>.filled(n, -1);
    dist[start] = 0;

    final heap = _MinHeap();
    heap.push(_HeapEntry(start, 0));

    while (heap.isNotEmpty) {
      final cur = heap.pop()!;
      if (cur.dist > dist[cur.node]) continue;
      if (cur.node == end) break;
      for (final edge in graph.adj[cur.node]) {
        final nd = cur.dist + edge.lengthMeters;
        if (nd < dist[edge.neighbor]) {
          dist[edge.neighbor] = nd;
          prev[edge.neighbor] = cur.node;
          prevEdgeWay[edge.neighbor] = edge.wayIndex;
          heap.push(_HeapEntry(edge.neighbor, nd));
        }
      }
    }

    if (!dist[end].isFinite) return null;

    final path = <int>[];
    final edgeWays = <int>[];
    var cur = end;
    while (cur != -1) {
      path.add(cur);
      if (prevEdgeWay[cur] != -1) edgeWays.add(prevEdgeWay[cur]);
      cur = prev[cur];
    }
    final reversedPath = path.reversed.toList();
    final reversedEdgeWays = edgeWays.reversed.toList();
    return _PathResult(
      path: reversedPath,
      edgeWays: reversedEdgeWays,
      lengthMeters: dist[end],
    );
  }

  List<TurnInstruction> _buildTurnInstructions(
      List<int> edgeWays, List<int> path) {
    if (edgeWays.isEmpty || path.length < 2) {
      if (path.isNotEmpty) {
        return [
          TurnInstruction(
            kind: TurnKind.arrive,
            streetName: null,
            legMeters: 0,
            cumulativeMeters: 0,
            nodeIndex: path.last,
          )
        ];
      }
      return const [];
    }

    final edges = <_EdgeInfo>[];
    for (var i = 0; i < edgeWays.length; i++) {
      final wayIdx = edgeWays[i];
      final way = graph.ways[wayIdx];
      final label = way.name ?? (way.park ?? 'unnamed pathway');
      final len = graph.adj[path[i]]
          .firstWhere((e) => e.neighbor == path[i + 1],
              orElse: () => const Edge(neighbor: -1, lengthMeters: 0, wayIndex: -1))
          .lengthMeters;
      final b = _bearing(graph.nodes[path[i]], graph.nodes[path[i + 1]]);
      edges.add(_EdgeInfo(len, label, b));
    }

    final out = <TurnInstruction>[];
    var cursor = 0;
    var cumulative = 0.0;
    while (cursor < edges.length) {
      var end = cursor;
      while (end + 1 < edges.length && edges[end + 1].name == edges[cursor].name) {
        end++;
      }
      var legLen = 0.0;
      for (var i = cursor; i <= end; i++) {
        legLen += edges[i].len;
      }
      final TurnKind kind;
      if (cursor == 0) {
        kind = TurnKind.start;
      } else {
        kind = _classifyTurn(edges[cursor - 1].bearing, edges[cursor].bearing);
      }
      out.add(TurnInstruction(
        kind: kind,
        streetName: edges[cursor].name,
        legMeters: legLen,
        cumulativeMeters: cumulative,
        nodeIndex: path[cursor],
      ));
      cumulative += legLen;
      cursor = end + 1;
    }
    out.add(TurnInstruction(
      kind: TurnKind.arrive,
      streetName: null,
      legMeters: 0,
      cumulativeMeters: cumulative,
      nodeIndex: path.last,
    ));
    return out;
  }

  static double _bearing(Coord a, Coord b) {
    final lat1 = a.lat * math.pi / 180;
    final lat2 = b.lat * math.pi / 180;
    final dLon = (b.lon - a.lon) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  static TurnKind _classifyTurn(double bearingIn, double bearingOut) {
    var delta = bearingOut - bearingIn;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    final magnitude = delta.abs();
    if (magnitude < 25) return TurnKind.continueStraight;
    if (magnitude > 160) return TurnKind.uTurn;
    if (delta < 0) {
      if (magnitude < 50) return TurnKind.slightLeft;
      if (magnitude < 130) return TurnKind.left;
      return TurnKind.sharpLeft;
    } else {
      if (magnitude < 50) return TurnKind.slightRight;
      if (magnitude < 130) return TurnKind.right;
      return TurnKind.sharpRight;
    }
  }

  /// Where the user is along a given route. Projects userLocation onto
  /// the route polyline segment-by-segment and keeps the closest hit.
  RouteProgress progress(RouteResult route, double userLat, double userLon) {
    if (route.nodes.length < 2) {
      return RouteProgress(
        distanceAlongRoute: 0,
        distanceFromRoute: 0,
        remainingMeters: 0,
        currentInstructionIndex: 0,
        upcomingInstruction:
            route.turnInstructions.isNotEmpty ? route.turnInstructions.first : null,
        distanceToNext: 0,
        isArrived: true,
      );
    }

    final cum = <double>[0];
    for (var i = 1; i < route.nodes.length; i++) {
      final a = graph.nodes[route.nodes[i - 1]];
      final b = graph.nodes[route.nodes[i]];
      cum.add(cum[i - 1] + _haversineMeters(a.lat, a.lon, b.lat, b.lon));
    }

    var bestIdx = 0;
    var bestT = 0.0;
    var bestPerp = double.infinity;
    for (var i = 0; i < route.nodes.length - 1; i++) {
      final a = graph.nodes[route.nodes[i]];
      final b = graph.nodes[route.nodes[i + 1]];
      final proj = _projectionDistance(userLat, userLon, a.lat, a.lon, b.lat, b.lon);
      if (proj.perp < bestPerp) {
        bestIdx = i;
        bestT = proj.t;
        bestPerp = proj.perp;
      }
    }

    final segLen = cum[bestIdx + 1] - cum[bestIdx];
    final alongRoute = cum[bestIdx] + bestT * segLen;
    final remaining = math.max(0.0, route.lengthMeters - alongRoute);
    final isArrived = remaining < 15;

    var currentIdx = 0;
    for (var i = 0; i < route.turnInstructions.length; i++) {
      if (route.turnInstructions[i].cumulativeMeters <= alongRoute) {
        currentIdx = i;
      } else {
        break;
      }
    }

    TurnInstruction? upcoming;
    double distanceToNext;
    if (currentIdx + 1 < route.turnInstructions.length) {
      final next = route.turnInstructions[currentIdx + 1];
      upcoming = next;
      distanceToNext = math.max(0.0, next.cumulativeMeters - alongRoute);
    } else {
      upcoming =
          route.turnInstructions.isNotEmpty ? route.turnInstructions.last : null;
      distanceToNext = 0;
    }

    return RouteProgress(
      distanceAlongRoute: alongRoute,
      distanceFromRoute: bestPerp,
      remainingMeters: remaining,
      currentInstructionIndex: currentIdx,
      upcomingInstruction: upcoming,
      distanceToNext: distanceToNext,
      isArrived: isArrived,
    );
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Equirectangular projection of point P onto segment A->B at the
  /// midpoint latitude. Returns (perpendicular distance m, t in [0,1]).
  static _Projection _projectionDistance(
    double lat, double lon,
    double aLat, double aLon,
    double bLat, double bLon,
  ) {
    final midLat = (aLat + bLat) / 2;
    final mPerLon = 111319.0 * math.cos(midLat * math.pi / 180);
    const mPerLat = 111319.0;
    final ax = aLon * mPerLon, ay = aLat * mPerLat;
    final bx = bLon * mPerLon, by = bLat * mPerLat;
    final px = lon * mPerLon, py = lat * mPerLat;
    final dx = bx - ax, dy = by - ay;
    final seg2 = dx * dx + dy * dy;
    if (seg2 < 1e-6) {
      final d = math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
      return _Projection(d, 0);
    }
    var t = ((px - ax) * dx + (py - ay) * dy) / seg2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final d = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
    return _Projection(d, t);
  }

  List<String> _uniqueParks(List<int> edgeWays) {
    final seen = <String>{};
    final out = <String>[];
    for (final wi in edgeWays) {
      final parks = graph.ways[wi].parks;
      if (parks == null) continue;
      for (final p in parks) {
        if (seen.add(p)) out.add(p);
      }
    }
    return out;
  }

  List<NamedSegment> _collapseSegments(List<int> edgeWays, List<int> path) {
    final out = <NamedSegment>[];
    String? currentName;
    var currentLen = 0.0;
    for (var i = 0; i < edgeWays.length; i++) {
      final way = graph.ways[edgeWays[i]];
      final label = way.name ?? (way.park ?? 'unnamed pathway');
      final edgeLen = graph.adj[path[i]]
          .firstWhere((e) => e.neighbor == path[i + 1],
              orElse: () => const Edge(neighbor: -1, lengthMeters: 0, wayIndex: -1))
          .lengthMeters;
      if (label != currentName) {
        if (currentName != null && currentLen > 0) {
          out.add(NamedSegment(currentName, currentLen));
        }
        currentName = label;
        currentLen = edgeLen;
      } else {
        currentLen += edgeLen;
      }
    }
    if (currentName != null && currentLen > 0) {
      out.add(NamedSegment(currentName, currentLen));
    }
    return out;
  }
}

class _PathResult {
  final List<int> path;
  final List<int> edgeWays;
  final double lengthMeters;
  const _PathResult({required this.path, required this.edgeWays, required this.lengthMeters});
}

class _EdgeInfo {
  final double len;
  final String name;
  final double bearing;
  const _EdgeInfo(this.len, this.name, this.bearing);
}

class _Projection {
  final double perp;
  final double t;
  const _Projection(this.perp, this.t);
}

// MARK: - MinHeap
//
// Hand-rolled binary heap (array-backed, sift up/down) — direct port of
// the Swift MinHeap. Dart's collection package has HeapPriorityQueue,
// but keeping this self-contained avoids an extra dependency for
// something this small.

class _HeapEntry {
  final int node;
  final double dist;
  const _HeapEntry(this.node, this.dist);
}

class _MinHeap {
  final List<_HeapEntry> _storage = [];

  bool get isNotEmpty => _storage.isNotEmpty;

  void push(_HeapEntry value) {
    _storage.add(value);
    _siftUp(_storage.length - 1);
  }

  _HeapEntry? pop() {
    if (_storage.isEmpty) return null;
    final last = _storage.length - 1;
    final tmp = _storage[0];
    _storage[0] = _storage[last];
    _storage[last] = tmp;
    final value = _storage.removeLast();
    if (_storage.isNotEmpty) _siftDown(0);
    return value;
  }

  void _siftUp(int i0) {
    var i = i0;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_storage[i].dist < _storage[parent].dist) {
        final tmp = _storage[i];
        _storage[i] = _storage[parent];
        _storage[parent] = tmp;
        i = parent;
      } else {
        break;
      }
    }
  }

  void _siftDown(int i0) {
    var i = i0;
    final count = _storage.length;
    while (true) {
      final l = 2 * i + 1;
      final r = 2 * i + 2;
      var smallest = i;
      if (l < count && _storage[l].dist < _storage[smallest].dist) smallest = l;
      if (r < count && _storage[r].dist < _storage[smallest].dist) smallest = r;
      if (smallest == i) break;
      final tmp = _storage[i];
      _storage[i] = _storage[smallest];
      _storage[smallest] = tmp;
      i = smallest;
    }
  }
}
