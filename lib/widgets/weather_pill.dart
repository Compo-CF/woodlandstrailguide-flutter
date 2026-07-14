import 'package:flutter/material.dart';

import '../services/weather_service.dart';
import '../theme/natural_palette.dart';

/// Compact weather badge for the map's top-left. Icon + temperature at
/// a glance; tap expands to WeatherDetailSheet. Direct port of iOS
/// WeatherPill.
class WeatherPill extends StatelessWidget {
  final WeatherSnapshot? snapshot;
  final VoidCallback onTap;

  const WeatherPill({super.key, required this.snapshot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Material(
      color: NaturalPalette.buttonBg,
      shape: const StadiumBorder(side: BorderSide(color: NaturalPalette.hairline, width: 0.5)),
      elevation: 3,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: s == null
            ? const SizedBox(
                width: 44,
                height: 34,
                child: Icon(Icons.cloud_outlined, size: 15, color: NaturalPalette.inkMuted),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconFor(s.conditionIconName), size: 15, color: NaturalPalette.forest),
                    const SizedBox(width: 6),
                    Text('${s.temperatureF.round()}°',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: NaturalPalette.forest)),
                  ],
                ),
              ),
      ),
    );
  }

  static IconData _iconFor(String name) {
    switch (name) {
      case 'wb_sunny': return Icons.wb_sunny;
      case 'wb_cloudy': return Icons.wb_cloudy;
      case 'foggy': return Icons.foggy;
      case 'grain': return Icons.grain;
      case 'ac_unit': return Icons.ac_unit;
      case 'water_drop': return Icons.water_drop;
      case 'thunderstorm': return Icons.thunderstorm;
      default: return Icons.cloud;
    }
  }
}

/// Expanded weather detail sheet — condition, temperature, wind,
/// walking advisory, last-updated, and a refresh button. Direct port
/// of iOS WeatherDetailSheet.
class WeatherDetailSheet extends StatefulWidget {
  final WeatherSnapshot? snapshot;
  final DateTime? lastFetch;
  final Future<void> Function() onRefresh;

  const WeatherDetailSheet({
    super.key,
    required this.snapshot,
    required this.lastFetch,
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required WeatherSnapshot? snapshot,
    required DateTime? lastFetch,
    required Future<void> Function() onRefresh,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: NaturalPalette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WeatherDetailSheet(
        snapshot: snapshot,
        lastFetch: lastFetch,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<WeatherDetailSheet> createState() => _WeatherDetailSheetState();
}

class _WeatherDetailSheetState extends State<WeatherDetailSheet> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Weather',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: NaturalPalette.ink)),
                const Spacer(),
                IconButton(
                  onPressed: _refreshing
                      ? null
                      : () async {
                          setState(() => _refreshing = true);
                          await widget.onRefresh();
                          if (mounted) setState(() => _refreshing = false);
                        },
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: NaturalPalette.forest),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: NaturalPalette.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (s == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Weather unavailable right now. Try refreshing when you have a signal.',
                  style: TextStyle(color: NaturalPalette.inkMuted),
                ),
              )
            else ...[
              Row(
                children: [
                  Icon(WeatherPill._iconFor(s.conditionIconName),
                      size: 40, color: NaturalPalette.forest),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.temperatureF.round()}°F',
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: NaturalPalette.ink)),
                      Text(s.conditionLabel,
                          style: const TextStyle(
                              fontSize: 14, color: NaturalPalette.inkMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Wind', style: TextStyle(color: NaturalPalette.inkMuted)),
                  const Spacer(),
                  Text('${s.windMph.round()} mph ${s.windCardinal}',
                      style: const TextStyle(color: NaturalPalette.ink)),
                ],
              ),
              if (s.walkingAdvisory != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: NaturalPalette.route),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.walkingAdvisory!,
                          style: const TextStyle(color: NaturalPalette.ink)),
                    ),
                  ],
                ),
              ],
              if (widget.lastFetch != null) ...[
                const SizedBox(height: 16),
                Text('Last updated ${_relativeTime(widget.lastFetch!)}',
                    style: const TextStyle(fontSize: 12, color: NaturalPalette.inkMuted)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }
}
