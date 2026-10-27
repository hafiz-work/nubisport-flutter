import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../../domain/models/activity.dart';
import '../activity_format.dart';

/// Own activity: Strava-style template picker. Someone else's: a small floating sheet, no templates.
Future<void> showActivityShareSheet(BuildContext context, Activity activity, {required bool isMine}) {
  if (!isMine) {
    return FamilyModalSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _OtherActivityShareSheet(activity: activity, sheetContext: sheetContext),
    );
  }
  return FamilyModalSheet.showMaterialDefault<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ActivityShareSheet(activity: activity, sheetContext: sheetContext),
  );
}

class _ActivityShareSheet extends StatefulWidget {
  const _ActivityShareSheet({required this.activity, required this.sheetContext});
  final Activity activity;
  final BuildContext sheetContext;

  @override
  State<_ActivityShareSheet> createState() => _ActivityShareSheetState();
}

class _ActivityShareSheetState extends State<_ActivityShareSheet> {
  final _cardKey = GlobalKey();
  bool _busy = false;
  ShareTemplate _template = ShareTemplate.values.first;

  String get _caption => _shareCaption(widget.activity);

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _cardKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null || !mounted) return;

      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['nubi-${widget.activity.id}-${_template.name}.png'],
          text: _caption,
          subject: widget.activity.title,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Couldn\'t share image.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCaption() async {
    await Clipboard.setData(ClipboardData(text: _caption));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Caption copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screen = MediaQuery.sizeOf(widget.sheetContext);

    return SizedBox(
      height: screen.height * 0.9 - 48,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Share activity', style: theme.textTheme.headlineSmall)),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(widget.sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: ShareTemplate.values.length,
                itemBuilder: (context, i) {
                  final t = ShareTemplate.values[i];
                  final selected = t == _template;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: t.label,
                    child: GestureDetector(
                      key: ValueKey(t),
                      onTap: () => setState(() => _template = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                child: CustomPaint(
                                  // Checkerboard marks templates that export with a transparent background.
                                  painter: t.transparent ? const _CheckerPainter() : null,
                                  child: RepaintBoundary(
                                    key: selected ? _cardKey : null,
                                    child: t.build(widget.activity),
                                  ),
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(Icons.check_circle, color: Colors.white, size: 22),
                                ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      t.sizeLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Text(
                      '${_template.label} · ${_template.hint}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _shareImage,
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share, size: 18),
                        label: Text(_busy ? 'Preparing image…' : 'Share image'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _copyCaption,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy caption'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shareCaption(Activity a) =>
    '${a.userName} · ${a.title}\n'
    '${formatDistance(a.distanceKm)} · ${formatDuration(a.duration)} · '
    '${formatPace(a.pace)}/km\n'
    '${a.location}\n'
    '#NubiSport';

class _OtherActivityShareSheet extends StatelessWidget {
  const _OtherActivityShareSheet({required this.activity, required this.sheetContext});
  final Activity activity;
  final BuildContext sheetContext;

  Future<void> _shareText(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: _shareCaption(activity),
        subject: activity.title,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _shareCaption(activity)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Caption copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Share to', style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _shareText(context),
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share to…'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy caption'),
          ),
        ],
      ),
    );
  }
}

class ActivityShareCard extends StatelessWidget {
  const ActivityShareCard({super.key, required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final date = formatActivityDate(activity.startedAt).split(',').first.toUpperCase();
    return SizedBox(
      width: 360,
      height: 450,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy2, AppColors.navy],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -90, right: -70, child: _Glow(color: AppColors.orange, size: 230)),
            const Positioned(bottom: -110, left: -90, child: _Glow(color: AppColors.onDark, size: 240)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(7)),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NUBI SPORT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        date,
                        style: const TextStyle(
                          color: AppColors.onDarkMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.orange,
                        child: Text(
                          activity.userInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTheme.displayFont,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              activity.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.onDarkMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _ShareRoutePainter(points: activity.route)),
                          ),
                          if (activity.route.length < 2)
                            const Center(child: Icon(Icons.route, color: Colors.white24, size: 40)),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(activityIcon(activity.type), size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    activityLabel(activity.type).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ShareStat(label: 'DISTANCE', value: formatDistance(activity.distanceKm)),
                      _ShareStat(label: 'TIME', value: formatDuration(activity.duration)),
                      _ShareStat(label: 'PACE', value: formatPace(activity.pace)),
                      _ShareStat(label: 'ELEV', value: '${activity.elevationGainM} m'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'nubisport.hafizbahtiar.com',
                        style: TextStyle(color: AppColors.onDarkMuted, fontSize: 8.5),
                      ),
                      const Spacer(),
                      const Text(
                        '#NubiSport',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onDarkMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _ShareRoutePainter extends CustomPainter {
  const _ShareRoutePainter({
    required this.points,
    this.line = AppColors.orange,
    this.casing = Colors.white,
    this.grid = true,
  });
  final List<GeoPoint> points;
  final Color line;
  final Color? casing;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.045)
        ..strokeWidth = 1;
      for (var i = 1; i < 6; i++) {
        final x = size.width * i / 6;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (var i = 1; i < 4; i++) {
        final y = size.height * i / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    if (latSpan == 0 && lngSpan == 0) {
      canvas.drawCircle(size.center(Offset.zero), 5, Paint()..color = line);
      return;
    }

    const padding = 18.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;
    final scaleX = lngSpan == 0 ? double.infinity : availableWidth / lngSpan;
    final scaleY = latSpan == 0 ? double.infinity : availableHeight / latSpan;
    final scale = math.min(scaleX, scaleY);
    final drawWidth = lngSpan * scale;
    final drawHeight = latSpan * scale;
    final left = (size.width - drawWidth) / 2;
    final top = (size.height - drawHeight) / 2;

    final offsets = [
      for (final point in points)
        Offset(left + (point.longitude - minLng) * scale, top + drawHeight - (point.latitude - minLat) * scale),
    ];

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    if (casing != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = casing!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(offsets.first, 4.5, Paint()..color = const Color(0xFF2EB82E));
    canvas.drawCircle(
      offsets.first,
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(offsets.last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(offsets.last, 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _ShareRoutePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.line != line ||
      oldDelegate.casing != casing ||
      oldDelegate.grid != grid;
}

/// Share image presets, Strava-style. Transparent ones are stickers to place over your own photo.
enum ShareTemplate {
  classic('Classic', '4:5 card with a route map and stats.'),
  story('Story', '9:16 format for Instagram / WhatsApp Story.'),
  statsSticker('Statistik', 'Transparent PNG — place it over your photo.', transparent: true),
  routeSticker('Route', 'Route only, transparent PNG.', transparent: true),
  bigNumber('Big distance', '1:1 square, distance in a large font.'),
  light('Minimal', '1:1 square on a clean white background.'),
  poster('Poster', '4:5 card, full route with stats below.'),
  receipt('Receipt', '4:5 card in a shop-receipt style — just for fun.');

  const ShareTemplate(this.label, this.hint, {this.transparent = false});
  final String label;
  final String hint;
  final bool transparent;

  String get sizeLabel => switch (this) {
    ShareTemplate.classic => '4:5',
    ShareTemplate.story => '9:16',
    ShareTemplate.statsSticker || ShareTemplate.routeSticker => 'PNG',
    ShareTemplate.bigNumber || ShareTemplate.light => '1:1',
    ShareTemplate.poster || ShareTemplate.receipt => '4:5',
  };

  Widget build(Activity a) => switch (this) {
    ShareTemplate.classic => ActivityShareCard(activity: a),
    ShareTemplate.story => _StoryCard(activity: a),
    ShareTemplate.statsSticker => _StatsSticker(activity: a),
    ShareTemplate.routeSticker => _RouteSticker(activity: a),
    ShareTemplate.bigNumber => _BigNumberCard(activity: a),
    ShareTemplate.light => _LightCard(activity: a),
    ShareTemplate.poster => _PosterCard(activity: a),
    ShareTemplate.receipt => _ReceiptCard(activity: a),
  };
}

const _shadow = [Shadow(color: Colors.black54, blurRadius: 6)];

TextStyle _display(double size, {Color color = Colors.white, List<Shadow>? shadows}) => TextStyle(
  fontFamily: AppTheme.displayFont,
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.0,
  shadows: shadows,
);

TextStyle _caps(double size, {Color color = AppColors.onDarkMuted, List<Shadow>? shadows}) =>
    TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700, letterSpacing: 1.2, shadows: shadows);

Widget _brand({Color color = Colors.white, List<Shadow>? shadows}) => Text(
  'NUBI SPORT',
  style: _caps(11, color: color, shadows: shadows).copyWith(letterSpacing: 2),
);

Widget _stack(
  String label,
  String value, {
  Color color = Colors.white,
  Color? muted,
  double size = 30,
  List<Shadow>? shadows,
}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      label,
      style: _caps(9, color: muted ?? color.withValues(alpha: 0.7), shadows: shadows),
    ),
    const SizedBox(height: 4),
    FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value,
        style: _display(size, color: color, shadows: shadows),
      ),
    ),
  ],
);

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.orange, AppColors.orangeInk, AppColors.navy],
          stops: [0, 0.35, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brand(),
          const SizedBox(height: 24),
          Text(activity.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _display(38)),
          const SizedBox(height: 6),
          Text(
            '${activity.userName} · ${formatActivityDate(activity.startedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Expanded(
            child: CustomPaint(
              painter: _ShareRoutePainter(points: activity.route, grid: false),
              size: Size.infinite,
            ),
          ),
          _stack('DISTANCE', formatDistance(activity.distanceKm), size: 56),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _stack('TIME', formatDuration(activity.duration), size: 26),
              _stack('PACE', '${formatPace(activity.pace)}/km', size: 26),
              _stack('ELEV', '${activity.elevationGainM} m', size: 26),
            ].map((w) => Flexible(child: w)).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatsSticker extends StatelessWidget {
  const _StatsSticker({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 640,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stack('DISTANCE', formatDistance(activity.distanceKm), shadows: _shadow),
          const SizedBox(height: 20),
          _stack('PACE', '${formatPace(activity.pace)} /km', shadows: _shadow),
          const SizedBox(height: 20),
          _stack('TIME', formatDuration(activity.duration), shadows: _shadow),
          const SizedBox(height: 24),
          _brand(shadows: _shadow),
        ],
      ),
    );
  }
}

class _RouteSticker extends StatelessWidget {
  const _RouteSticker({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 640,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _ShareRoutePainter(
                points: activity.route,
                grid: false,
                line: Colors.white,
                casing: Colors.black26,
              ),
              size: Size.infinite,
            ),
          ),
          Text(formatDistance(activity.distanceKm), style: _display(40, shadows: _shadow)),
          const SizedBox(height: 6),
          _brand(shadows: _shadow),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _BigNumberCard extends StatelessWidget {
  const _BigNumberCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      color: AppColors.orange,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(activityIcon(activity.type), color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(activityLabel(activity.type).toUpperCase(), style: _caps(11, color: Colors.white)),
              const Spacer(),
              _brand(),
            ],
          ),
          const Spacer(),
          FittedBox(child: Text(activity.distanceKm.toStringAsFixed(2), style: _display(150).copyWith(height: 0.9))),
          Text('KILOMETERS', style: _caps(14, color: AppColors.navy).copyWith(letterSpacing: 6)),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${formatDuration(activity.duration)}  ·  ${formatPace(activity.pace)}/km  ·  ${activity.elevationGainM} m',
              style: _display(20, color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      color: AppColors.paper,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _display(26, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatActivityDate(activity.startedAt)} · ${activity.location}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          Expanded(
            child: CustomPaint(
              painter: _ShareRoutePainter(points: activity.route, grid: false, line: AppColors.ink, casing: null),
              size: Size.infinite,
            ),
          ),
          const Divider(color: AppColors.line, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _stack(
                'DISTANCE',
                formatDistance(activity.distanceKm),
                color: AppColors.ink,
                muted: AppColors.muted,
                size: 22,
              ),
              _stack('TIME', formatDuration(activity.duration), color: AppColors.ink, muted: AppColors.muted, size: 22),
              _stack('PACE', formatPace(activity.pace), color: AppColors.ink, muted: AppColors.muted, size: 22),
            ].map((w) => Flexible(child: w)).toList(),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 450,
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: _ShareRoutePainter(points: activity.route, grid: false, casing: null),
                size: Size.infinite,
              ),
            ),
          ),
          Container(
            color: AppColors.orange,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _display(28)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${formatDistance(activity.distanceKm)}  /  ${formatDuration(activity.duration)}',
                          style: _display(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _brand(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', color: AppColors.ink, fontSize: 13, height: 1.5);
    Widget line(String k, String v) => Row(
      children: [
        Text(k, style: mono),
        const Spacer(),
        Text(v, style: mono),
      ],
    );
    const dash = Text('- - - - - - - - - - - - - - - - - - -', style: mono, maxLines: 1, overflow: TextOverflow.clip);

    return Container(
      width: 360,
      height: 450,
      color: const Color(0xFFFFFDF7),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Text('NUBI SPORT', style: mono.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(formatActivityDate(activity.startedAt), style: mono.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          dash,
          line('ACTIVITY', activityLabel(activity.type).toUpperCase()),
          line('DISTANCE', formatDistance(activity.distanceKm)),
          line('TIME', formatDuration(activity.duration)),
          line('PACE', '${formatPace(activity.pace)}/km'),
          line('ELEV', '${activity.elevationGainM} m'),
          dash,
          line('ATHLETE', activity.userName.toUpperCase()),
          dash,
          const Spacer(),
          Text('THANKS FOR RUNNING', style: mono.copyWith(fontSize: 11)),
          Text('#NubiSport', style: mono.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    final a = Paint()..color = const Color(0xFF3A3F47);
    final b = Paint()..color = const Color(0xFF2A2E35);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), ((x + y) / cell).round().isEven ? a : b);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
