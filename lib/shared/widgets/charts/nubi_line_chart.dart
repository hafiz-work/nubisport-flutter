import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Themed line chart used by the Progress card. The surrounding labels stay in
/// the card so the visual matches NubiSport rather than a package default.
class NubiLineChart extends StatelessWidget {
  const NubiLineChart({
    super.key,
    required this.values,
    required this.axisMax,
    required this.lineColor,
    required this.gridColor,
    required this.markerColor,
    required this.dotFill,
    this.unit = 'km',
  });

  final List<double> values;
  final double axisMax;
  final Color lineColor;
  final Color gridColor;
  final Color markerColor;
  final Color dotFill;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lastX = (values.length - 1).toDouble();
    final spots = [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];

    return LineChart(
      LineChartData(
        minX: -0.25,
        maxX: lastX + 0.25,
        minY: -axisMax * 0.04,
        maxY: axisMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: axisMax / 2,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [VerticalLine(x: lastX, color: markerColor.withValues(alpha: 0.8), strokeWidth: 1.5)],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [lineColor.withValues(alpha: 0.35), lineColor.withValues(alpha: 0)],
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final isLast = index == spots.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 3.4 : 2.4,
                  color: lineColor,
                  strokeWidth: isLast ? 3 : 2.2,
                  strokeColor: dotFill,
                );
              },
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(AppTheme.radius),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.surfaceContainerHigh,
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} $unit',
                    theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700) ??
                        TextStyle(color: scheme.onSurface, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                )
                .toList(),
          ),
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: markerColor.withValues(alpha: 0.7), strokeWidth: 1),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(radius: 3.4, color: lineColor, strokeWidth: 3, strokeColor: dotFill),
                ),
              ),
          ],
        ),
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }
}
