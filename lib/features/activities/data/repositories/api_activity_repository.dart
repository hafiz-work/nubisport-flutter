import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../fit_records.dart';

/// hono-workers /me/apps/nubi/activities (own) and /me/apps/nubi/feed (members' shared runs).
///
/// The API has no place name, calories or notes. Route, splits and chart streams come from the
/// owner's shared records (/feed/:id/records), or for own activities from the original .fit.
class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<Activity>> myActivities({required AppUser user}) async {
    // shortcut: whole history in one call (server caps at 5000 per member), page by date range if it gets slow.
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/apps/nubi/activities',
      // preview=1: route shape + kudos per row, so own cards draw a map like the feed's.
      queryParameters: {'from': '2000-01-01', 'preview': '1'},
    );
    final rows = ((res.data?['data']?['activities'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    // Rows from before previews existed (never shared) have no map: build theirs from our own .fit,
    // like the web does on first share. The newest few wait so the top of the list draws; the rest
    // are saved in the background and show on the next load.
    // shortcut: activities without GPS retry once per app run; remember them on disk if that gets costly.
    final missing = [
      for (final row in rows)
        if (row['preview'] == null && _previewTried.add('${row['id']}')) row,
    ]..sort((a, b) => '${b['startedAt']}'.compareTo('${a['startedAt']}'));
    await Future.wait(missing.take(4).map(_fillPreview));
    unawaited(() async {
      for (final row in missing.skip(4)) {
        await _fillPreview(row);
      }
    }());
    // Own rows carry no author: the name and id come from the signed-in user.
    final items = [for (final row in rows) ownFromJson(row, user)];
    return items..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  final _previewTried = <String>{};

  /// Sets row['preview'] from the .fit and stores it, keeping the row's own sharing settings.
  Future<void> _fillPreview(Map<String, dynamic> row) async {
    final records = (await _fitRecords('${row['id']}')).columns;
    final preview = records == null
        ? const <List<double>>[]
        : routePreview(parseRecords(records).route);
    if (preview.length < 2) return;
    row['preview'] = preview;
    try {
      await _dio.put<void>(
        '/me/apps/nubi/activities/${row['id']}/visibility',
        data: {
          'visibility': row['visibility'],
          'shareHr': row['shareHr'] == true,
          'preview': preview,
        },
      );
    } on DioException {
      // Shown this time anyway; retried next app run.
    }
  }

  @override
  Future<List<Activity>> feed({AppUser? viewer}) async {
    // shortcut: first page only (server default limit), follow `next` when the feed page gets infinite scroll.
    final res = await _dio.get<Map<String, dynamic>>('/me/apps/nubi/feed');
    final rows = (res.data?['data']?['items'] as List?) ?? const [];
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        feedFromJson(row, viewer),
    ];
  }

  /// Feed detail first (it has the author and route); own private activities are only in /activities.
  @override
  Future<Activity?> activity(String id, {AppUser? viewer}) async {
    if (int.tryParse(id) == null) return null;
    final shared = await _getOrNull('/me/apps/nubi/feed/$id');
    if (shared != null) {
      // Like the web: our own activity reads our own .fit; members read the owner's copy.
      final copy = '/me/apps/nubi/feed/$id/records';
      var records = shared['own'] == true
          ? await _fitRecords(id)
          : await _copyRecords(copy);
      if (records.columns == null && shared['own'] == true) {
        final fallback = await _copyRecords(copy);
        if (fallback.columns != null) records = fallback;
      }
      return feedFromJson(
        shared,
        viewer,
        records: records.columns,
        recordsMissing: records.missing,
      );
    }
    final own = await _getOrNull('/me/apps/nubi/activities/$id');
    if (own == null) return null;
    final records = await _fitRecords(id);
    return ownFromJson(
      own,
      viewer,
      records: records.columns,
      recordsMissing: records.missing,
    );
  }

  /// Own original .fit decoded to record columns, or why not - the summary still shows, only
  /// the charts are left out.
  Future<_Records> _fitRecords(String id) async {
    try {
      final res = await _dio.get<List<int>>(
        '/me/apps/nubi/activities/$id/file',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(res.data ?? const []);
      // Off the UI isolate: a long activity is tens of thousands of records.
      final columns = await compute(fitRecordColumns, bytes);
      return (
        columns: columns,
        missing: columns == null
            ? '.fit has no records (${bytes.length} bytes)'
            : null,
      );
    } on DioException catch (e) {
      return (
        columns: null,
        missing: '.fit not loaded (${e.response?.statusCode ?? e.type})',
      );
    }
  }

  /// The owner's copy: raw JSON (no { success, data } envelope); any other shape counts as no
  /// copy, as on the web.
  Future<_Records> _copyRecords(String path) async {
    try {
      final data = (await _dio.get<Map<String, dynamic>>(path)).data;
      if (data?['timestamp'] is List) return (columns: data, missing: null);
      return (columns: null, missing: 'members\' copy has no timestamp column');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 404 && status != 403) rethrow;
      return (columns: null, missing: 'no members\' copy ($status)');
    }
  }

  @override
  Future<({int count, bool mine})> setKudos(
    String id, {
    required bool on,
  }) async {
    final path = '/me/apps/nubi/feed/$id/kudos';
    final res = on
        ? await _dio.post<Map<String, dynamic>>(path)
        : await _dio.delete<Map<String, dynamic>>(path);
    final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
    return (
      count: (data['count'] as num?)?.toInt() ?? 0,
      mine: data['mine'] == true,
    );
  }

  /// 403 too: a non-member may not read the feed, but can still open their own activity.
  Future<Map<String, dynamic>?> _getOrNull(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return res.data?['data'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 403) return null;
      rethrow;
    }
  }
}

