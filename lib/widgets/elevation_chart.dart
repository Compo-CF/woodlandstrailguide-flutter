import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/elevation_service.dart';
import '../theme/natural_palette.dart';

/// Elevation profile — area+line chart with gain/loss labels above.
/// Direct port of iOS ElevationChartView (SwiftUI Charts) using
/// fl_chart's AreaData-equivalent LineChartBarData with belowBarData.
class ElevationChartView extends StatelessWidget {
  final ElevationProfile profile;
  const ElevationChartView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < profile.distancesMeters.length; i++) {
      final miles = profile.distancesMeters[i] / 1609.344;
      final feet = profile.elevationsMeters[i] * 3.28084;
      spots.add(FlSpot(miles, feet));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final minY = profile.minMeters * 3.28084;
    final maxY = profile.maxMeters * 3.28084;
    final pad = (maxY - minY) * 0.15 + 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _gainLossChip(Icons.trending_up, '${profile.gainFeet.round()} ft up',
                NaturalPalette.forest),
            const SizedBox(width: 10),
            _gainLossChip(Icons.trending_down, '${profile.lossFeet.round()} ft down',
                NaturalPalette.route),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: NaturalPalette.forest,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        NaturalPalette.forest.withValues(alpha: 0.28),
                        NaturalPalette.forest.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gainLossChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
