import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/activity.dart';
import 'activity_map.dart' show MapCreditButton;
import 'route_draw.dart';

/// Native MapLibre map for the activity detail page: angled 3D camera, the
/// Liberty style's 3D buildings, and a GeoJSON route that draws itself.
class ActivityMap3D extends StatefulWidget {
  const ActivityMap3D({
    super.key,
    required this.activity,
    required this.height,
    this.animateRoute = true,
    this.controlsBottomInset = 8,
    this.focusTrigger = 0,
    this.focusPadding = const EdgeInsets.all(48),
    this.initialFocusPadding,
    this.introDelay = const Duration(milliseconds: 400),
    this.tilted = true,
  });

  final Activity activity;
  final double height;
  final bool animateRoute;
  final double controlsBottomInset;
  final int focusTrigger;
  final EdgeInsets focusPadding;
  final EdgeInsets? initialFocusPadding;
  final Duration introDelay;

  /// 3D (45° tilt) when true, flat top-down 2D when false. Changing it animates the camera.
  final bool tilted;

  @override
  State<ActivityMap3D> createState() => _ActivityMap3DState();
}

class _ActivityMap3DState extends State<ActivityMap3D>
    with SingleTickerProviderStateMixin {
  static const _routeSource = 'nubi-route';
  static const _routeCasingLayer = 'nubi-route-casing';
  static const _routeLayer = 'nubi-route-line';
  static const _startSource = 'nubi-start';
  static const _startLayer = 'nubi-start-circle';
  static const _endSource = 'nubi-end';
  static const _endLayer = 'nubi-end-circle';
  static const _tipSource = 'nubi-tip';
  static const _tipLayer = 'nubi-tip-circle';
  static const _arrowSource = 'nubi-arrows';
  static const _arrowLayer = 'nubi-arrow-symbols';
  static const _arrowImage = 'nubi-arrow';
  static const _arrowCount = 5;

  late final AnimationController _routeController;
  Timer? _introTimer;
  MapLibreMapController? _map;
  bool _styleReady = false;
  bool _drawing = false;
  int _arrowsShown = -1;

  /// Built once: per-frame work must not grow with the route's length.
  late final List<LatLng> _route = [
    for (final p in widget.activity.route) LatLng(p.latitude, p.longitude),
  ];

  /// Mercator distance from the start to each point, matching MapLibre's line-progress, so
  /// the moving tip sits exactly at the end of the drawn line.
  late final List<double> _cumulative = () {
    var total = 0.0;
    final out = <double>[];
    for (var i = 0; i < _route.length; i++) {
      if (i > 0) {
        final a = mercator(_route[i - 1].latitude, _route[i - 1].longitude);
        final b = mercator(_route[i].latitude, _route[i].longitude);
        total += math.sqrt(
          (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y),
        );
      }
      out.add(total);
    }
    return out;
  }();

  late final List<({LatLng point, double bearing, double at})> _arrows = [
    for (var i = 1; i <= _arrowCount; i++)
      if ((
            _pointAt(i / (_arrowCount + 1)),
            _pointAt(i / (_arrowCount + 1) + 0.01),
          )
          case (final a, final b) when a != b)
        (point: a, bearing: _bearing(a, b), at: i / (_arrowCount + 1)),
  ];
  bool get _hasRoute => _route.length > 1;
  bool get _animate => widget.animateRoute && _hasRoute;

  LatLng get _center =>
      LatLng(widget.activity.latitude, widget.activity.longitude);

  @override
  void initState() {
    super.initState();
    _routeController = AnimationController(
      vsync: this,
      // Same on-screen speed for every route, and the same as the 2D map.
      duration: routeDrawDuration(widget.activity.route),
      value: _animate ? 0 : 1,
    )..addListener(_onRouteTick);
  }

  @override
  void didUpdateWidget(covariant ActivityMap3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTrigger != oldWidget.focusTrigger) {
      unawaited(_fitRoute());
    }
    if (widget.tilted != oldWidget.tilted) {
      unawaited(_applyTilt());
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _routeController
      ..removeListener(_onRouteTick)
      ..dispose();
    super.dispose();
  }

  double get _progress =>
      Curves.easeInOutSine.transform(_routeController.value);

  // One draw in flight at a time, always the latest progress: as smooth as the platform
  // channel allows, without queueing stale frames.
  void _onRouteTick() {
    if (_drawing) return;
    _drawing = true;
    unawaited(_drawLatest());
  }

  Future<void> _drawLatest() async {
    double drawn;
    do {
      drawn = _progress;
      await _drawRoute(drawn);
    } while (mounted && drawn != _progress);
    _drawing = false;
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;
    final map = _map;
    if (map == null || _styleReady) return;
    _styleReady = true;
    final start = _route.isNotEmpty ? _route.first : _center;
    final end = _route.length > 1 ? _route.last : _center;

    // The whole line goes to the map once; drawing only moves a gradient cut-off along it, so
    // each frame costs the same however long the route is.
    await map.addSource(
      _routeSource,
      GeojsonSourceProperties(data: _lineJson(_route), lineMetrics: true),
    );
    await map.addLineLayer(
      _routeSource,
      _routeCasingLayer,
      LineLayerProperties(
        lineGradient: _reveal('#FFFFFF', _progress),
        lineWidth: 8.5,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await map.addLineLayer(
      _routeSource,
      _routeLayer,
      LineLayerProperties(
        lineGradient: _reveal(_hex(AppColors.orange), _progress),
        lineWidth: 5.5,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    // Same orange arrows as the 2D map, revealed as the line passes them.
    await map.addImage(_arrowImage, await _arrowPng());
    await map.addGeoJsonSource(_arrowSource, _arrowJson(const []));
    await map.addSymbolLayer(
      _arrowSource,
      _arrowLayer,
      const SymbolLayerProperties(
        iconImage: _arrowImage,
        iconSize: 1 / 3,
        iconRotate: [Expressions.get, 'bearing'],
        iconRotationAlignment: 'map',
        iconPitchAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
    await map.addGeoJsonSource(_startSource, _pointJson(start));
    await map.addCircleLayer(
      _startSource,
      _startLayer,
      const CircleLayerProperties(
        circleColor: '#2EB82E',
        circleRadius: 6,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
    await map.addGeoJsonSource(_endSource, _pointJson(end));
    await map.addCircleLayer(
      _endSource,
      _endLayer,
      const CircleLayerProperties(
        circleColor: '#0A1A33',
        circleRadius: 6,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
    await map.addGeoJsonSource(_tipSource, _pointJson(start));
    await map.addCircleLayer(
      _tipSource,
      _tipLayer,
      CircleLayerProperties(
        circleColor: _hex(AppColors.orange),
        circleRadius: 7,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );

    unawaited(_drawRoute(_progress));
    // Intro: fly from the wide flat view down into the tilted fit, then draw the line once
    // the camera has settled.
    await _fitRoute(initial: true);
    if (!mounted) return;

    if (_animate) {
      _introTimer = Timer(widget.introDelay, () {
        if (mounted) _routeController.forward();
      });
    }
  }

  /// [color] up to [t] of the line, transparent after it.
  static List<Object> _reveal(String color, double t) => [
    'step',
    ['line-progress'],
    color,
    t >= 1 ? 1.01 : t,
    'rgba(0,0,0,0)',
  ];

  Future<void> _drawRoute(double t) async {
    final map = _map;
    if (map == null || !_styleReady) return;
    try {
      await map.setLayerProperties(
        _routeCasingLayer,
        LineLayerProperties(lineGradient: _reveal('#FFFFFF', t)),
      );
      await map.setLayerProperties(
        _routeLayer,
        LineLayerProperties(lineGradient: _reveal(_hex(AppColors.orange), t)),
      );
      await map.setGeoJsonSource(
        _tipSource,
        _pointJson(_hasRoute ? _pointAt(t) : _center),
      );
      // Arrows only change when the line passes one.
      final shown = _arrows.where((a) => a.at <= t).length;
      if (shown != _arrowsShown) {
        _arrowsShown = shown;
        await map.setGeoJsonSource(
          _arrowSource,
          _arrowJson(_arrows.take(shown).toList()),
        );
      }
    } catch (_) {
      // Style not ready yet, or the map is being disposed.
    }
  }

  /// The point [t] (0..1) of the way along the route, by binary search.
  LatLng _pointAt(double t) {
    final route = _route;
    if (route.length < 2 || t <= 0) {
      return route.isEmpty ? _center : route.first;
    }
    final total = _cumulative.last;
    if (t >= 1 || total <= 0) return route.last;
    final target = total * t;
    var lo = 1, hi = route.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulative[mid] < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final span = _cumulative[lo] - _cumulative[lo - 1];
    final f = span == 0 ? 0.0 : (target - _cumulative[lo - 1]) / span;
    final a = route[lo - 1], b = route[lo];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * f,
      a.longitude + (b.longitude - a.longitude) * f,
    );
  }

  /// One camera move that frames the route inside [padding] with the tilt already applied.
  /// newLatLngBounds can't take a tilt, and tilting afterwards both jerks and pushes the route
  /// off screen, so the fit is worked out here (Web Mercator, 512 px tiles like MapLibre).
  Future<void> _fitRoute({bool initial = false}) async {
    final map = _map;
    final size = context.size;
    if (map == null || !_styleReady || size == null) return;
    final route = _route;
    if (route.isEmpty) return;
    final padding = initial
        ? (widget.initialFocusPadding ?? widget.focusPadding)
        : widget.focusPadding;
    final camera = fitCamera(_bounds(route), size, padding, tilt: _tilt);
    if (camera == null) return;
    try {
      await map.animateCamera(
        CameraUpdate.newCameraPosition(camera),
        duration: Duration(milliseconds: initial ? 1800 : 850),
      );
    } catch (_) {}
  }

  double get _tilt => widget.tilted ? 45 : 0;

  Future<void> _applyTilt() async {
    final map = _map;
    final pos = map?.cameraPosition;
    if (map == null || pos == null) return;
    try {
      await map.animateCamera(
        CameraUpdate.newCameraPosition(
          // Flat mode also faces north, like a classic 2D map.
          CameraPosition(
            target: pos.target,
            zoom: pos.zoom,
            bearing: widget.tilted ? pos.bearing : 0,
            tilt: _tilt,
          ),
        ),
        duration: const Duration(milliseconds: 500),
      );
    } catch (_) {}
  }

  void _replay() {
    _introTimer?.cancel();
    unawaited(_fitRoute());
    _routeController.forward(from: 0);
  }

  static LatLng _midpoint(LatLngBounds b) => LatLng(
    (b.southwest.latitude + b.northeast.latitude) / 2,
    (b.southwest.longitude + b.northeast.longitude) / 2,
  );

  static LatLngBounds _bounds(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static Map<String, dynamic> _lineJson(List<LatLng> points) => {
    'type': 'FeatureCollection',
    'features': points.length < 2
        ? const <Map<String, dynamic>>[]
        : [
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final p in points) [p.longitude, p.latitude],
                ],
              },
            },
          ],
  };

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x) * 180 / math.pi;
  }

  /// [Icons.navigation] rendered at 3x (54px) so it matches the 2D map's 18px arrow at iconSize 1/3.
  static Future<Uint8List> _arrowPng() async {
    const px = 54.0;
    final recorder = ui.PictureRecorder();
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.navigation.codePoint),
        style: TextStyle(
          fontSize: px,
          fontFamily: Icons.navigation.fontFamily,
          color: AppColors.orange,
        ),
      ),
    )..layout();
    painter.paint(Canvas(recorder), Offset.zero);
    final image = await recorder.endRecording().toImage(px.toInt(), px.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static Map<String, dynamic> _arrowJson(
    List<({LatLng point, double bearing, double at})> arrows,
  ) => {
    'type': 'FeatureCollection',
    'features': [
      for (final a in arrows)
        {
          'type': 'Feature',
          'properties': {'bearing': a.bearing},
          'geometry': {
            'type': 'Point',
            'coordinates': [a.point.longitude, a.point.latitude],
          },
        },
    ],
  };

  static Map<String, dynamic> _pointJson(LatLng point) => {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'Point',
          'coordinates': [point.longitude, point.latitude],
        },
      },
    ],
  };

  static String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Liberty: detailed, coloured OpenFreeMap style with built-in 3D buildings (`building-3d`).
    const style = 'https://tiles.openfreemap.org/styles/liberty';

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              styleString: style,
              // Wide and flat: the intro flies down into the tilted route fit.
              initialCameraPosition: CameraPosition(
                target: _hasRoute ? _midpoint(_bounds(_route)) : _center,
                zoom: 11.5,
              ),
              onMapCreated: (controller) => _map = controller,
              onStyleLoadedCallback: _onStyleLoaded,
              trackCameraPosition: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              doubleClickZoomEnabled: true,
              compassEnabled: false,
              logoEnabled: false,
              // The native credit sits under the sheet; MapCreditButton below shows it above the sheet.
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonMargins: const math.Point(-200, -200),
              foregroundLoadColor: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
          MapCreditButton(bottomInset: widget.controlsBottomInset),
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
    );
  }
}

