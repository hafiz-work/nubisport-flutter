import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/data/repositories/api_activity_repository.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/auth/domain/models/app_user.dart';

/// Answers by path: (status, JSON body).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final Map<String, (int, Object)> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = routes[options.path] ?? (404, {'success': false, 'error': 'Not found'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _me = AppUser(id: 7, name: 'Aina', email: 'aina@example.com', role: 'user', apps: {});

ApiActivityRepository _repo(Map<String, (int, Object)> routes) =>
    ApiActivityRepository(Dio()..httpClientAdapter = _FakeAdapter(routes), currentUser: () => _me);

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

  test('own activities map to the signed-in user, newest first, untitled ones get a default', () async {
    final items = await _repo({
      '/me/apps/nubi/activities': (
        200,
        {
          'success': true,
          'data': {
            'activities': [
              own,
              {...own, 'id': 13, 'startedAt': '2026-10-25T06:30:00Z', 'name': 'Subuh', 'sport': 'other'},
            ],
          },
        },
      ),
    }).myActivities(userId: 7);

    expect(items.map((a) => a.id), ['13', '12']);
    expect(items.last.title, 'Run');
    expect(items.last.userName, 'Aina');
    expect(items.last.distanceKm, 5.02);
    expect(items.last.duration, const Duration(seconds: 1721));
    expect(items.first.type, ActivityType.other);
    expect(items.last.startedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 21, 13, 12, 7)), isTrue);
  });

  test('feed items carry author, route preview and kudos', () async {
    final feed = await _repo({
      '/me/apps/nubi/feed': (
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
    }).feed();

    expect(feed.single.userName, 'Zul');
    expect(feed.single.userId, 0);
    expect(feed.single.route.length, 2);
    expect(feed.single.latitude, 3.07);
    expect(feed.single.kudos, 3);
    expect(feed.single.kudosed, isFalse);
  });

  test('kudos returns the server count and state', () async {
    final result = await _repo({
      '/me/apps/nubi/feed/12/kudos': (
        200,
        {
          'success': true,
          'data': {'count': 4, 'mine': true},
        },
      ),
    }).setKudos('12', on: true);

    expect(result, (count: 4, mine: true));
  });

  test('detail falls back to own activity when not in the feed, null when nowhere', () async {
    final repo = _repo({
      '/me/apps/nubi/activities/12': (200, {'success': true, 'data': own}),
    });

    final detail = await repo.activity('12');
    expect(detail?.id, '12');
    expect(detail?.userName, 'Aina');
    expect(detail?.route, isEmpty);
    expect(await repo.activity('99'), isNull);
    expect(await repo.activity('a1'), isNull);
  });

  test('server errors other than 403/404 are not hidden as "not found"', () async {
    final repo = _repo({
      '/me/apps/nubi/feed/12': (500, {'success': false, 'error': 'Feed unavailable'}),
    });
    expect(repo.activity('12'), throwsA(isA<DioException>()));
  });
}