/// Record columns, or why there are none.
typedef _Records = ({Map<String, dynamic>? columns, String? missing});

Activity ownFromJson(
  Map<String, dynamic> json,
  AppUser? me, {
  Map<String, dynamic>? records,
  String? recordsMissing,
}) {
  final track = records == null ? null : parseRecords(records);
  return _activity(
    json,
    userId: me?.id ?? 0,
    userName: me?.name ?? '',
    route: track != null && track.route.length > 1
        ? track.route
        : _preview(json),
    kudos: (json['kudos'] as num?)?.toInt() ?? 0,
    splits: track?.splits ?? const [],
    samples: track?.samples ?? const [],
    chartsMissing: _chartsMissing(track, recordsMissing),
  );
}

/// Why an activity has no chart samples: the fetch's reason, or records without distance.
String? _chartsMissing(
  ({List<GeoPoint> route, List<Duration> splits, List<ActivitySample> samples})?
  track,
  String? fetch,
) => track == null
    ? fetch
    : (track.samples.isEmpty ? 'records have no distance' : null);

/// The list/feed route preview: [[lat, lon], ...]; empty when absent.
List<GeoPoint> _preview(Map<String, dynamic> json) => [
  for (final p in (json['preview'] as List?) ?? const [])
    GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
];

Activity feedFromJson(
  Map<String, dynamic> json,
  AppUser? me, {
  Map<String, dynamic>? records,
  String? recordsMissing,
}) {
  final own = json['own'] == true;
  final track = records == null ? null : parseRecords(records);
  return _activity(
    json,
    // The feed hides other authors' ids; only "is it mine" is known.
    userId: own ? me?.id ?? 0 : 0,
    userName:
        (json['author'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    route: track != null && track.route.length > 1
        ? track.route
        : _preview(json),
    kudos:
        ((json['kudos'] as Map<String, dynamic>?)?['count'] as num?)?.toInt() ??
        0,
    kudosed: (json['kudos'] as Map<String, dynamic>?)?['mine'] == true,
    splits: track?.splits ?? const [],
    samples: track?.samples ?? const [],
    chartsMissing: _chartsMissing(track, recordsMissing),
  );
}

/// Column records (FIT units: semicircles, m, m/s, epoch ms) -> map route, km splits, chart samples.
({List<GeoPoint> route, List<Duration> splits, List<ActivitySample> samples})
parseRecords(Map<String, dynamic> r) {
  List<num?> col(String a, [String? b]) {
    final first = (r[a] as List?)?.cast<num?>();
    final second = b == null ? null : (r[b] as List?)?.cast<num?>();
    if (first == null) return second ?? const [];
    if (second == null) return first;
    return [
      for (var i = 0; i < first.length; i++)
        first[i] ?? (i < second.length ? second[i] : null),
    ];
  }

  final time = col('timestamp');
  final lat = col('positionLat'), lon = col('positionLong');
  final dist = col('distance'), alt = col('enhancedAltitude', 'altitude');
  final speed = col('enhancedSpeed', 'speed'), hr = col('heartRate');
  num? at(List<num?> c, int i) => i < c.length ? c[i] : null;

  const degrees = 180 / 2147483648; // 2^31
  final route = <GeoPoint>[];
  final full = <ActivitySample>[];
  final splits = <Duration>[];
  var nextKm = 1000.0;
  num? splitStart = at(time, 0);
  num? lastDistance;
  for (var i = 0; i < time.length; i++) {
    final la = at(lat, i), lo = at(lon, i);
    if (la != null && lo != null) {
      route.add(GeoPoint(la * degrees, lo * degrees));
    }
    // Strava's files put distance on only ~40% of records; the rest carry GPS, speed and most HR
    // readings, so they reuse the last distance instead of being dropped.
    final d = at(dist, i) ?? lastDistance;
    if (d == null) continue;
    lastDistance = d;
    full.add(
      ActivitySample(
        distanceM: d.toDouble(),
        altitudeM: at(alt, i)?.toDouble(),
        speedMs: at(speed, i)?.toDouble(),
        heartRate: at(hr, i)?.toDouble(),
      ),
    );
    final t = at(time, i);
    if (t != null && splitStart != null && d >= nextKm) {
      splits.add(Duration(milliseconds: (t - splitStart).round()));
      splitStart = t;
      nextKm += 1000;
    }
  }
  return (
    route: _thin(route, 1500),
    splits: splits,
    samples: _buckets(full, 300),
  );
}

/// The stored list/feed preview: [max] evenly spaced [lat, lon] at 5 decimals (the web's downsampledRoute).
List<List<double>> routePreview(List<GeoPoint> route, [int max = 150]) {
  if (route.length < 2) return const [];
  final n = math.min(max, route.length);
  double round5(double v) => (v * 1e5).round() / 1e5;
  return [
    for (var i = 0; i < n; i++)
      [
        round5(route[(i * (route.length - 1) / (n - 1)).round()].latitude),
        round5(route[(i * (route.length - 1) / (n - 1)).round()].longitude),
      ],
  ];
}

/// Every n-th point (last kept) so the map gets a light polyline.
List<T> _thin<T>(List<T> items, int max) {
  if (items.length <= max) return items;
  final step = items.length / max;
  return [for (var i = 0; i < max; i++) items[(i * step).floor()], items.last];
}

/// Averages runs of samples into at most [max] points: smooths GPS speed noise and keeps charts fast.
List<ActivitySample> _buckets(List<ActivitySample> items, int max) {
  if (items.length <= max) return items;
  final size = items.length / max;
  double? avg(Iterable<double?> values) {
    final known = values.whereType<double>();
    return known.isEmpty ? null : known.reduce((a, b) => a + b) / known.length;
  }

  return [
    for (var b = 0; b < max; b++)
      () {
        final chunk = items.sublist(
          (b * size).floor(),
          math.min(items.length, ((b + 1) * size).floor()),
        );
        return ActivitySample(
          distanceM: chunk.last.distanceM,
          altitudeM: avg(chunk.map((s) => s.altitudeM)),
          speedMs: avg(chunk.map((s) => s.speedMs)),
          heartRate: avg(chunk.map((s) => s.heartRate)),
        );
      }(),
  ];
}

Activity _activity(
  Map<String, dynamic> json, {
  required int userId,
  required String userName,
  required List<GeoPoint> route,
  required int kudos,
  bool kudosed = false,
  List<Duration> splits = const [],
  List<ActivitySample> samples = const [],
  String? chartsMissing,
}) {
  final type = switch (json['sport']) {
    'run' => ActivityType.run,
    'walk' => ActivityType.walk,
    'hike' => ActivityType.hike,
    'ride' => ActivityType.ride,
    _ => ActivityType.other,
  };
  final name = json['name'] as String?;
  return Activity(
    id: '${json['id']}',
    userId: userId,
    userName: userName,
    title: name == null || name.trim().isEmpty ? _defaultTitle(type) : name,
    type: type,
    startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
    distanceKm: ((json['distanceM'] as num?) ?? 0) / 1000,
    duration: Duration(seconds: ((json['movingS'] as num?) ?? 0).round()),
    location: '',
    latitude: route.isEmpty ? 0 : route.first.latitude,
    longitude: route.isEmpty ? 0 : route.first.longitude,
    route: route,
    elevationGainM: ((json['elevationGainM'] as num?) ?? 0).round(),
    kudos: kudos,
    kudosed: kudosed,
    splits: splits,
    samples: samples,
    chartsMissing: chartsMissing,
    elapsed: Duration(seconds: ((json['elapsedS'] as num?) ?? 0).round()),
    avgHr: (json['avgHr'] as num?)?.round(),
    maxHr: (json['maxHr'] as num?)?.round(),
    weather: switch (json['weather']) {
      final Map<String, dynamic> w => ActivityWeather(
        temperatureC: (w['temperatureC'] as num?)?.toDouble(),
        feelsLikeC: (w['feelsLikeC'] as num?)?.toDouble(),
        humidityPct: (w['humidityPct'] as num?)?.toDouble(),
        windSpeedMs: (w['windSpeedMs'] as num?)?.toDouble(),
        windDirectionDeg: (w['windDirectionDeg'] as num?)?.toDouble(),
      ),
      _ => null,
    },
  );
}

String _defaultTitle(ActivityType type) => switch (type) {
  ActivityType.run => 'Run',
  ActivityType.walk => 'Walk',
  ActivityType.hike => 'Hike',
  ActivityType.ride => 'Ride',
  ActivityType.other => 'Activity',
};
