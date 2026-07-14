import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/poi.dart';
import '../models/trail_graph.dart';
import '../services/router.dart';
import '../state/routing_state.dart';
import '../stores/poi_store.dart';
import '../stores/trail_store.dart';
import '../theme/natural_palette.dart';
import '../widgets/loop_builder_sheet.dart';
import '../widgets/navigation_banner.dart';
import '../widgets/poi_detail_sheet.dart';
import '../widgets/route_summary_card.dart';
import '../widgets/search_sheet.dart';
import '../widgets/trail_detail_sheet.dart';

/// Map tab. Renders every Way as a Google Maps polyline, plus POI
/// markers filtered by zoom level, plus (when routing) the computed
/// route highlighted on top with start/end/waypoint pins.
///
///   zoom < 13   → parking, playgrounds, restrooms
///   zoom 13-15  → + pavilions, water fountains, sports fields, picnic areas
///   zoom ≥ 15   → + bridges, art benches, trolley stops
class MapScreen extends StatefulWidget {
  /// Bumped by ContentView's Route tab shortcut. Entering routing mode
  /// on change is handled in didUpdateWidget.
  final int routeIntent;
  const MapScreen({super.key, this.routeIntent = 0});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;
  bool _hasLocationPermission = false;

  int _zoomBand = 0;
  static const _cityZoomThreshold = 13.0;
  static const _streetZoomThreshold = 15.0;

  /// Off-route auto-reroute: if the user drifts more than this many
  /// meters from the route for longer than the sustained duration, we
  /// silently recompute from their current position to the same
  /// destination. Mirrors iOS's offRouteThreshold/offRouteDuration.
  static const _offRouteThreshold = 100.0;
  static const _offRouteDuration = Duration(seconds: 8);
  DateTime? _offRouteSince;
  bool _showingRerouteToast = false;
  StreamSubscription<Position>? _positionSub;

  /// Best-effort last-known position, used only to show "X mi from you"
  /// in the POI detail sheet. Not authoritative for navigation math —
  /// that always reads a fresh Geolocator fix.
  Position? _lastKnownPosition;

