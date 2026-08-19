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

  /// Set from UserDataStore.preferPavedRoutes by MapScreen whenever it
  /// changes. recompute() reads this directly so toggling the setting
  /// immediately updates any active route.
  SurfacePreference surfacePreference = SurfacePreference.any;

  /// Set when the active route came from the route planner (a distance/
  /// time target) rather than plain tap-to-route. Null for normal
  /// routing. Read by recompute() so surface toggles and off-route
  /// reroutes keep recomputing consistently with the original plan —
  /// cleared by clearRoute() and whenever a fresh, un-planned route
  /// begins.
  RoutePlan? activePlan;

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
    final plan = activePlan;
    if (plan != null &&
        plan.shape == PlannedRouteShape.loop &&
        startNode == endNode &&
        waypointNodes.length == 1) {
      // Planner loop: build a genuine loop (different path back) via
      // the discourage-based Dijkstra, instead of the plain through-
      // route Dijkstra below (which would just retrace the same edges
      // both ways).
      route = router.loopRoute(startNode!, waypointNodes[0],
          surfacePreference: plan.surfacePreference);
    } else if (plan != null) {
      // Planner out-and-back (or a loop that's degraded -- e.g. after
      // an off-route reroute dropped the waypoint): plain through-
      // route, but honoring the plan's own surface preference rather
      // than the global prefer-paved toggle.
      final stops = [startNode!, ...waypointNodes, endNode!];
      route = router.routeThrough(stops, surfacePreference: plan.surfacePreference);
    } else {
      final stops = [startNode!, ...waypointNodes, endNode!];
      route = router.routeThrough(stops, surfacePreference: surfacePreference);
    }
    notifyListeners();
  }

  /// Updates the surface preference and immediately recomputes any
  /// active route against it — mirrors iOS's "Prefer paved paths"
  /// toggle in the map's more-options menu.
  void setSurfacePreference(SurfacePreference preference, TrailGraph graph) {
    surfacePreference = preference;
    recompute(graph);
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
    activePlan = null;
    notifyListeners();
  }

  /// Replace the whole start/end/waypoints/route in one shot — used by
  /// applyPendingRoute (Featured Walks handoff) and the route planner.
  void applyStops(List<int> stops, TrailGraph graph) {
    if (stops.length < 2) return;
    startNode = stops.first;
    endNode = stops.last;
    waypointNodes = stops.sublist(1, stops.length - 1);
    routingMode = true;
    recompute(graph);
  }

  /// Applies a route-planner result: start == end with a far waypoint in
  /// between, plus the plan itself so recompute() knows how to rebuild
  /// it (genuine loop vs out-and-back) on every future recompute.
  void applyPlan(int start, int far, RoutePlan plan, TrailGraph graph) {
    clearRoute();
    routingMode = true;
    startNode = start;
    endNode = start;
    waypointNodes = [far];
    activePlan = plan;
    recompute(graph);
  }

  /// A POI-targeted route is never a "planned" route, even if one was
  /// active -- drop it so recompute() doesn't try to rebuild a loop back
  /// to a start that no longer matches this new destination.
  void clearActivePlan() {
    activePlan = null;
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
