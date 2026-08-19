import 'package:flutter/material.dart';

import '../models/travel_mode.dart';
import '../services/router.dart';
import '../theme/natural_palette.dart';

/// Sheet for generating a route to hit a target distance or time, with a
/// choice of activity (walk/jog/run — drives the pace used for time-to-
/// distance conversion), path type (any/paved/natural), and shape (loop
/// vs out-and-back). Direct port of iOS RoutePlannerSheet — replaces the
/// old fixed-distance-only LoopBuilderSheet.
class RoutePlannerSheet extends StatefulWidget {
  /// Fired with (startNodeIndex, farNodeIndex, plan). MapScreen plugs
  /// both into RoutingState.applyPlan, which knows how to build the
  /// planned route (genuine loop or surface-aware out-and-back) on every
  /// future recompute.
  final void Function(int start, int far, RoutePlan plan) onGenerate;
  final int? Function() nearestNodeToUser;
  final int? Function(int start, double targetMeters, SurfacePreference pref) farthestNode;

  const RoutePlannerSheet({
    super.key,
    required this.onGenerate,
    required this.nearestNodeToUser,
    required this.farthestNode,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(int start, int far, RoutePlan plan) onGenerate,
    required int? Function() nearestNodeToUser,
    required int? Function(int start, double targetMeters, SurfacePreference pref)
        farthestNode,
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
        farthestNode: farthestNode,
      ),
    );
  }

  @override
  State<RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

enum _TargetKind { distance, time }

class _RoutePlannerSheetState extends State<RoutePlannerSheet> {
  _TargetKind _targetKind = _TargetKind.distance;
  double _selectedMiles = 2;
  double _selectedMinutes = 30;
  TravelMode _activity = TravelMode.walk;
  SurfacePreference _surfacePreference = SurfacePreference.any;
  PlannedRouteShape _shape = PlannedRouteShape.loop;
  bool _couldNotGenerate = false;

  static const _mileOptions = <double>[1, 2, 3, 5, 6.2, 10];
  static const _minuteOptions = <double>[15, 20, 30, 45, 60, 90];
  // Bike is a real TravelMode (nav ETA) but doesn't belong in a "plan a
  // walk/jog/run" picker -- left out deliberately.
  static const _activities = <TravelMode>[TravelMode.walk, TravelMode.jog, TravelMode.run];

  double get _targetMeters {
    switch (_targetKind) {
      case _TargetKind.distance:
        return _selectedMiles * 1609.344;
      case _TargetKind.time:
        return _selectedMinutes / 60.0 * _activity.paceMph * 1609.344;
    }
  }

  String get _derivedCaption {
    final pace = _activity.paceMph.toStringAsFixed(1);
    switch (_targetKind) {
      case _TargetKind.distance:
        final mins = (_selectedMiles / _activity.paceMph * 60).round();
        return '≈ $mins min at a ${_activity.label.toLowerCase()} pace ($pace mph)';
      case _TargetKind.time:
        final miles = (_selectedMinutes / 60.0 * _activity.paceMph).toStringAsFixed(1);
        return '≈ $miles mi at a ${_activity.label.toLowerCase()} pace ($pace mph)';
    }
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
              "Set a target and we'll build a route to match, starting from where you are.",
              textAlign: TextAlign.center,
              style: TextStyle(color: NaturalPalette.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _section('Target', [
              _chipRow<_TargetKind>(
                [_TargetKind.distance, _TargetKind.time],
                _targetKind,
                (k) => k == _TargetKind.distance ? 'Distance' : 'Time',
                (k) => setState(() => _targetKind = k),
              ),
              const SizedBox(height: 8),
              if (_targetKind == _TargetKind.distance)
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
            if (_couldNotGenerate) ...[
              const SizedBox(height: 14),
              const Text(
                "Couldn't find a route that long near you — try a shorter target.",
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

  void _generate() {
    setState(() => _couldNotGenerate = false);
    final start = widget.nearestNodeToUser();
    if (start == null || _targetMeters <= 0) {
      setState(() => _couldNotGenerate = true);
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