  static const _tierAlways = <String>{
    'parking_park',
    'parking_lots',
    'playgrounds',
    'restrooms',
  };
  static const _tierMid = <String>{
    'pavilions',
    'water_fountains',
    'sports_fields',
    'picnic_areas',
  };
  static const _tierDetail = <String>{
    'bridges',
    'art_benches',
    'trolley_stops',
  };

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeIntent != oldWidget.routeIntent) {
      final routing = context.read<RoutingState>();
      if (!routing.routingMode) routing.enterRoutingMode();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _initLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trailStore = context.watch<TrailStore>();
    final poiStore = context.watch<POIStore>();
    final routing = context.watch<RoutingState>();
    final graph = trailStore.graph;

    return Scaffold(
      body: graph == null
          ? _loadingOrError(trailStore)
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(graph.bbox.centerLat, graph.bbox.centerLon),
                    zoom: 12,
                  ),
                  mapType: _mapType,
                  polylines: _buildPolylines(graph, routing),
                  markers: _buildMarkers(poiStore.categories, graph, routing),
                  onMapCreated: (c) => _controller = c,
                  onCameraIdle: _onCameraIdle,
                  onTap: (pos) => _onMapTap(pos, graph, routing),
                  myLocationEnabled: _hasLocationPermission,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                ),
                Positioned(
                  top: 48,
                  right: 12,
                  child: Column(
                    children: [
                      _floatingButton(
                        icon: routing.routingMode
                            ? Icons.close
                            : Icons.directions_walk,
                        selected: routing.routingMode,
                        onTap: () => _toggleRouting(routing),
                      ),
                      const SizedBox(height: 10),
                      _floatingButton(
                        icon: switch (_mapType) {
                          MapType.normal => Icons.map_outlined,
                          MapType.hybrid => Icons.satellite_alt,
                          _ => Icons.public,
                        },
                        onTap: _cycleMapType,
                      ),
                      const SizedBox(height: 10),
                      _floatingButton(
                        icon: Icons.my_location,
                        onTap: _centerOnUser,
                      ),
                      const SizedBox(height: 10),
                      _floatingButton(
                        icon: Icons.search,
                        onTap: () => _openSearch(graph, poiStore, routing),
                      ),
                      if (routing.routingMode) ...[
                        const SizedBox(height: 10),
                        _floatingButton(
                          icon: Icons.all_inclusive,
                          onTap: () => _openLoopBuilder(graph, routing),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!routing.routingMode)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: _zoomHintPill(),
                  ),
                if (routing.routingMode &&
                    (routing.route == null || routing.addingWaypoint))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: RoutingHintCard(
                      startNode: routing.startNode,
                      endNode: routing.endNode,
                      addingWaypoint: routing.addingWaypoint,
                      waypointCount: routing.waypointNodes.length,
                      onUseCurrentLocation: routing.startNode == null
                          ? () => _useCurrentLocationAsStart(graph, routing)
                          : null,
                    ),
                  ),
                if (routing.route != null &&
                    !routing.navigationActive &&
                    !routing.addingWaypoint)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: RouteSummaryCard(
                      route: routing.route!,
                      onStartWalking: () => _startNavigation(routing),
                      onClear: () => routing.clearRoute(),
                      onAddWaypoint: () => routing.toggleWaypointMode(),
                    ),
                  ),
                if (routing.navigationActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: NavigationBanner(
                      route: routing.route!,
                      progress: routing.routeProgress,
                      onEnd: () => _endNavigation(routing),
                    ),
                  ),
                if (_showingRerouteToast)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(child: const RerouteToast()),
                  ),
              ],
            ),
    );
  }

  Widget _loadingOrError(TrailStore store) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: NaturalPalette.forest),
            const SizedBox(height: 16),
            Text(
              store.loadError ?? 'Loading trail data…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: NaturalPalette.ink),
            ),
          ],
        ),
      ),
    );
  }

  /// Enter live navigation: mark RoutingState active, keep the screen
  /// on for the duration (mirrors iOS's isIdleTimerDisabled toggle),
  /// and start a GPS stream that drives route progress + off-route
  /// detection + camera follow.
  Future<void> _startNavigation(RoutingState routing) async {
    routing.startNavigation();
    unawaited(WakelockPlus.enable());
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen(_onPositionUpdate);
  }

  Future<void> _endNavigation(RoutingState routing) async {
    await _positionSub?.cancel();
    _positionSub = null;
    unawaited(WakelockPlus.disable());
    _offRouteSince = null;
    routing.endNavigation();
  }

  void _onPositionUpdate(Position pos) {
    if (!mounted) return;
    _lastKnownPosition = pos;
    final routing = context.read<RoutingState>();
    final graph = context.read<TrailStore>().graph;
    if (graph == null || routing.route == null || !routing.navigationActive) return;

    final router = TrailRouter(graph);
    final progress = router.progress(routing.route!, pos.latitude, pos.longitude);
    routing.updateProgress(progress);

    _controller?.animateCamera(
      CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
    );

    // Off-route auto-reroute: if the user has drifted past the threshold
    // for the sustained duration, silently recompute from their current
    // position to the same destination. Waypoints are dropped.
    if (progress.distanceFromRoute > _offRouteThreshold && !progress.isArrived) {
      _offRouteSince ??= DateTime.now();
      if (DateTime.now().difference(_offRouteSince!) > _offRouteDuration &&
          routing.endNode != null) {
        final newStart = router.nearestNode(pos.latitude, pos.longitude);
        if (newStart != null) {
          final rerouted = router.route(newStart, routing.endNode!);
          if (rerouted != null) {
            final newProgress =
                router.progress(rerouted, pos.latitude, pos.longitude);
            routing.applyReroute(newStart, rerouted, newProgress);
            _offRouteSince = null;
            setState(() => _showingRerouteToast = true);
            Future.delayed(const Duration(milliseconds: 2500), () {
              if (mounted) setState(() => _showingRerouteToast = false);
            });
          }
        }
      }
    } else {
      _offRouteSince = null;
    }
  }

  void _toggleRouting(RoutingState routing) {
    if (routing.routingMode) {
      routing.clearRoute();
    } else {
      routing.enterRoutingMode();
    }
  }

  void _onMapTap(LatLng pos, TrailGraph graph, RoutingState routing) {
    if (!routing.routingMode) return;
    final router = TrailRouter(graph);
    final node = router.nearestNode(pos.latitude, pos.longitude);
    if (node == null) return;

    if (routing.addingWaypoint) {
      routing.addWaypoint(node, graph);
      routing.toggleWaypointMode();
    } else if (routing.startNode == null) {
      routing.setStart(node, graph);
    } else if (routing.endNode == null) {
      routing.setEnd(node, graph);
    }
    // Both already set — ignore further taps until the user clears.
  }

  /// Opens the full POI detail sheet. "Route here" snaps the POI's
  /// coordinates to the nearest graph node, enters routing mode, and
  /// sets it as the start point — mirrors iOS POIDetailSheet's
  /// onRouteHere wiring.
  void _showPOIDetail(
      POI poi, POICategory category, TrailGraph graph, RoutingState routing) {
    POIDetailSheet.show(
      context,
      poi: poi,
      category: category,
      userLocation: _lastKnownPosition,
      onRouteHere: () {
        final router = TrailRouter(graph);
        final node = router.nearestNode(poi.lat, poi.lon);
        if (node == null) return;
        if (!routing.routingMode) routing.enterRoutingMode();
        routing.setStart(node, graph);
      },
    );
  }

  /// Opens the search sheet. Trail results open TrailDetailSheet
  /// directly; POI results open the full POIDetailSheet with "Route
  /// here" wired the same way as a map tap. Either way the camera also
  /// pans to the result.
  Future<void> _openSearch(
      TrailGraph graph, POIStore poiStore, RoutingState routing) async {
    Position? pos;
    if (_hasLocationPermission) {
      try {
        pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        _lastKnownPosition = pos;
      } catch (_) {}
    }
    if (!mounted) return;
    await SearchSheet.show(
      context,
      graph: graph,
      categories: poiStore.categories,
      userLocation: pos,
      onSelect: (result) async {
        await _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(result.lat, result.lon), 17),
        );
        if (!mounted) return;
        if (result.poi != null && result.category != null) {
          _showPOIDetail(result.poi!, result.category!, graph, routing);
        } else if (result.way != null) {
          TrailDetailSheet.show(context, result.way!);
        }
      },
    );
  }

  Future<void> _useCurrentLocationAsStart(
      TrailGraph graph, RoutingState routing) async {
    if (!_hasLocationPermission) {
      await _initLocation();
      if (!_hasLocationPermission) return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final router = TrailRouter(graph);
      final node = router.nearestNode(pos.latitude, pos.longitude);
      if (node != null) routing.setStart(node, graph);
    } catch (_) {}
  }

  /// Opens the loop-distance picker, then resolves the user's nearest
  /// node as the loop's start and Router.farthestNode(atRouteDistance:
  /// miles/2) as the turnaround point, mirroring iOS LoopBuilderSheet.
  Future<void> _openLoopBuilder(TrailGraph graph, RoutingState routing) async {
    if (!_hasLocationPermission) {
      await _initLocation();
      if (!_hasLocationPermission) return;
    }
    if (!mounted) return;
    await LoopBuilderSheet.show(context, onGenerate: (miles) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        final router = TrailRouter(graph);
        final start = router.nearestNode(pos.latitude, pos.longitude);
        if (start == null) return;
        final far = router.farthestNode(start, miles * 1609.344 / 2);
        if (far == null) return;
        routing.applyStops([start, far, start], graph);
      } catch (_) {}
    });
  }

  Future<void> _onCameraIdle() async {
    if (_controller == null) return;
    try {
      final zoom = await _controller!.getZoomLevel();
      final newBand = _bandFor(zoom);
      if (newBand != _zoomBand && mounted) {
        setState(() => _zoomBand = newBand);
      }
    } catch (_) {}
  }

  int _bandFor(double zoom) {
    if (zoom < _cityZoomThreshold) return 0;
    if (zoom < _streetZoomThreshold) return 1;
    return 2;
  }

  bool _isCategoryVisible(String key) {
    if (_tierAlways.contains(key)) return true;
    if (_tierMid.contains(key)) return _zoomBand >= 1;
    if (_tierDetail.contains(key)) return _zoomBand >= 2;
    return false;
  }

  Widget _zoomHintPill() {
    if (_zoomBand >= 2) return const SizedBox.shrink();
    final text = _zoomBand == 0
        ? 'Zoom in for more points of interest'
        : 'Zoom in for bridges and more';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NaturalPalette.buttonBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in, size: 16, color: NaturalPalette.forest),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: NaturalPalette.ink, fontSize: 12)),
        ],
      ),
    );
  }

  Set<Polyline> _buildPolylines(TrailGraph graph, RoutingState routing) {
    final polys = <Polyline>{};
    // Trails are only tappable-for-detail when NOT actively routing —
    // in routing mode a tap on a trail should register as a start/end/
    // waypoint point instead of popping the detail sheet, so we leave
    // consumeTapEvents off and let the tap fall through to the map's
    // onTap handler.
    final tappable = !routing.routingMode;
    for (var i = 0; i < graph.ways.length; i++) {
      final w = graph.ways[i];
      final coords = w.nodeIndices
          .where((idx) => idx >= 0 && idx < graph.nodes.length)
          .map((idx) => graph.nodes[idx])
          .map((c) => LatLng(c.lat, c.lon))
          .toList();
      if (coords.length < 2) continue;

      final isTrail = w.kind == 'trail';
      polys.add(Polyline(
        polylineId: PolylineId('way_$i'),
        points: coords,
        color: isTrail ? const Color(0xFF6B4A2B) : NaturalPalette.forest,
        width: isTrail ? 3 : 4,
        geodesic: false,
        zIndex: 0,
        consumeTapEvents: tappable,
        onTap: tappable ? () => TrailDetailSheet.show(context, w) : null,
      ));
    }

    if (routing.route != null) {
      final coords = routing.route!.nodes
          .where((idx) => idx >= 0 && idx < graph.nodes.length)
          .map((idx) => graph.nodes[idx])
          .map((c) => LatLng(c.lat, c.lon))
          .toList();
      if (coords.length >= 2) {
        polys.add(Polyline(
          polylineId: const PolylineId('active_route'),
          points: coords,
          color: NaturalPalette.route,
          width: 6,
          geodesic: false,
          zIndex: 10,
        ));
      }
    }
    return polys;
  }

  Set<Marker> _buildMarkers(
      List<POICategory> categories, TrailGraph graph, RoutingState routing) {
    final markers = <Marker>{};
    for (final cat in categories) {
      if (!_isCategoryVisible(cat.key)) continue;
      final hue = _hueForCategory(cat.key);
      final icon = BitmapDescriptor.defaultMarkerWithHue(hue);
      for (final poi in cat.pois) {
        markers.add(Marker(
          markerId: MarkerId('${cat.key}__${poi.id}'),
          position: LatLng(poi.lat, poi.lon),
          icon: icon,
          onTap: () => _showPOIDetail(poi, cat, graph, routing),
        ));
      }
    }

    if (routing.startNode != null) {
      final c = graph.nodes[routing.startNode!];
      markers.add(Marker(
        markerId: const MarkerId('route_start'),
        position: LatLng(c.lat, c.lon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
        zIndex: 20,
      ));
    }
    for (var i = 0; i < routing.waypointNodes.length; i++) {
      final c = graph.nodes[routing.waypointNodes[i]];
      markers.add(Marker(
        markerId: MarkerId('route_waypoint_$i'),
        position: LatLng(c.lat, c.lon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
        zIndex: 20,
      ));
    }
    if (routing.endNode != null) {
      final c = graph.nodes[routing.endNode!];
      markers.add(Marker(
        markerId: const MarkerId('route_end'),
        position: LatLng(c.lat, c.lon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Destination'),
        zIndex: 20,
      ));
    }
    return markers;
  }

  double _hueForCategory(String key) {
    switch (key) {
      case 'playgrounds':
      case 'sports_fields':
        return BitmapDescriptor.hueGreen;
      case 'bridges':
      case 'water_fountains':
        return BitmapDescriptor.hueAzure;
      case 'restrooms':
        return BitmapDescriptor.hueBlue;
      case 'pavilions':
      case 'picnic_areas':
        return BitmapDescriptor.hueOrange;
      case 'parking_park':
      case 'parking_lots':
        return BitmapDescriptor.hueViolet;
      case 'art_benches':
        return BitmapDescriptor.hueMagenta;
      case 'trolley_stops':
        return BitmapDescriptor.hueYellow;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  Future<void> _centerOnUser() async {
    if (!_hasLocationPermission) {
      await _initLocation();
      if (!_hasLocationPermission) return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _lastKnownPosition = pos;
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (_) {}
  }

  void _cycleMapType() {
    setState(() {
      _mapType = switch (_mapType) {
        MapType.normal => MapType.hybrid,
        MapType.hybrid => MapType.satellite,
        _ => MapType.normal,
      };
    });
  }

  Widget _floatingButton(
      {required IconData icon, required VoidCallback onTap, bool selected = false}) {
    return Material(
      color: selected ? NaturalPalette.route : NaturalPalette.buttonBg,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20,
              color: selected ? Colors.white : NaturalPalette.forest),
        ),
      ),
    );
  }
}
