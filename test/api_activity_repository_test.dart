import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/data/repositories/api_activity_repository.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/auth/domain/models/app_user.dart';

import 'support/fake_adapter.dart';

const _me = AppUser(
  id: 7,
  name: 'Aina',
  email: 'aina@example.com',
  role: 'user',
  apps: {},
);

ApiActivityRepository _repo(Map<String, (int, Object)> routes) =>
    ApiActivityRepository(Dio()..httpClientAdapter = FakeAdapter(routes));

void main() {
  const own = {
    'id': 12,
    'startedAt': '2026-10-21T13:12:07Z',
    'sport': 'run',
    'name': null,
    'distanceM': 5020,
    'movingS': 1721,
    'elevationGainM': 42,
  };

  test(
    'own activities map to the signed-in user, newest first, untitled ones get a default',
    () async {
      final items = await _repo({
        'GET /me/apps/nubi/activities': (
          200,
          {
            'success': true,
            'data': {
              'activities': [
                own,
                {
                  ...own,
                  'id': 13,
                  'startedAt': '2026-10-25T06:30:00Z',
                  'name': 'Subuh',
                  'sport': 'other',
                  'preview': [
                    [3.07, 101.51],
                    [3.08, 101.52],
                  ],
                  'kudos': 2,
                },
              ],
            },
          },
        ),
      }).myActivities(user: _me);

      // ?preview=1 rows: the map shape and kudos count for the profile cards.
      expect(items.first.route.length, 2);
      expect(items.first.latitude, 3.07);
      expect(items.first.kudos, 2);
      expect(items.last.route, isEmpty);
      expect(items.map((a) => a.id), ['13', '12']);
      expect(items.last.title, 'Run');
      expect(items.last.userName, 'Aina');
      expect(items.last.distanceKm, 5.02);
      expect(items.last.duration, const Duration(seconds: 1721));
      expect(items.first.type, ActivityType.other);
      expect(
        items.last.startedAt.isAtSameMomentAs(
          DateTime.utc(2026, 10, 21, 13, 12, 7),
        ),
        isTrue,
      );
    },
  );

  test(
    'rows without a preview get one from the own .fit, saved with their own sharing',
    () async {
      final adapter = FakeAdapter({
        'GET /me/apps/nubi/activities': (
          200,
          {
            'success': true,
            'data': {
              'activities': [
                {
                  ...own,
                  'visibility': 'private',
                  'shareHr': false,
                  'preview': null,
                },
              ],
            },
          },
        ),
        'GET /me/apps/nubi/activities/12/file': (
          200,
          File('test/fixtures/walk.fit').readAsBytesSync(),
        ),
        'PUT /me/apps/nubi/activities/12/visibility': (200, {'success': true}),
      });
      final items = await ApiActivityRepository(
        Dio()..httpClientAdapter = adapter,
      ).myActivities(user: _me);

      expect(items.single.route, hasLength(150));
      final saved =
          adapter.bodies['PUT /me/apps/nubi/activities/12/visibility'] as Map;
      expect(saved['visibility'], 'private');
      expect(saved['shareHr'], false);
      expect(saved['preview'], hasLength(150));
    },
  );

  test(
    'own shared activity charts come from our own .fit, not the copy (like the web)',
    () async {
      final a = (await _repo({
        'GET /me/apps/nubi/feed/12': (
          200,
          {
            'success': true,
            'data': {...own, 'own': true},
          },
        ),
        // A copy with nothing chartable must not win over the file.
        'GET /me/apps/nubi/feed/12/records': (
          200,
          {
            'timestamp': [0, 1000],
          },
        ),
        'GET /me/apps/nubi/activities/12/file': (
          200,
          File('test/fixtures/walk.fit').readAsBytesSync(),
        ),
      }).activity('12', viewer: _me))!;
      expect(
        a.samples.where((s) => s.altitudeM != null).length,
        greaterThan(100),
      );
      expect(a.chartsMissing, isNull);
    },
  );

  test(
    'a copy in another shape counts as none, with the reason kept',
    () async {
      final a = (await _repo({
        'GET /me/apps/nubi/feed/12': (200, {'success': true, 'data': own}),
        'GET /me/apps/nubi/feed/12/records': (
          200,
          {'success': true, 'data': {}},
        ),
      }).activity('12', viewer: _me))!;
      expect(a.samples, isEmpty);
      expect(a.chartsMissing, contains('no timestamp'));
    },
  );

  test('route preview: evenly spaced, ends kept, 5 decimals', () {
    final route = [
      for (var i = 0; i < 1000; i++) GeoPoint(3 + i * 0.0000123456, 101.5),
    ];
    final preview = routePreview(route);
    expect(preview, hasLength(150));
    expect(preview.first, [3.0, 101.5]);
    expect(preview.last.first, closeTo(3 + 999 * 0.0000123456, 0.000005));
    expect(routePreview(route.take(1).toList()), isEmpty);
  });

  test('feed items carry author, route preview and kudos', () async {
    final feed = await _repo({
      'GET /me/apps/nubi/feed': (
        200,
        {
          'success': true,
          'data': {
            'items': [
              {
                ...own,
                'author': {'name': 'Zul'},
                'preview': [
                  [3.07, 101.51],
                  [3.08, 101.52],
                ],
                'kudos': {'count': 3, 'mine': false},
                'own': false,
              },
            ],
            'next': null,
          },
        },
      ),
    }).feed(viewer: _me);

    expect(feed.single.userName, 'Zul');
    expect(feed.single.userId, 0);
    expect(feed.single.route.length, 2);
    expect(feed.single.latitude, 3.07);
    expect(feed.single.kudos, 3);
    expect(feed.single.kudosed, isFalse);
  });

  test('kudos returns the server count and state', () async {
    final result = await _repo({
      'POST /me/apps/nubi/feed/12/kudos': (
        200,
        {
          'success': true,
          'data': {'count': 4, 'mine': true},
        },
      ),
    }).setKudos('12', on: true);

    expect(result, (count: 4, mine: true));
  });

  test(
    'detail falls back to own activity when not in the feed, null when nowhere',
    () async {
      final repo = _repo({
        'GET /me/apps/nubi/activities/12': (
          200,
          {'success': true, 'data': own},
        ),
      });

      final detail = await repo.activity('12', viewer: _me);
      expect(detail?.id, '12');
      expect(detail?.userName, 'Aina');
      expect(detail?.route, isEmpty);
      expect(await repo.activity('99', viewer: _me), isNull);
      expect(await repo.activity('a1', viewer: _me), isNull);
    },
  );

  test(
    'shared detail reads records: full route, km splits, chart samples, weather',
    () async {
      const semi = 2147483648 / 180; // degrees -> semicircles
      final detail = await _repo({
        'GET /me/apps/nubi/feed/12': (
          200,
          {
            'success': true,
            'data': {
              ...own,
              'elapsedS': 1800,
              'avgHr': 150,
              'author': {'name': 'Aina'},
              'preview': [
                [3.0, 101.0],
              ],
              'kudos': {'count': 0, 'mine': false},
              'own': true,
              'weather': {'temperatureC': 29.2, 'humidityPct': 76},
            },
          },
        ),
        // Raw body, no envelope; one point per 500 m, 4 min/km.
        'GET /me/apps/nubi/feed/12/records': (
          200,
          {
            'timestamp': [0, 120000, 240000, 360000, 480000],
            'positionLat': [for (var i = 0; i < 5; i++) (3.0 + i / 100) * semi],
            'positionLong': [for (var i = 0; i < 5; i++) 101.5 * semi],
            'distance': [0, 500, 1000, 1500, 2000],
            'enhancedAltitude': [50, 52, null, 56, 58],
            'altitude': [0, 0, 54, 0, 0],
            'speed': [4.17, 4.17, 4.17, 4.17, 4.17],
          },
        ),
      }).activity('12', viewer: _me);

      expect(detail!.route.length, 5);
      expect(detail.route.last.latitude, closeTo(3.04, 1e-6));
      expect(detail.splits, [
        const Duration(minutes: 4),
        const Duration(minutes: 4),
      ]);
      expect(detail.samples.map((s) => s.altitudeM), [50, 52, 54, 56, 58]);
      expect(detail.samples.last.distanceM, 2000);
      expect(detail.elapsed, const Duration(seconds: 1800));
      expect(detail.avgHr, 150);
      expect(detail.weather?.temperatureC, 29.2);
    },
  );

  test(
    'records without distance (most of a Strava file) reuse the last one instead of being dropped',
    () {
      final parsed = parseRecords({
        'timestamp': [0, 1000, 2000, 3000],
        'distance': [0, null, null, 8],
        'heartRate': [null, 120, 121, null],
      });
      expect(parsed.samples.map((s) => s.distanceM), [0, 0, 0, 8]);
      expect(parsed.samples.where((s) => s.heartRate != null), hasLength(2));
    },
  );

  test('records thinned to chart buckets keep the distance end', () {
    final n = 3000;
    final parsed = parseRecords({
      'timestamp': [for (var i = 0; i < n; i++) i * 1000],
      'distance': [for (var i = 0; i < n; i++) i * 3.0],
      'speed': [for (var i = 0; i < n; i++) 3.0],
    });
    expect(parsed.samples.length, 300);
    expect(parsed.samples.last.distanceM, (n - 1) * 3.0);
    expect(parsed.samples.first.speedMs, 3.0);
    expect(parsed.splits.length, 8);
  });

  test(
    'server errors other than 403/404 are not hidden as "not found"',
    () async {
      final repo = _repo({
        'GET /me/apps/nubi/feed/12': (
          500,
          {'success': false, 'error': 'Feed unavailable'},
        ),
      });
      expect(repo.activity('12', viewer: _me), throwsA(isA<DioException>()));
    },
  );
}
