// Routing state shared across the Map screen (and later Featured Walks,
// deep links, etc.) via Provider. Mirrors the routing-related @State
// vars that live in iOS MapTabView.swift, but hoisted into its own
// ChangeNotifier so other screens (Featured tab's "Walk this route")
// can populate a pending route without needing a widget reference to
// MapScreen's State object.

import 'package:flutter/foundation.dart';

import '../models/trail_graph.dart';
import '../services/router.dart';

class RoutingState extends ChangeNotifier {
  bool routingMode = false;
  int? startNode;
  int? endNode;
  List<int> waypointNodes = [];
  RouteResult? route;

  /// True while the user has tapped "+ Waypoint" and the next map tap
  /// should append to waypointNodes instead of touching start/end.
  bool addingWaypoint = false;

  /// Set once the user taps "Start" on a computed route.
  bool navigationActive = false;
  RouteProgress? routeProgress;

  /// A route requested from outside the map screen (Featured Walks'
  /// "Walk this route" button, or a future deep link). MapScreen
  /// observes this and applies + clears it.
  PendingRoute? pending;

  void requestRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    List<List<double>> waypoints = const [],
  }) {
    pending = PendingRoute(
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
      waypoints: waypoints,
    );
    notifyListeners();
  }

  /// Sets a fully-formed PendingRoute directly — used by the deep-link
  /// handler (RoutingBridge.parse already produced one).
  void setPending(PendingRoute route) {
    pending = route;
    notifyListeners();
  }

  void clearPending() {
    pending = null;
  }

  void enterRoutingMode() {
    routingMode = true;
    notifyListeners();
  }

  void toggleWaypointMode() {
    addingWaypoint = !addingWaypoint;
    notifyListeners();
  }

  /// Recompute the route from current start/end/waypoints against the
  /// given graph. Call after any of those change.
  void recompute(TrailGraph graph) {
    if (startNode == null || endNode == null) {
      route = null;
      notifyListeners();
      return;
    }
    final router = TrailRouter(graph);
    final stops = [startNode!, ...waypointNodes, endNode!];
    route = router.routeThrough(stops);
    notifyListeners();
  }

  void setStart(int node, TrailGraph graph) {
    startNode = node;
    recompute(graph);
  }

  void setEnd(int node, TrailGraph graph) {
    endNode = node;
    recompute(graph);
  }

  void addWaypoint(int node, TrailGraph graph) {
    waypointNodes.add(node);
    recompute(graph);
  }

  void removeWaypoint(int index, TrailGraph graph) {
    if (index < 0 || index >= waypointNodes.length) return;
    waypointNodes.removeAt(index);
    recompute(graph);
  }

  void updateProgress(RouteProgress? progress) {
    routeProgress = progress;
    notifyListeners();
  }

  /// Applies an off-route auto-reroute: new start node (snapped to the
  /// user's current position), the freshly-computed route, and initial
  /// progress against it. Waypoints are dropped — the user has already
  /// moved past whatever waypoint context existed.
  void applyReroute(int newStart, RouteResult rerouted, RouteProgress progress) {
    startNode = newStart;
    waypointNodes = [];
    route = rerouted;
    routeProgress = progress;
    notifyListeners();
  }

  void startNavigation() {
    navigationActive = true;
    notifyListeners();
  }

  void endNavigation() {
    navigationActive = false;
    routeProgress = null;
    notifyListeners();
  }

  void clearRoute() {
    routingMode = false;
    startNode = null;
    endNode = null;
    waypointNodes = [];
    route = null;
    addingWaypoint = false;
    navigationActive = false;
    routeProgress = null;
    notifyListeners();
  }

  /// Replace the whole start/end/waypoints/route in one shot — used by
  /// applyPendingRoute (Featured Walks handoff) and the loop builder.
  void applyStops(List<int> stops, TrailGraph graph) {
    if (stops.length < 2) return;
    startNode = stops.first;
    endNode = stops.last;
    waypointNodes = stops.sublist(1, stops.length - 1);
    routingMode = true;
    recompute(graph);
  }
}

class PendingRoute {
  final double startLat, startLon, endLat, endLon;
  final List<List<double>> waypoints; // each [lat, lon]
  const PendingRoute({
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.waypoints,
  });
}
