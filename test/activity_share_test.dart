import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_share_sheet.dart';

void main() {
  testWidgets('activity share sheet shows the custom template', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final activity = Activity(
      id: 'share-card',
      userId: 1,
      userName: 'Demo Member',
      title: 'Botanic Garden Morning Run',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 25, 6, 30),
      distanceKm: 5.02,
      duration: const Duration(minutes: 28, seconds: 41),
      location: 'Taman Botani, Shah Alam',
      latitude: 3.0733,
      longitude: 101.5185,
      elevationGainM: 42,
      route: const [
        GeoPoint(3.0715, 101.5155),
        GeoPoint(3.0740, 101.5180),
        GeoPoint(3.0755, 101.5210),
        GeoPoint(3.0725, 101.5235),
        GeoPoint(3.0700, 101.5200),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showActivityShareSheet(context, activity, isMine: true),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share activity'), findsOneWidget);
    expect(find.byType(ActivityShareCard), findsOneWidget);
    expect(find.text('Share image'), findsOneWidget);
    expect(find.text('Copy caption'), findsOneWidget);

    // Every template renders without overflow.
    for (final t in ShareTemplate.values) {
      final tile = find.byKey(ValueKey(t));
      await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.textContaining(t.hint), findsOneWidget);
      expect(tester.takeException(), isNull, reason: t.label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('someone else\'s activity gets the simple sheet without templates', (tester) async {
    final activity = Activity(
      id: 'other',
      userId: 2,
      userName: 'Orang Lain',
      title: 'Evening Run',
      type: ActivityType.run,
      startedAt: DateTime(2026, 10, 25, 18),
      distanceKm: 3,
      duration: const Duration(minutes: 18),
      location: 'Shah Alam',
      latitude: 3.07,
      longitude: 101.51,
      elevationGainM: 10,
      route: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showActivityShareSheet(context, activity, isMine: false),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share to'), findsOneWidget);
    expect(find.byType(ActivityShareCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