/// Camera that frames [bounds] inside [size] minus [padding] (Web Mercator, 512 px tiles), or
/// null when the padding leaves no room. Tilted views zoom out a little so the far end still fits.
CameraPosition? fitCamera(
  LatLngBounds bounds,
  Size size,
  EdgeInsets padding, {
  double tilt = 0,
}) {
  final w = size.width - padding.horizontal;
  final h = size.height - padding.vertical;
  if (w <= 0 || h <= 0) return null;
  double x(double lng) => (lng + 180) / 360;
  double y(double lat) {
    final sin = math.sin(lat * math.pi / 180);
    return 0.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi);
  }

  const tile = 512.0;
  final x1 = x(bounds.southwest.longitude), x2 = x(bounds.northeast.longitude);
  final y1 = y(bounds.northeast.latitude), y2 = y(bounds.southwest.latitude);
  final spanX = math.max((x2 - x1) * tile, 1e-9),
      spanY = math.max((y2 - y1) * tile, 1e-9);
  // Capped so a tiny route (or a treadmill dot) doesn't zoom into a single building.
  final zoom =
      math.min(math.log(math.min(w / spanX, h / spanY)) / math.ln2, 17.0) -
      (tilt > 0 ? 0.35 : 0);
  // Shift the camera so the route centres in the padded box, not the whole screen.
  final scale = tile * math.pow(2, zoom);
  final cx = (x1 + x2) / 2 - (padding.left - padding.right) / 2 / scale;
  final cy = (y1 + y2) / 2 - (padding.top - padding.bottom) / 2 / scale;
  final lat =
      math.atan(
        (math.exp(math.pi * (1 - 2 * cy)) - math.exp(-math.pi * (1 - 2 * cy))) /
            2,
      ) *
      180 /
      math.pi;
  return CameraPosition(
    target: LatLng(lat, cx * 360 - 180),
    zoom: zoom,
    tilt: tilt,
  );
}
