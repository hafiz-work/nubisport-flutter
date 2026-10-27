import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_card.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_map.dart';

void main() {
  testWidgets('tapping the map triggers the card action', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var taps = 0;
    final activity = Activity(
      id: 'map-tap',
      userId: 1,
      userName: 'Demo Member',
      title: 'Test Run',
      type: ActivityType.run,
      startedAt: DateTime.now(),
      distanceKm: 5,
      duration: const Duration(minutes: 30),
      location: 'Taman Botani',
      latitude: 3.0733,
      longitude: 101.5185,
      route: const [GeoPoint(3.0715, 101.5155), GeoPoint(3.0755, 101.5210)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityCard(activity: activity, showUser: true, onTap: () => taps++),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.byType(ActivityMap)));
    await tester.pump();

    expect(taps, 1);
  });
}
