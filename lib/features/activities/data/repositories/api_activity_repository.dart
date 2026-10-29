import 'package:dio/dio.dart';

import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/activity.dart';
import '../../domain/repositories/activity_repository.dart';

/// hono-workers /me/apps/nubi/activities (own) and /me/apps/nubi/feed (members' shared runs).
///
/// The API has no place name, calories, notes or splits, and only feed items carry a route
/// preview - those fields stay at their empty defaults.
class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository(this._dio, {required this.currentUser});
  final Dio _dio;

  /// The signed-in user: own activities from the API carry no author name.
  final AppUser? Function() currentUser;

  @override
  Future<List<Activity>> myActivities({required int userId}) async {
    // shortcut: whole history in one call (server caps at 5000 per member), page by date range if it gets slow.
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/apps/nubi/activities',
      queryParameters: {'from': '2000-01-01'},
    );
    final rows = (res.data?['data']?['activities'] as List?) ?? const [];
    final items = [for (final row in rows.cast<Map<String, dynamic>>()) ownFromJson(row, currentUser())];
    return items..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<List<Activity>> feed() async {
    // shortcut: first page only (server default limit), follow `next` when the feed page gets infinite scroll.
    final res = await _dio.get<Map<String, dynamic>>('/me/apps/nubi/feed');
    final rows = (res.data?['data']?['items'] as List?) ?? const [];
    return [for (final row in rows.cast<Map<String, dynamic>>()) feedFromJson(row, currentUser())];
  }

  /// Feed detail first (it has the author and route); own private activities are only in /activities.
  @override
  Future<Activity?> activity(String id) async {
    if (int.tryParse(id) == null) return null;
    final shared = await _getOrNull('/me/apps/nubi/feed/$id');
    if (shared != null) return feedFromJson(shared, currentUser());
    final own = await _getOrNull('/me/apps/nubi/activities/$id');
    return own == null ? null : ownFromJson(own, currentUser());
  }

  @override
  Future<({int count, bool mine})> setKudos(String id, {required bool on}) async {
    final path = '/me/apps/nubi/feed/$id/kudos';
    final res = on ? await _dio.post<Map<String, dynamic>>(path) : await _dio.delete<Map<String, dynamic>>(path);
    final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
    return (count: (data['count'] as num?)?.toInt() ?? 0, mine: data['mine'] == true);
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

Activity ownFromJson(Map<String, dynamic> json, AppUser? me) =>
    _activity(json, userId: me?.id ?? 0, userName: me?.name ?? '', route: const [], kudos: 0);

Activity feedFromJson(Map<String, dynamic> json, AppUser? me) {
  final own = json['own'] == true;
  return _activity(
    json,
    // The feed hides other authors' ids; only "is it mine" is known.
    userId: own ? me?.id ?? 0 : 0,
    userName: (json['author'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    route: [
      for (final p in (json['preview'] as List?) ?? const [])
        GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ],
    kudos: ((json['kudos'] as Map<String, dynamic>?)?['count'] as num?)?.toInt() ?? 0,
    kudosed: (json['kudos'] as Map<String, dynamic>?)?['mine'] == true,
  );
}

Activity _activity(
  Map<String, dynamic> json, {
  required int userId,
  required String userName,
  required List<GeoPoint> route,
  required int kudos,
  bool kudosed = false,
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
  );
}

String _defaultTitle(ActivityType type) => switch (type) {
  ActivityType.run => 'Run',
  ActivityType.walk => 'Walk',
  ActivityType.hike => 'Hike',
  ActivityType.ride => 'Ride',
  ActivityType.other => 'Activity',
};
