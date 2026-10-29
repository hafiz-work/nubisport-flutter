enum ActivityType { run, walk, hike, ride, other }

/// A plain coordinate pair, so the domain does not depend on a map package.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class Activity {
  const Activity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.type,
    required this.startedAt,
    required this.distanceKm,
    required this.duration,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.route = const [],
    this.elevationGainM = 0,
    this.calories = 0,
    this.kudos = 0,
    this.kudosed = false,
    this.notes = '',
    this.splits = const [],
  });

  final String id;
  final int userId;
  final String userName;
  final String title;
  final ActivityType type;
  final DateTime startedAt;
  final double distanceKm;
  final Duration duration;
  final String location;
  final double latitude;
  final double longitude;

  /// Points of the recorded route, ordered from start to finish.
  final List<GeoPoint> route;

  final int elevationGainM;
  final int calories;
  final int kudos;

  /// The signed-in viewer gave kudos (counted in [kudos]).
  final bool kudosed;
  final String notes;

  /// One split per kilometre (time for that km).
  final List<Duration> splits;

  Duration get pace {
    if (distanceKm <= 0) return Duration.zero;
    return Duration(seconds: (duration.inSeconds / distanceKm).round());
  }

  String get userInitial {
    final name = userName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }
}
