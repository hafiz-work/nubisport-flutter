import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/presentation/activity_format.dart';

void main() {
  test('relative dates read like Strava', () {
    final now = DateTime(2026, 10, 29, 9, 0);
    expect(
      formatRelativeDate(DateTime(2026, 10, 29, 6, 5), now: now),
      'Today at 06:05',
    );
    expect(
      formatRelativeDate(DateTime(2026, 10, 28, 18, 22), now: now),
      'Yesterday at 18:22',
    );
    expect(
      formatRelativeDate(DateTime(2026, 10, 27, 23, 59), now: now),
      '27 Oct 2026 at 23:59',
    );
  });
}
