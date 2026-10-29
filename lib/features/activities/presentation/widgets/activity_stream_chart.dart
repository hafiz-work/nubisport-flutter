import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Strava-style area chart over distance: rises in on first build, scrub to read a value.
class ActivityStreamChart extends StatefulWidget {
  const ActivityStreamChart({
    super.key,
    required this.xKm,
    required this.values,
    required this.color,
    required this.format,
    required this.unit,
    this.background,
    this.inverted = false,
  });

  final List<double> xKm;

  /// Same length as [xKm]; null = no reading there (drawn as a gap).
  final List<double?> values;
  final Color color;

  /// Axis and tooltip text for a value.
  final String Function(double value) format;

  /// Shown in place of the lowest axis label, like Strava's "m" / "/km".
  final String unit;

  /// Drawn grey behind the main series, scaled to the chart height (elevation under pace).
  final List<double?>? background;

  /// Lower is better (pace): drawn upside down so faster sits higher.
  final bool inverted;

  @override
  State<ActivityStreamChart> createState() => _ActivityStreamChartState();
}

class _ActivityStreamChartState extends State<ActivityStreamChart> {
  bool _shown = false;
  int? _scrubIndex;

  @override
  void initState() {
    super.initState();
    // First frame flat, then fl_chart tweens up to the real values.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ys = [
      for (final v in widget.values)
        v == null ? null : (widget.inverted ? -v : v),
    ];
    final known = ys.whereType<double>();
    if (known.length < 2 || widget.xKm.last <= 0) {
      return const SizedBox.shrink();
    }

    var minY = known.reduce(math.min), maxY = known.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.08, 1.0);
    minY -= pad;
    maxY += pad;
    final step = _niceStep((maxY - minY) / 4);
    final maxX = widget.xKm.last;

    FlSpot spot(int i, double? y) =>
        y == null ? FlSpot.nullSpot : FlSpot(widget.xKm[i], _shown ? y : minY);

    final bg = widget.background;
    final bgKnown = bg?.whereType<double>() ?? const <double>[];
    final bgMin = bgKnown.isEmpty ? 0.0 : bgKnown.reduce(math.min);
    final bgSpan = bgKnown.isEmpty
        ? 1.0
        : math.max(bgKnown.reduce(math.max) - bgMin, 1.0);
    final bgColor = scheme.onSurfaceVariant.withValues(alpha: 0.28);

    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 11,
    );
    final grid = scheme.outlineVariant.withValues(alpha: 0.6);

    final bars = [
      if (bgKnown.length > 1)
        LineChartBarData(
          spots: [
            for (var i = 0; i < bg!.length; i++)
              spot(
                i,
                bg[i] == null
                    ? null
                    : minY + (bg[i]! - bgMin) / bgSpan * (maxY - minY) * 0.95,
              ),
          ],
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: bgColor),
        ),
      LineChartBarData(
        spots: [for (var i = 0; i < ys.length; i++) spot(i, ys[i])],
        color: widget.color,
        barWidth: 1.6,
        isStrokeJoinRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: widget.color.withValues(alpha: 0.55),
        ),
      ),
    ];
    final main = bars.last;

    return AspectRatio(
      aspectRatio: 1.45,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: step,
            verticalInterval: _niceStep(maxX / 4),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: grid, strokeWidth: 0.8),
            getDrawingVerticalLine: (_) =>
                FlLine(color: grid, strokeWidth: 0.8),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: step,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  final text = value == meta.min
                      ? widget.unit
                      : widget.format(widget.inverted ? -value : value);
                  return Text(text, style: labelStyle);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _niceStep(maxX / 4),
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${_trim(value)} km', style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineBarsData: bars,
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              final index = response?.lineBarSpots?.firstOrNull?.spotIndex;
              if (index != null && index != _scrubIndex) {
                HapticFeedback.selectionClick();
              }
              _scrubIndex = event.isInterestedForInteractions ? index : null;
            },
            touchTooltipData: LineTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(AppTheme.radius),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  s.bar != main
                      ? null
                      : LineTooltipItem(
                          '${widget.format(widget.inverted ? -s.y : s.y)}\n',
                          TextStyle(
                            color: scheme.onInverseSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: '${s.x.toStringAsFixed(2)} km',
                              style: TextStyle(
                                color: scheme.onInverseSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
              ],
            ),
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                bar != main
                    ? null
                    : TouchedSpotIndicatorData(
                        FlLine(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          strokeWidth: 1,
                        ),
                        FlDotData(
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: widget.color,
                            strokeWidth: 2,
                            strokeColor: scheme.surface,
                          ),
                        ),
                      ),
            ],
          ),
        ),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// 1, 2, 2.5 or 5 x 10^n, so axis lines land on round numbers.
double _niceStep(double raw) {
  if (raw <= 0) return 1;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  return mag *
      (n <= 1
          ? 1
          : n <= 2
          ? 2
          : n <= 2.5
          ? 2.5
          : n <= 5
          ? 5
          : 10);
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
