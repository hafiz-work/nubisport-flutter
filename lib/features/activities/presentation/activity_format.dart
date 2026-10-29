import 'package:flutter/material.dart';

import '../domain/models/activity.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDistance(double km) => '${km.toStringAsFixed(2)} km';

String formatDuration(Duration duration) {
  if (duration.inHours > 0) return '${duration.inHours}j ${duration.inMinutes % 60}m';
  if (duration.inMinutes > 0) return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  return '${duration.inSeconds}s';
}

String formatPace(Duration pace) {
  if (pace == Duration.zero) return '—';
  return "${pace.inMinutes}'${twoDigits(pace.inSeconds % 60)}\"/km";
}

String formatSplit(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}:${twoDigits(duration.inMinutes % 60)}:${twoDigits(duration.inSeconds % 60)}';
  }
  return '${duration.inMinutes}:${twoDigits(duration.inSeconds % 60)}';
}

String formatActivityDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]} ${date.year}, '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

String activityLabel(ActivityType type) => switch (type) {
  ActivityType.run => 'Run',
  ActivityType.walk => 'Jalan kaki',
  ActivityType.hike => 'Hike',
  ActivityType.ride => 'Kayuh',
  ActivityType.other => 'Activity',
};

IconData activityIcon(ActivityType type) => switch (type) {
  ActivityType.run => Icons.directions_run,
  ActivityType.walk => Icons.directions_walk,
  ActivityType.hike => Icons.hiking,
  ActivityType.ride => Icons.directions_bike,
  ActivityType.other => Icons.fitness_center,
};
