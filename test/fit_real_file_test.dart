import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/data/fit_records.dart';
import 'package:nubisport_flutter/features/activities/data/repositories/api_activity_repository.dart';

void main() {
  // test/fixtures/walk.fit: written by Garmin's FIT SDK (@garmin/fitsdk Encoder) - 600 records,
  // enhanced altitude/speed, HR, every 7th record without distance (as some phone apps do).
  test(
    'decodes a FIT file written by the Garmin SDK, and it feeds the charts',
    () {
      final columns = fitRecordColumns(
        File('test/fixtures/walk.fit').readAsBytesSync(),
      )!;
      expect(columns['timestamp'], hasLength(600));
      expect(
        columns['timestamp']!.first,
        DateTime.utc(2026, 10, 28, 10, 22).millisecondsSinceEpoch,
      );
      expect(columns['positionLat']!.first, 37700268);
      expect(columns['enhancedAltitude']!.first, closeTo(60, 0.2));
      expect(columns['enhancedSpeed']![7], closeTo(1.6, 0.001));
      expect(columns['heartRate']![7], 117);
      expect(columns['distance']![0], isNull);
      expect(columns['distance']![1], closeTo(3.9, 0.01));

      final track = parseRecords(columns);
      expect(track.route.length, greaterThan(100));
      expect(track.samples.length, greaterThan(100));
      expect(
        track.samples.where((s) => s.altitudeM != null).length,
        greaterThan(1),
      );
      expect(
        track.samples.where((s) => (s.speedMs ?? 0) > 0.5).length,
        greaterThan(1),
      );
      expect(track.splits, hasLength(2)); // 600 x 3.9 m = 2.3 km
    },
  );
}
