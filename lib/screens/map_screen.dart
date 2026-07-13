import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/poi.dart';
import '../models/trail_graph.dart';
import '../stores/poi_store.dart';
import '../stores/trail_store.dart';
import '../theme/natural_palette.dart';

/// Map tab. Renders every Way in the TrailGraph as a Google Maps
/// polyline, plus POI markers for the interesting categories.
/// Cycle button toggles Standard / Hybrid / Satellite. Recenter
/// button jumps to the user's location.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;
  bool _hasLocationPermission = false;

  /// Categories we render as pins on the map. Everything else (benches,
  /// bike racks, dog bag stations, trail markers, monuments) is data
  /// we HAVE but don't clutter the map with. Mirrors iOS's
  /// `alongRouteSkip` filter in reverse.
  static const _mapCategoryAllow = <String>{
    'bridges',
    'restrooms',
    'water_fountains',
    'playgrounds',
    'pavilions',
    'sports_fields',
    'parking_park',
    'parking_lots',
    'art_benches',
    'trolley_stops',
    'picnic_areas',
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
            ? const Color(0xFF6B4A2B) // brown for natural trails
            : NaturalPalette.forest,   // green for paved pathways
        width: isTrail ? 3 : 4,
        geodesic: false,
      ));
    }
    return polys;
  }

  /// One marker per POI in an allowed category. Skips the noisy
  /// categories (benches, bike racks, etc.) that would clutter
  /// the map. Tint approximated to Google's built-in marker hues.
  Set<Marker> _buildMarkers(List<POICategory> categories) {
    final markers = <Marker>{};
    for (final cat in categories) {
      if (!_mapCategoryAllow.contains(cat.key)) continue;
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
    } catch (_) {
      // Silent — GPS unavailable, user off-network, etc.
    }
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
