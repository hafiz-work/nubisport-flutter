import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/route_draw.dart';

void main() {
  test('draw time follows how much screen the line covers, not distance', () {
    const straightShort = [GeoPoint(3.0, 101.0), GeoPoint(3.01, 101.0)];
    const straightLong = [GeoPoint(3.0, 101.0), GeoPoint(3.5, 101.0)];
    // Square loop: 4 sides inside a 1-side box.
    const loop = [
      GeoPoint(3.0, 101.0),
      GeoPoint(3.01, 101.0),
      GeoPoint(3.01, 101.01),
      GeoPoint(3.0, 101.01),
      GeoPoint(3.0, 101.0),
    ];
    // Same box, many laps.
    final laps = [for (var i = 0; i < 10; i++) ...loop];

    // A 1 km and a 55 km straight line look the same once fitted: same time.
    expect(routeDrawDuration(straightShort), routeDrawDuration(straightLong));
    expect(
      routeDrawDuration(straightShort),
      const Duration(milliseconds: 2500),
    );
    expect(routeDrawDuration(loop).inMilliseconds, closeTo(6400, 50));
    expect(routeDrawDuration(laps), const Duration(milliseconds: 9000));
    expect(
      routeDrawDuration(const [GeoPoint(3, 101)]),
      const Duration(milliseconds: 2500),
    );
  });
}
