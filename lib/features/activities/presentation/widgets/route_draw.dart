import 'dart:math' as math;

import '../../domain/models/activity.dart';

/// Web Mercator x/y in 0..1 - the space the camera fits and MapLibre's line-progress measures in.
({double x, double y}) mercator(double latitude, double longitude) {
  final sin = math.sin(latitude * math.pi / 180).clamp(-0.9999, 0.9999);
  return (
    x: (longitude + 180) / 360,
    y: 0.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi),
  );
}

/// How long the route takes to draw itself, so the line crosses the screen at the same speed
/// on every activity. The camera always fits the route's box, so what the eye sees is the path
/// length over the box size: a straight walk is ~1 box, an out-and-back ~2, a loop ~3-4.
Duration routeDrawDuration(List<GeoPoint> route) {
  if (route.length < 2) return const Duration(milliseconds: 2500);
  final points = [for (final p in route) mercator(p.latitude, p.longitude)];
  var path = 0.0;
  var minX = points.first.x, maxX = minX, minY = points.first.y, maxY = minY;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    path += math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
    minX = math.min(minX, b.x);
    maxX = math.max(maxX, b.x);
    minY = math.min(minY, b.y);
    maxY = math.max(maxY, b.y);
  }
  final box = math.max(maxX - minX, maxY - minY);
  if (box <= 0) return const Duration(milliseconds: 2500);
  // 1.6 s per box length; floor keeps a short line from snapping, cap keeps laps watchable.
  return Duration(milliseconds: (path / box * 1600).clamp(2500, 9000).round());
}
