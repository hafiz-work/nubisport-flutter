import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/activity.dart';

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

class _ActivityMap3DState extends State<ActivityMap3D> with SingleTickerProviderStateMixin {
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

  List<LatLng> get _route => [for (final p in widget.activity.route) LatLng(p.latitude, p.longitude)];
  bool get _hasRoute => _route.length > 1;
  bool get _animate => widget.animateRoute && _hasRoute;

  LatLng get _center => LatLng(widget.activity.latitude, widget.activity.longitude);

  @override
  void initState() {
    super.initState();
    _routeController = AnimationController(
      vsync: this,
      // Same pace and easing as the 2D map (activity_map.dart).
      duration: const Duration(milliseconds: 4500),
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

  double get _progress => Curves.easeInOutSine.transform(_routeController.value);

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

    await map.addGeoJsonSource(_routeSource, _lineJson(const []));
    await map.addLineLayer(
      _routeSource,
      _routeCasingLayer,
      const LineLayerProperties(lineColor: '#FFFFFF', lineWidth: 8.5, lineJoin: 'round', lineCap: 'round'),
    );
    await map.addLineLayer(
      _routeSource,
      _routeLayer,
      LineLayerProperties(lineColor: _hex(AppColors.orange), lineWidth: 5.5, lineJoin: 'round', lineCap: 'round'),
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
    // Let the camera settle first, so the line is not drawn while the view is still moving.
    await _fitRoute(initial: true);
    if (!mounted) return;

    if (_animate) {
      _introTimer = Timer(widget.introDelay, () {
        if (mounted) _routeController.forward();
      });
    }
    await _fitRoute(initial: true);
  }

  Future<void> _drawRoute(double t) async {
    final map = _map;
    if (map == null || !_styleReady) return;
    final partial = _partialRoute(t);
    final tip = partial.tip ?? _center;
    try {
      await map.setGeoJsonSource(_routeSource, _lineJson(partial.points));
      await map.setGeoJsonSource(_tipSource, _pointJson(tip));
      await map.setGeoJsonSource(
        _arrowSource,
        _arrowJson([
          for (final a in _arrows)
            if (a.at <= t) a,
        ]),
      );
    } catch (_) {
      // Style not ready yet, or the map is being disposed.
    }
  }

  Future<void> _fitRoute({bool initial = false}) async {
    final map = _map;
    if (map == null || !_styleReady) return;
    final route = _route;
    if (route.isEmpty) return;
    final padding = initial ? (widget.initialFocusPadding ?? widget.focusPadding) : widget.focusPadding;
    final bounds = _bounds(route);
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
        duration: const Duration(milliseconds: 600),
      );
      // newLatLngBounds resets tilt; restore it and face north, undoing any user rotation.
      final pos = map.cameraPosition;
      if (pos != null) {
        await map.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: pos.target, zoom: pos.zoom, bearing: 0, tilt: _tilt)),
          duration: const Duration(milliseconds: 300),
        );
      }
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
          CameraPosition(target: pos.target, zoom: pos.zoom, bearing: widget.tilted ? pos.bearing : 0, tilt: _tilt),
        ),
        duration: const Duration(milliseconds: 500),
      );
    } catch (_) {}
  }

  void _replay() {
    _introTimer?.cancel();
    _routeController.forward(from: 0);
  }

  ({List<LatLng> points, LatLng? tip}) _partialRoute(double t) {
    final route = _route;
    if (route.isEmpty) return (points: const <LatLng>[], tip: null);
    if (route.length == 1 || t >= 1) return (points: route, tip: route.last);
    if (t <= 0) return (points: [route.first], tip: route.first);

    final lengths = <double>[];
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      final length = _meters(route[i - 1], route[i]);
      lengths.add(length);
      total += length;
    }
    if (total <= 0) return (points: route, tip: route.last);

    final target = total * t;
    final points = <LatLng>[route.first];
    var covered = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final length = lengths[i];
      if (covered + length <= target) {
        points.add(route[i + 1]);
        covered += length;
        continue;
      }
      final fraction = length == 0 ? 0.0 : (target - covered) / length;
      final a = route[i];
      final b = route[i + 1];
      points.add(
        LatLng(a.latitude + (b.latitude - a.latitude) * fraction, a.longitude + (b.longitude - a.longitude) * fraction),
      );
      break;
    }
    return (points: points, tip: points.last);
  }

  static double _meters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = dLng * math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);
    return earth * math.sqrt(dLat * dLat + x * x);
  }

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
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
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

  /// Evenly spaced points along the route with their heading, for direction arrows.
  List<({LatLng point, double bearing, double at})> get _arrows => [
    for (var i = 1; i <= _arrowCount; i++)
      if ((_partialRoute(i / (_arrowCount + 1)).tip, _partialRoute(i / (_arrowCount + 1) + 0.01).tip) case (
        final a?,
        final b?,
      ) when a != b)
        (point: a, bearing: _bearing(a, b), at: i / (_arrowCount + 1)),
  ];

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
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
        style: TextStyle(fontSize: px, fontFamily: Icons.navigation.fontFamily, color: AppColors.orange),
      ),
    )..layout();
    painter.paint(Canvas(recorder), Offset.zero);
    final image = await recorder.endRecording().toImage(px.toInt(), px.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static Map<String, dynamic> _arrowJson(List<({LatLng point, double bearing, double at})> arrows) => {
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
              initialCameraPosition: CameraPosition(target: _center, zoom: 14.2, tilt: _tilt),
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
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonColor: theme.colorScheme.onSurfaceVariant,
              foregroundLoadColor: theme.colorScheme.surfaceContainerHigh,
            ),
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
                      child: Icon(Icons.play_arrow_rounded, size: 28, color: theme.colorScheme.primary),
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
