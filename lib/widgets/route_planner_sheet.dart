import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../models/travel_mode.dart';
import '../services/router.dart';
import '../theme/natural_palette.dart';

/// Sheet for generating a route to hit a target distance or time, with a
/// choice of starting point (current location / address / tap on map),
/// activity (walk/jog/run — drives the pace used for time-to-distance
/// conversion), path type (any/paved/natural), and shape (loop vs
/// out-and-back). Direct port of iOS RoutePlannerSheet.
class RoutePlannerSheet extends StatefulWidget {
  /// Fired with (startNodeIndex, farNodeIndex, plan). MapScreen plugs
  /// both into RoutingState.applyPlan, which knows how to build the
  /// planned route (genuine loop or surface-aware out-and-back) on every
  /// future recompute.
  final void Function(int start, int far, RoutePlan plan) onGenerate;
  final int? Function() nearestNodeToUser;
  final int? Function(double lat, double lon) nearestNodeAt;
  final int? Function(int start, double targetMeters, SurfacePreference pref) farthestNode;
  /// Fired when the user taps "Choose point on map" (or "Change"). The
  /// sheet is already closed by the time this fires (see show()) — MapScreen
  /// drops the map into a one-shot "tap to set start" mode and reopens the
  /// sheet with the draft passed back as initialDraft once a tap lands.
  final void Function(RouteDraft draft) onRequestMapTap;
  /// True if we have a live location fix right now — drives whether
  /// "Current Location" shows a warning. MapScreen no longer needs a fix
  /// just to open this sheet.
  final bool hasLiveLocation;
  /// Restores every selection (including a previously-picked starting
  /// point) when the sheet reopens after "Tap on Map". Null for a fresh,
  /// from-scratch open.
  final RouteDraft? initialDraft;

  const RoutePlannerSheet({
    super.key,
    required this.onGenerate,
    required this.nearestNodeToUser,
    required this.nearestNodeAt,
    required this.farthestNode,
    required this.onRequestMapTap,
    required this.hasLiveLocation,
    this.initialDraft,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(int start, int far, RoutePlan plan) onGenerate,
    required int? Function() nearestNodeToUser,
    required int? Function(double lat, double lon) nearestNodeAt,
    required int? Function(int start, double targetMeters, SurfacePreference pref)
        farthestNode,
    required void Function(RouteDraft draft) onRequestMapTap,
    required bool hasLiveLocation,
    RouteDraft? initialDraft,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RoutePlannerSheet(
        onGenerate: onGenerate,
        nearestNodeToUser: nearestNodeToUser,
        nearestNodeAt: nearestNodeAt,
        farthestNode: farthestNode,
        onRequestMapTap: onRequestMapTap,
        hasLiveLocation: hasLiveLocation,
        initialDraft: initialDraft,
      ),
    );
  }

  @override
  State<RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<RoutePlannerSheet> {
  late bool _targetIsDistance;
  late double _selectedMiles;
  late double _selectedMinutes;
  late TravelMode _activity;
  late SurfacePreference _surfacePreference;
  late PlannedRouteShape _shape;
  late RouteStartMode _startMode;
  late final TextEditingController _addressController;
  double? _addressLat;
  double? _addressLon;
  String? _addressLabel;
  String? _addressError;
  bool _isGeocoding = false;
  double? _tapLat;
  double? _tapLon;
  bool _couldNotGenerate = false;
  bool _missingStartPoint = false;

  static const _mileOptions = <double>[1, 2, 3, 5, 6.2, 10];
  static const _minuteOptions = <double>[15, 20, 30, 45, 60, 90];
  // Bike is a real TravelMode (nav ETA) but doesn't belong in a "plan a
  // walk/jog/run" picker -- left out deliberately.
  static const _activities = <TravelMode>[TravelMode.walk, TravelMode.jog, TravelMode.run];

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    _targetIsDistance = d?.targetIsDistance ?? true;
    _selectedMiles = d?.selectedMiles ?? 2;
    _selectedMinutes = d?.selectedMinutes ?? 30;
    _activity = d?.activity ?? TravelMode.walk;
    _surfacePreference = d?.surfacePreference ?? SurfacePreference.any;
    _shape = d?.shape ?? PlannedRouteShape.loop;
    _startMode = d?.startMode ?? RouteStartMode.currentLocation;
    _addressController = TextEditingController(text: d?.addressText ?? '');
    // The Find button's enabled state is derived from this controller's
    // text, and a TextField edit does NOT rebuild its parent on its own —
    // without this listener the button stayed greyed out no matter what
    // was typed, only springing to life when some unrelated setState
    // happened to rebuild the sheet.
    _addressController.addListener(_onAddressChanged);
    _addressLat = d?.addressLat;
    _addressLon = d?.addressLon;
    _addressLabel = d?.addressLabel;
    _tapLat = d?.tapLat;
    _tapLon = d?.tapLon;
  }

