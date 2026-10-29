enum ActivityType { run, walk, hike, ride, other }

/// A plain coordinate pair, so the domain does not depend on a map package.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Weather at the run's midpoint (MET Norway); any field can be missing.
class ActivityWeather {
  const ActivityWeather({
    this.temperatureC,
    this.feelsLikeC,
    this.humidityPct,
    this.windSpeedMs,
    this.windDirectionDeg,
  });
  final double? temperatureC;
  final double? feelsLikeC;
  final double? humidityPct;
  final double? windSpeedMs;
  final double? windDirectionDeg;
}

/// One point of the recorded streams, keyed by distance for the detail charts.
class ActivitySample {
  const ActivitySample({
    required this.distanceM,
    this.altitudeM,
    this.speedMs,
    this.heartRate,
  });
  final double distanceM;
  final double? altitudeM;
  final double? speedMs;
  final double? heartRate;
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
    this.elapsed = Duration.zero,
    this.avgHr,
    this.maxHr,
    this.weather,
    this.samples = const [],
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

  /// Wall-clock time including pauses; zero when unknown.
  final Duration elapsed;
  final int? avgHr;
  final int? maxHr;
  final ActivityWeather? weather;

  /// Downsampled streams for the elevation/pace/heart-rate charts; empty when not shared.
  final List<ActivitySample> samples;

  Duration get pace {
    if (distanceKm <= 0) return Duration.zero;
    return Duration(seconds: (duration.inSeconds / distanceKm).round());
  }

  String get userInitial {
    final name = userName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }
}
