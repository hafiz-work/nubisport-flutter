import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../../domain/models/activity.dart';
import '../activity_format.dart';
import 'route_draw.dart';

/// Map for an activity. List previews use free OSM raster tiles; the detail map
/// ([useVector]) draws an OpenFreeMap vector style instead, so labels stay
/// upright when the map is rotated.
///
/// When [animateRoute] is true the route is drawn like Strava's replay: the
/// camera fits the whole track, then after [introDelay] the line grows from the
/// start point to the end point with a moving dot.
class ActivityMap extends StatefulWidget {
  const ActivityMap({
    super.key,
    required this.activity,
    this.height = 140,
    this.interactive = false,
    this.animateRoute = false,
    this.introDelay = const Duration(milliseconds: 400),
    this.borderRadius,
    this.controlsBottomInset = 8,
    this.focusTrigger = 0,
    this.focusPadding = const EdgeInsets.all(48),
    this.initialFocusPadding,
    this.useVector = false,
    this.onTap,
    this.replayButton = false,
  });

  final Activity activity;
  final double height;
  final bool interactive;
  final bool animateRoute;
  final Duration introDelay;

  /// Defaults to [AppTheme.radius] (10). Pass [BorderRadius.zero] for a
  /// full-bleed map.
  final BorderRadius? borderRadius;

  /// Distance from the map's bottom edge for the credit "i" and replay button.
  /// Detail pages raise this above a draggable bottom sheet.
  final double controlsBottomInset;

  /// Increment this to smoothly fit the camera to the recorded route
  /// (Strava-style focus when the detail sheet snaps between sizes).
  final int focusTrigger;
  final EdgeInsets focusPadding;

  /// Padding used for the very first camera fit (e.g. to leave room for the
  /// detail sheet at its initial height). Falls back to a small uniform pad.
  final EdgeInsets? initialFocusPadding;

  /// Draw an OpenFreeMap vector style instead of OSM raster tiles.
  final bool useVector;

  /// Tap anywhere on a preview (except the replay button), e.g. to open the activity.
  final VoidCallback? onTap;

  /// Small Strava-style play at bottom-left of a preview: the route shows complete, a tap
  /// draws it again from the start.
  final bool replayButton;

  @override
  State<ActivityMap> createState() => _ActivityMapState();
}

