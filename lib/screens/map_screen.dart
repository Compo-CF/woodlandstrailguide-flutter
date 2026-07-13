import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/poi.dart';
import '../models/trail_graph.dart';
import '../stores/poi_store.dart';
import '../stores/trail_store.dart';
import '../theme/natural_palette.dart';

/// Map tab. Renders every Way as a Google Maps polyline, plus POI
/// markers filtered by zoom level so the map isn't buried in pins at
/// low zoom.
///
///   zoom < 13   → parking, playgrounds, restrooms
///   zoom 13-15  → + pavilions, water fountains, sports fields, picnic areas
///   zoom ≥ 15   → + bridges, art benches, trolley stops
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;
  bool _hasLocationPermission = false;

  /// Current zoom band index — 0 (city), 1 (village), 2 (street). We
  /// only rebuild markers when the band changes, not on every micro-
  /// movement of the camera, so panning stays smooth.
  int _zoomBand = 0;

  static const _cityZoomThreshold = 13.0;
  static const _streetZoomThreshold = 15.0;

  /// Category priority tiers.
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
                  polylines: _buildPolylines(graph),
                  markers: _buildMarkers(poiStore.categories),
                  onMapCreated: (c) => _controller = c,
                  onCameraIdle: _onCameraIdle,
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
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: _zoomHintPill(),
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

  /// Camera stopped moving — recompute what zoom band we're in and
  /// rebuild markers if it changed. Panning within a band doesn't
  /// trigger a rebuild.
  Future<void> _onCameraIdle() async {
    if (_controller == null) return;
    try {
      final zoom = await _controller!.getZoomLevel();
      final newBand = _bandFor(zoom);
      if (newBand != _zoomBand && mounted) {
        setState(() => _zoomBand = newBand);
      }
    } catch (_) {
      // getZoomLevel can fail during controller disposal — ignore.
    }
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
    return false; // categories not listed are never shown on the map
  }

  /// Optional hint pill in the bottom-left that tells users to zoom in
  /// for more detail at low zoom. Disappears once they zoom past the
  /// street threshold.
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
          const Icon(Icons.zoom_in,
              size: 16, color: NaturalPalette.forest),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: NaturalPalette.ink, fontSize: 12)),
        ],
      ),
    );
  }

  /// Convert every Way into a Google Maps Polyline. Colors mirror iOS.
  Set<Polyline> _buildPolylines(TrailGraph graph) {
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
        color: isTrail
            ? const Color(0xFF6B4A2B)
            : NaturalPalette.forest,
        width: isTrail ? 3 : 4,
        geodesic: false,
      ));
    }
    return polys;
  }

  Set<Marker> _buildMarkers(List<POICategory> categories) {
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

  Widget _floatingButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: NaturalPalette.buttonBg,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: NaturalPalette.forest),
        ),
      ),
    );
  }
}