  /// Rebuilds so the Find button's enabled state tracks the field. Also
  /// clears a stale resolved coordinate: once the text no longer matches
  /// what was geocoded, the green "found it" checkmark below the field is
  /// lying, and Generate would silently route from the OLD address.
  void _onAddressChanged() {
    final text = _addressController.text.trim();
    final stale = _addressLabel != null && text != _addressLabel;
    if (!mounted) return;
    setState(() {
      if (stale) {
        _addressLat = null;
        _addressLon = null;
        _addressLabel = null;
      }
      _addressError = null;
    });
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    super.dispose();
  }

  double get _targetMeters {
    if (_targetIsDistance) return _selectedMiles * 1609.344;
    return _selectedMinutes / 60.0 * _activity.paceMph * 1609.344;
  }

  String get _derivedCaption {
    final pace = _activity.paceMph.toStringAsFixed(1);
    if (_targetIsDistance) {
      final mins = (_selectedMiles / _activity.paceMph * 60).round();
      return '≈ $mins min at a ${_activity.label.toLowerCase()} pace ($pace mph)';
    }
    final miles = (_selectedMinutes / 60.0 * _activity.paceMph).toStringAsFixed(1);
    return '≈ $miles mi at a ${_activity.label.toLowerCase()} pace ($pace mph)';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const SizedBox(height: 16),
            const Icon(Icons.track_changes, size: 48, color: NaturalPalette.forest),
            const SizedBox(height: 12),
            const Text('Plan a walk, jog, or run',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: NaturalPalette.ink)),
            const SizedBox(height: 6),
            const Text(
              "Set a target and we'll build a route to match.",
              textAlign: TextAlign.center,
              style: TextStyle(color: NaturalPalette.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _section('Starting point', [
              _chipRow<RouteStartMode>(RouteStartMode.values, _startMode, (m) => m.label,
                  (m) => setState(() => _startMode = m)),
              const SizedBox(height: 8),
              _startPointPanel(),
            ]),
            const SizedBox(height: 16),
            _section('Target', [
              _chipRow<bool>(
                [true, false],
                _targetIsDistance,
                (v) => v ? 'Distance' : 'Time',
                (v) => setState(() => _targetIsDistance = v),
              ),
              const SizedBox(height: 8),
              if (_targetIsDistance)
                _chipRow<double>(_mileOptions, _selectedMiles, _formatMiles,
                    (m) => setState(() => _selectedMiles = m))
              else
                _chipRow<double>(_minuteOptions, _selectedMinutes, (m) => '${m.toInt()} min',
                    (m) => setState(() => _selectedMinutes = m)),
              const SizedBox(height: 6),
              Text(_derivedCaption,
                  style: const TextStyle(fontSize: 12, color: NaturalPalette.inkMuted)),
            ]),
            const SizedBox(height: 16),
            _section('Activity', [
              _chipRow<TravelMode>(
                  _activities, _activity, (m) => m.label, (m) => setState(() => _activity = m)),
            ]),
            const SizedBox(height: 16),
            _section('Path type', [
              _chipRow<SurfacePreference>(SurfacePreference.values, _surfacePreference,
                  (p) => p.label, (p) => setState(() => _surfacePreference = p)),
            ]),
            const SizedBox(height: 16),
            _section('Shape', [
              _chipRow<PlannedRouteShape>(PlannedRouteShape.values, _shape, (s) => s.label,
                  (s) => setState(() => _shape = s)),
              const SizedBox(height: 6),
              Text(_shape.blurb,
                  style: const TextStyle(fontSize: 12, color: NaturalPalette.inkMuted)),
            ]),
            if (_missingStartPoint) ...[
              const SizedBox(height: 14),
              const Text(
                'Choose a starting point first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: NaturalPalette.route, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ] else if (_couldNotGenerate) ...[
              const SizedBox(height: 14),
              const Text(
                "Couldn't find a route that long near there — try a shorter target.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: NaturalPalette.route, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: NaturalPalette.forest,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.directions_run),
                label: const Text('Generate route',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startPointPanel() {
    switch (_startMode) {
      case RouteStartMode.currentLocation:
        if (widget.hasLiveLocation) return const SizedBox.shrink();
        return const Text(
          'Location unavailable — try an address or tap the map instead.',
          style: TextStyle(fontSize: 12, color: NaturalPalette.route),
        );
      case RouteStartMode.address:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: 'Address or place',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _geocodeAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isGeocoding || _addressController.text.trim().isEmpty
                      ? null
                      : _geocodeAddress,
                  style: FilledButton.styleFrom(backgroundColor: NaturalPalette.forest),
                  child: _isGeocoding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Find'),
                ),
              ],
            ),
            if (_addressLabel != null && _addressLat != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: NaturalPalette.forest),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_addressLabel!,
                        style: const TextStyle(fontSize: 12, color: NaturalPalette.forest)),
                  ),
                ],
              ),
            ] else if (_addressError != null) ...[
              const SizedBox(height: 6),
              Text(_addressError!,
                  style: const TextStyle(fontSize: 12, color: NaturalPalette.route)),
            ],
          ],
        );
      case RouteStartMode.tapOnMap:
        if (_tapLat != null && _tapLon != null) {
          return Row(
            children: [
              const Icon(Icons.location_pin, size: 16, color: NaturalPalette.forest),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_tapLat!.toStringAsFixed(4)}, ${_tapLon!.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: NaturalPalette.forest),
                ),
              ),
              TextButton(
                onPressed: _requestMapTap,
                child: const Text('Change',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          );
        }
        return TextButton.icon(
          onPressed: _requestMapTap,
          icon: const Icon(Icons.touch_app, size: 18, color: NaturalPalette.forest),
          label: const Text('Choose point on map',
              style: TextStyle(fontWeight: FontWeight.w600, color: NaturalPalette.forest)),
        );
    }
  }

  void _requestMapTap() {
    final draft = RouteDraft(
      selectedMiles: _selectedMiles,
      selectedMinutes: _selectedMinutes,
      targetIsDistance: _targetIsDistance,
      activity: _activity,
      surfacePreference: _surfacePreference,
      shape: _shape,
      startMode: RouteStartMode.tapOnMap,
      addressText: _addressController.text,
      addressLat: _addressLat,
      addressLon: _addressLon,
      addressLabel: _addressLabel,
      // tapLat/tapLon deliberately omitted (null) — requesting a fresh tap.
    );
    Navigator.of(context).pop();
    widget.onRequestMapTap(draft);
  }

  Future<void> _geocodeAddress() async {
    final text = _addressController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isGeocoding = true;
      _addressError = null;
      _addressLat = null;
      _addressLon = null;
    });
    try {
      // geocoding 5.x is class-based (the old top-level
      // locationFromAddress() function is gone). isPresent() is an
      // Android-only reality check — some devices ship no geocoder
      // backend at all, and without this those users would get a
      // misleading "couldn't find that address" for every input.
      final geocoder = geocoding.Geocoding();
      if (!await geocoder.isPresent()) {
        if (!mounted) return;
        setState(() {
          _isGeocoding = false;
          _addressError = 'Address lookup unavailable on this device — '
              'tap the map to pick a starting point instead.';
        });
        return;
      }
      final results = await geocoder.locationFromAddress(text);
      if (!mounted) return;
      if (results.isNotEmpty) {
        setState(() {
          _isGeocoding = false;
          _addressLat = results.first.latitude;
          _addressLon = results.first.longitude;
          _addressLabel = text;
        });
      } else {
        setState(() {
          _isGeocoding = false;
          _addressError = "Couldn't find that address.";
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGeocoding = false;
        _addressError = "Couldn't find that address.";
      });
    }
  }

  void _generate() {
    setState(() {
      _couldNotGenerate = false;
      _missingStartPoint = false;
    });
    int? start;
    switch (_startMode) {
      case RouteStartMode.currentLocation:
        start = widget.nearestNodeToUser();
        break;
      case RouteStartMode.address:
        start = (_addressLat != null && _addressLon != null)
            ? widget.nearestNodeAt(_addressLat!, _addressLon!)
            : null;
        break;
      case RouteStartMode.tapOnMap:
        start = (_tapLat != null && _tapLon != null)
            ? widget.nearestNodeAt(_tapLat!, _tapLon!)
            : null;
        break;
    }
    if (start == null || _targetMeters <= 0) {
      setState(() => _missingStartPoint = true);
      return;
    }
    final far = widget.farthestNode(start, _targetMeters / 2, _surfacePreference);
    if (far == null) {
      setState(() => _couldNotGenerate = true);
      return;
    }
    final plan = RoutePlan(
      shape: _shape,
      surfacePreference: _surfacePreference,
      targetMeters: _targetMeters,
      activity: _activity,
    );
    widget.onGenerate(start, far, plan);
    Navigator.of(context).pop();
  }

  String _formatMiles(double m) => m == m.roundToDouble() ? '${m.toInt()} mi' : '$m mi';

  Widget _section(String title, List<Widget> children) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NaturalPalette.inkMuted,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _chipRow<T>(
      List<T> options, T selected, String Function(T) label, void Function(T) onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option == selected;
        return GestureDetector(
          onTap: () => onTap(option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? NaturalPalette.forest : NaturalPalette.chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label(option),
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? Colors.white : NaturalPalette.forest)),
          ),
        );
      }).toList(),
    );
  }

  Widget _dragHandle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: NaturalPalette.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
