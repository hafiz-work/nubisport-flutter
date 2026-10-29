import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';

/// Strava-style map style picker. Visual only for now: choosing a style does
/// not change the map yet (terrain/heatmaps are placeholders).
Future<void> showMapStyleSheet(BuildContext context) {
  return FamilyModalSheet.show<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final sheetTheme = Theme.of(sheetContext);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle('Map style'),
                const SizedBox(height: 10),
                _OptionsRow(
                  options: const [
                    _MapOption(
                      label: 'Standard',
                      colors: [Color(0xFF5F8E6A), Color(0xFF2F5D62)],
                      selected: true,
                      premium: false,
                    ),
                    _MapOption(
                      label: 'Satellite',
                      colors: [Color(0xFF2E4A32), Color(0xFF1E2E24)],
                      icon: Icons.satellite_alt,
                    ),
                    _MapOption(
                      label: 'Hybrid',
                      colors: [Color(0xFF3F6B4A), Color(0xFF25403A)],
                    ),
                    _MapOption(
                      label: 'Winter',
                      colors: [Color(0xFFC9D6DE), Color(0xFF8FA9B5)],
                      icon: Icons.ac_unit,
                    ),
                  ],
                  onTap: (option) => _comingSoon(context, option),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Heatmap', info: true),
                const SizedBox(height: 10),
                _OptionsRow(
                  options: const [
                    _MapOption(
                      label: 'Global',
                      colors: [Color(0xFF2D5BFF), Color(0xFFFF4D3D)],
                      heatmap: true,
                    ),
                    _MapOption(
                      label: 'Weekly',
                      colors: [Color(0xFFFFB020), Color(0xFFE23A3A)],
                      heatmap: true,
                    ),
                    _MapOption(
                      label: 'Night',
                      colors: [Color(0xFF3C4F5C), Color(0xFFC79A4B)],
                      heatmap: true,
                    ),
                    _MapOption(
                      label: 'Personal',
                      colors: [Color(0xFFE86A8B), Color(0xFF7B3FF2)],
                      heatmap: true,
                    ),
                  ],
                  onTap: (option) => _comingSoon(context, option),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Layers', info: true),
                const SizedBox(height: 10),
                _OptionsRow(
                  options: const [
                    _MapOption(
                      label: 'POI',
                      colors: [Color(0xFF20402F), Color(0xFF122A1E)],
                      icon: Icons.restaurant,
                    ),
                    _MapOption(
                      label: 'Bike lanes',
                      colors: [Color(0xFF2F5D3A), Color(0xFF1C3B28)],
                      icon: Icons.directions_bike,
                    ),
                  ],
                  onTap: (option) => _comingSoon(context, option),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Terrain', info: true),
                const SizedBox(height: 10),
                _OptionsRow(
                  options: const [
                    _MapOption(
                      label: 'Terrain',
                      colors: [Color(0xFF6B4F3A), Color(0xFF3E2C20)],
                      icon: Icons.terrain,
                    ),
                    _MapOption(
                      label: 'Contour',
                      colors: [Color(0xFF8A6A4F), Color(0xFF4A3525)],
                      icon: Icons.landscape,
                    ),
                    _MapOption(
                      label: 'Slope',
                      colors: [Color(0xFF7B5A3E), Color(0xFF3A2A1D)],
                      icon: Icons.trending_up,
                    ),
                  ],
                  onTap: (option) => _comingSoon(context, option),
                ),
                const SizedBox(height: 16),
                Text(
                  'More map styles are coming. The map currently uses the standard style.',
                  style: sheetTheme.textTheme.bodySmall?.copyWith(
                    color: sheetTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // The map hides its own credit button (like Strava); OSM's ODbL still needs it shown somewhere.
                Text(
                  'Map © OpenFreeMap · data © OpenStreetMap contributors (ODbL).',
                  style: sheetTheme.textTheme.bodySmall?.copyWith(
                    color: sheetTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _comingSoon(BuildContext context, _MapOption option) {
  if (option.selected) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('${option.label} is coming soon.')));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.info = false});
  final String text;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(text, style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
        if (info) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.info_outline,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

class _MapOption {
  const _MapOption({
    required this.label,
    required this.colors,
    this.icon,
    this.premium = true,
    this.heatmap = false,
    this.selected = false,
  });

  final String label;
  final List<Color> colors;
  final IconData? icon;
  final bool premium;
  final bool heatmap;
  final bool selected;
}

class _OptionsRow extends StatelessWidget {
  const _OptionsRow({required this.options, required this.onTap});
  final List<_MapOption> options;
  final void Function(_MapOption option) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Always 4 columns so tiles keep the same size in every row.
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: i < options.length
                ? _OptionTile(
                    option: options[i],
                    onTap: () => onTap(options[i]),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.onTap});
  final _MapOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                    color: option.selected
                        ? AppColors.orange
                        : scheme.outlineVariant,
                    width: option.selected ? 2.5 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius - 1),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: option.colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: _PreviewPainter(
                            heatmap: option.heatmap,
                            routeColor: option.selected
                                ? AppColors.orange
                                : Colors.white,
                          ),
                        ),
                        if (option.icon != null)
                          Center(
                            child: Icon(
                              option.icon,
                              size: 24,
                              color: Colors.white.withValues(alpha: 0.9),
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (option.premium)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            option.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: option.selected ? FontWeight.w700 : FontWeight.w500,
              color: option.selected ? AppColors.orange : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({required this.heatmap, required this.routeColor});
  final bool heatmap;
  final Color routeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (heatmap) {
      final blobs = [(0.3, 0.35, 0.28), (0.6, 0.55, 0.34), (0.45, 0.75, 0.24)];
      for (final (x, y, r) in blobs) {
        final rect = Rect.fromCircle(
          center: Offset(size.width * x, size.height * y),
          radius: size.width * r,
        );
        canvas.drawCircle(
          rect.center,
          rect.width / 2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.75),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      }
      return;
    }

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.78)
      ..cubicTo(
        size.width * 0.05,
        size.height * 0.55,
        size.width * 0.35,
        size.height * 0.15,
        size.width * 0.58,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.68,
        size.width * 0.55,
        size.height * 0.85,
        size.width * 0.85,
        size.height * 0.72,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = routeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    _startDot(canvas, Offset(size.width * 0.28, size.height * 0.78));
  }

  void _startDot(Canvas canvas, Offset at) {
    canvas.drawCircle(at, 3.6, Paint()..color = Colors.white);
    canvas.drawCircle(at, 2, Paint()..color = const Color(0xFF2EB82E));
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.heatmap != heatmap || oldDelegate.routeColor != routeColor;
}
