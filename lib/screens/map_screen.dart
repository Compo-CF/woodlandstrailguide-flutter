import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/trail_graph.dart';
import '../stores/trail_store.dart';
import '../theme/natural_palette.dart';

/// Map tab. Renders every Way in the TrailGraph as a Google Maps
/// polyline. Pathways get one color/thickness, natural-surface trails
/// get another. Camera initially centers on the graph's bbox.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TrailStore>();
    final graph = store.graph;

    return Scaffold(
      body: graph == null
          ? _loadingOrError(store)
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(graph.bbox.centerLat, graph.bbox.centerLon),
                    zoom: 12,
                  ),
                  mapType: _mapType,
                  polylines: _buildPolylines(graph),
                  onMapCreated: (c) => _controller = c,
                  myLocationEnabled: false, // enable after location perms wired
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
                        icon: _mapType == MapType.normal
                            ? Icons.map_outlined
                            : Icons.satellite_alt,
                        onTap: _cycleMapType,
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

  /// Convert every Way's node indices into a Google Maps Polyline. This
  /// is the naïve version — no clustering, no simplification. Ships the
  /// full trail graph (~1,500 ways) to Google Maps' rendering thread.
  /// If perf tanks on low-end phones we'll add level-of-detail culling
  /// later, but starting simple.
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