class _ActivityMapState extends State<ActivityMap>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // Static list previews are costly to rebuild (map + tiles), so keep them alive while scrolling.
  // shortcut: keeps every seen preview in memory, add a cap when the feed paginates.
  @override
  bool get wantKeepAlive => !widget.interactive;

  static const _distance = Distance();
  // Shared by the line and its direction arrows so they always match.
  static const _routeColor = AppColors.orange;

  late final AnimationController _controller;
  late final AnimationController _cameraController;
  final MapController _mapController = MapController();
  Timer? _startTimer;

  MapCamera? _cameraFrom;
  MapCamera? _cameraTo;

  vt.Style? _vectorStyle;
  Brightness? _styleBrightness;
  bool _styleLoading = false;
  int _styleToken = 0;

  late List<LatLng> _routePoints;

  /// Distance from the start to each route point, so per-frame drawing is a binary search.
  List<double> _cumulative = const [];
  ({double t, List<LatLng> points, LatLng? tip})? _lastPartial;
  List<({LatLng point, double bearing, double at})> _arrowPoints = const [];

  List<LatLng> get _route => _routePoints;

  bool get _hasRoute => _routePoints.length > 1;
  bool get _animate => widget.animateRoute && _hasRoute;

  void _setRoute() {
    _routePoints = [
      for (final point in widget.activity.route)
        LatLng(point.latitude, point.longitude),
    ];
    var total = 0.0;
    _cumulative = [
      for (var i = 0; i < _routePoints.length; i++)
        total += i == 0
            ? 0
            : _distance.as(
                LengthUnit.Meter,
                _routePoints[i - 1],
                _routePoints[i],
              ),
    ];
    _lastPartial = null;
  }

  /// Eased progress of the intro line, shared by the line and marker layers.
  double get _progress => Curves.easeInOutSine.transform(_controller.value);

  void _scheduleIntro({Duration? delay}) {
    if (!_animate || _controller.value > 0 || _controller.isAnimating) return;
    _startTimer?.cancel();
    _startTimer = Timer(delay ?? widget.introDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void initState() {
    super.initState();
    _setRoute();
    _controller = AnimationController(
      vsync: this,
      // Same on-screen speed for every route, and the same as the 3D map.
      duration: routeDrawDuration(widget.activity.route),
      value: _animate ? 0 : 1,
    );
    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(_onCameraTick);
    // Vector maps wait for their style: swapping the base layer mid-draw drops frames.
    // Fallback in case the style request hangs.
    _scheduleIntro(delay: widget.useVector ? const Duration(seconds: 3) : null);
    _arrowPoints = _hasRoute
        ? _arrows(count: widget.interactive ? 5 : 3)
        : const [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.useVector) return;
    final brightness = Theme.of(context).brightness;
    if (_styleBrightness == brightness &&
        (_vectorStyle != null || _styleLoading)) {
      return;
    }
    _styleBrightness = brightness;
    _styleLoading = true;
    _loadVectorStyle(brightness);
  }

  Future<void> _loadVectorStyle(Brightness brightness) async {
    final token = ++_styleToken;
    // Same Liberty style as the 3D map; building extrusions render flat here.
    const uri = 'https://tiles.openfreemap.org/styles/liberty';
    try {
      final style = await vt.StyleReader(uri: uri, language: 'ms').read();
      if (!mounted || token != _styleToken) {
        style.dispose();
        return;
      }
      final previous = _vectorStyle;
      setState(() {
        _vectorStyle = style;
        _styleLoading = false;
      });
      _scheduleIntro();
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    } catch (_) {
      if (mounted && token == _styleToken) {
        setState(() => _styleLoading = false);
        _scheduleIntro();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ActivityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activity.id != oldWidget.activity.id ||
        widget.activity.route.length != oldWidget.activity.route.length ||
        widget.interactive != oldWidget.interactive) {
      _setRoute();
      _controller.duration = routeDrawDuration(widget.activity.route);
      _arrowPoints = _hasRoute
          ? _arrows(count: widget.interactive ? 5 : 3)
          : const [];
    }
    if (widget.focusTrigger != oldWidget.focusTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitRoute();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _styleToken++;
    _vectorStyle?.dispose();
    _cameraController
      ..removeListener(_onCameraTick)
      ..dispose();
    _controller.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Smoothly animates the camera to fit the recorded route.
  void _fitRoute() {
    final route = _route;
    if (route.length <= 1) {
      if (route.isNotEmpty) _mapController.move(route.first, 15);
      return;
    }
    final from = _mapController.camera;
    final target = CameraFit.coordinates(
      coordinates: route,
      padding: widget.focusPadding,
      maxZoom: 16,
    ).fit(from);
    _cameraFrom = from;
    _cameraTo = target;
    _cameraController.forward(from: 0);
  }

  void _onCameraTick() {
    final from = _cameraFrom;
    final to = _cameraTo;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_cameraController.value);
    _mapController.move(
      LatLng(
        from.center.latitude + (to.center.latitude - from.center.latitude) * t,
        from.center.longitude +
            (to.center.longitude - from.center.longitude) * t,
      ),
      from.zoom + (to.zoom - from.zoom) * t,
    );
  }

  /// Restarts the intro drawing from the start point, keeping the same map,
  /// camera and markers - no rebuild, no extra delay.
  void _replay() {
    _startTimer?.cancel();
    _startTimer = null;
    _controller.forward(from: 0);
  }

  /// The part of the route visible at [t] (0..1), plus the moving tip.
  ({List<LatLng> points, LatLng? tip}) _partialRoute(double t) {
    final cached = _lastPartial;
    if (cached != null && cached.t == t) {
      return (points: cached.points, tip: cached.tip);
    }
    final result = _computePartial(t);
    _lastPartial = (t: t, points: result.points, tip: result.tip);
    return result;
  }

  ({List<LatLng> points, LatLng? tip}) _computePartial(double t) {
    final route = _route;
    if (route.isEmpty) return (points: const <LatLng>[], tip: null);
    if (route.length == 1 || t >= 1) return (points: route, tip: route.last);
    if (t <= 0) return (points: [route.first], tip: route.first);

    final total = _cumulative.last;
    if (total <= 0) return (points: route, tip: route.last);
    final target = total * t;

    // First index whose cumulative distance passes the target.
    var lo = 1, hi = route.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulative[mid] < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final start = route[lo - 1];
    final end = route[lo];
    final length = _cumulative[lo] - _cumulative[lo - 1];
    final fraction = length == 0
        ? 0.0
        : (target - _cumulative[lo - 1]) / length;
    final tip = LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
    return (points: [...route.sublist(0, lo), tip], tip: tip);
  }

  /// Evenly spaced points along the route with their heading, for direction arrows.
  List<({LatLng point, double bearing, double at})> _arrows({int count = 5}) =>
      [
        for (var i = 1; i <= count; i++)
          if ((
                _partialRoute(i / (count + 1)).tip,
                _partialRoute(i / (count + 1) + 0.01).tip,
              )
              case (final a?, final b?) when a != b)
            (point: a, bearing: _distance.bearing(a, b), at: i / (count + 1)),
      ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final activity = widget.activity;
    final route = _route;
    final center = LatLng(activity.latitude, activity.longitude);
    // Raster fallback while the vector style loads (and for list previews).
    // Esri Gray Canvas (keyless) following the theme, with its road/place-name layer on top,
    // so feed tiles read like Strava's (dark map in dark mode) while the route still stands out.
    final canvas = theme.brightness == Brightness.dark
        ? 'World_Dark_Gray'
        : 'World_Light_Gray';
    String esri(String layer) =>
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/$layer/MapServer/tile/{z}/{y}/{x}';
    final arrows = _arrowPoints;

    return ClipRRect(
      borderRadius:
          widget.borderRadius ?? BorderRadius.circular(AppTheme.radius),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            initialCameraFit: route.length > 1
                ? CameraFit.coordinates(
                    coordinates: route,
                    padding:
                        widget.initialFocusPadding ?? const EdgeInsets.all(20),
                    maxZoom: 16,
                  )
                : null,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            interactionOptions: InteractionOptions(
              // Vector labels are drawn in screen space, so rotation keeps
              // them upright. List previews stay fixed.
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            if (widget.useVector && _vectorStyle != null)
              vt.VectorTileLayer(
                theme: _vectorStyle!.theme,
                tileProviders: _vectorStyle!.providers,
                rasterSources: _vectorStyle!.rasterSources,
                sprites: _vectorStyle!.sprites,
                labelMode: vt.LabelMode.screen,
              )
            else
              TileLayer(
                urlTemplate: esri('${canvas}_Base'),
                userAgentPackageName: 'com.hafizbahtiar.nubisport',
                maxZoom: 19,
                maxNativeZoom: 16,
              ),
            if (!(widget.useVector && _vectorStyle != null))
              TileLayer(
                urlTemplate: esri('${canvas}_Reference'),
                userAgentPackageName: 'com.hafizbahtiar.nubisport',
                maxZoom: 19,
                maxNativeZoom: 16,
              ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final partial = _partialRoute(_progress);
                if (partial.points.length < 2) return const SizedBox.shrink();
                // Own layer so each frame repaints only the line, not the vector tiles underneath.
                return RepaintBoundary(
                  child: PolylineLayer(
                    polylines: [
                      Polyline(
                        points: partial.points,
                        strokeWidth: 5.5,
                        color: _routeColor,
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final partial = _partialRoute(_progress);
                final markers = <Marker>[];
                if (_hasRoute) {
                  // Direction arrows appear once the growing line has passed them.
                  for (final arrow in arrows) {
                    if (arrow.at <= _progress) {
                      markers.add(
                        _marker(
                          arrow.point,
                          Transform.rotate(
                            angle: arrow.bearing * math.pi / 180,
                            child: const Icon(
                              Icons.navigation,
                              size: 18,
                              color: _routeColor,
                            ),
                          ),
                          size: 18,
                        ),
                      );
                    }
                  }
                  markers.add(
                    // Strava-style green start dot.
                    _marker(
                      route.first,
                      const _RouteDot(
                        color: Color(0xFF2EB82E),
                        border: Colors.white,
                      ),
                      size: 18,
                    ),
                  );
                  if (_controller.value < 1 && partial.tip != null) {
                    markers.add(
                      _marker(
                        partial.tip!,
                        _RouteDot(
                          color: AppColors.orange,
                          border: Colors.white,
                          icon: activityIcon(activity.type),
                        ),
                      ),
                    );
                  }
                  markers.add(
                    _marker(route.last, const _FinishDot(), size: 22),
                  );
                } else {
                  markers.add(
                    _marker(
                      center,
                      _RouteDot(
                        color: AppColors.orange,
                        border: Colors.white,
                        icon: activityIcon(activity.type),
                      ),
                    ),
                  );
                }
                return RepaintBoundary(child: MarkerLayer(markers: markers));
              },
            ),
            // Credit "i" on interactive maps only; feed previews stay clean like Strava's.
            if (widget.interactive)
              MapCreditButton(bottomInset: widget.controlsBottomInset),
            if (widget.onTap != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                ),
              ),
            if (widget.replayButton && _hasRoute)
              Positioned(
                left: 10,
                bottom: 10,
                child: _MiniReplayButton(onTap: _replay),
              ),
            if (_animate)
              Positioned(
                right: 12,
                bottom: widget.controlsBottomInset,
                child: Tooltip(
                  message: 'Replay animation',
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.94),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _replay,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _marker(LatLng point, Widget child, {double size = 30}) =>
      Marker(point: point, width: size, height: size, child: child);
}

/// Small dark play button over a map preview.
class _MiniReplayButton extends StatelessWidget {
  const _MiniReplayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Replay animation',
    child: Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.play_arrow_outlined, size: 22, color: Colors.white),
        ),
      ),
    ),
  );
}

/// The map credit "i" (OpenFreeMap / Esri / OSM) at bottom-left, raised by [bottomInset].
class MapCreditButton extends StatelessWidget {
  const MapCreditButton({super.key, required this.bottomInset});
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 8,
      bottom: bottomInset,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => FamilyModalSheet.show<void>(
            context: context,
            builder: (sheetContext) {
              final sheetTheme = Theme.of(sheetContext);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: sheetTheme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Map credit',
                            style: sheetTheme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Basemap: OpenFreeMap (vector) / Esri Light Gray (raster).',
                      style: sheetTheme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Map data © OpenStreetMap contributors (ODbL).',
                      style: sheetTheme.textTheme.bodySmall?.copyWith(
                        color: sheetTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          child: SizedBox(
            width: 22,
            height: 22,
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color, required this.border, this.icon});
  final Color color;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: icon == null ? null : Icon(icon, size: 15, color: Colors.white),
    );
  }
}

/// Strava-style finish marker: a black and white chequered circle with a white ring.
class _FinishDot extends StatelessWidget {
  const _FinishDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: ClipOval(
        child: CustomPaint(painter: _CheckerPainter(), size: Size.infinite),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  static const _cells = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _cells;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final black = Paint()..color = Colors.black;
    for (var row = 0; row < _cells; row++) {
      for (var col = 0; col < _cells; col++) {
        if ((row + col).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell, cell),
            black,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}
