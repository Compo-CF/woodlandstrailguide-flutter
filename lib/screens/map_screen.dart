import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/poi.dart';
import '../models/trail_graph.dart';
import '../services/router.dart';
import '../state/routing_state.dart';
import '../stores/poi_store.dart';
import '../stores/trail_store.dart';
import '../theme/natural_palette.dart';
import '../widgets/route_summary_card.dart';

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
                    ],
                  ),
                ),
                if (!routing.routingMode)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: _zoomHintPill(),
                  ),
                if (routing.routingMode && routing.route == null)
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
                if (routing.route != null && !routing.navigationActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: RouteSummaryCard(
                      route: routing.route!,
                      onStartWalking: () => routing.startNavigation(),
                      onClear: () => routing.clearRoute(),
                      onAddWaypoint: () => routing.toggleWaypointMode(),
                    ),
                  ),
                if (routing.navigationActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _navigatingBar(routing),
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

  /// Temporary compact nav bar shown while navigationActive. Full
  /// turn-by-turn instruction banner + off-route reroute lands in the
  /// next batch; this keeps "Start walking" functional in the
  /// meantime (remaining distance + End button).
  Widget _navigatingBar(RoutingState routing) {
    final remaining = routing.route!.lengthMeters;
    final miles = remaining / 1609.344;
    return Container(
      color: NaturalPalette.route,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Navigating — ${miles.toStringAsFixed(2)} mi total',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => routing.endNavigation(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('End'),
            ),
          ],
        ),
      ),
    );
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
          infoWindow: InfoWindow(
            title: poi.name ?? cat.label,
            snippet: [cat.label, poi.park, poi.village]
                .whereType<String>()
                .join(' · '),
          ),
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
