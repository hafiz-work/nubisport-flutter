import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_map_3d.dart';

void main() {
  final bounds = LatLngBounds(southwest: const LatLng(3.15, 101.64), northeast: const LatLng(3.17, 101.66));
  const size = Size(390, 844);

  test('even padding centres the route', () {
    final camera = fitCamera(bounds, size, const EdgeInsets.all(48))!;
    expect(camera.target.latitude, closeTo(3.16, 1e-6));
    expect(camera.target.longitude, closeTo(101.65, 1e-6));
    expect(camera.zoom, inInclusiveRange(13, 16));
  });

  test('a tall sheet at the bottom moves the camera south so the route sits above it', () {
    final even = fitCamera(bounds, size, const EdgeInsets.all(48))!;
    final sheet = fitCamera(bounds, size, const EdgeInsets.fromLTRB(48, 110, 48, 460))!;
    expect(sheet.target.latitude, lessThan(3.16));
    expect(sheet.zoom, lessThan(even.zoom));
  });

  test('tilt zooms out a little; no room returns null; tiny routes are capped', () {
    final flat = fitCamera(bounds, size, const EdgeInsets.all(48))!;
    final tilted = fitCamera(bounds, size, const EdgeInsets.all(48), tilt: 45)!;
    expect(tilted.zoom, closeTo(flat.zoom - 0.35, 1e-9));
    expect(tilted.tilt, 45);
    expect(fitCamera(bounds, size, const EdgeInsets.fromLTRB(0, 500, 0, 500)), isNull);
    final dot = LatLngBounds(southwest: const LatLng(3.16, 101.65), northeast: const LatLng(3.16, 101.65));
    expect(fitCamera(dot, size, const EdgeInsets.all(48))!.zoom, 17);
  });
}
