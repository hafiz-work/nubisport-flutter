import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/activities/domain/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/activity_providers.dart';
import 'package:nubisport_flutter/features/auth/domain/app_user.dart';
import 'package:nubisport_flutter/features/profile/profile_page.dart';

Activity _activity({
  required String id,
  required int daysAgo,
  required double km,
  required Duration duration,
  required List<Duration> splits,
}) {
  return Activity(
    id: id,
    userId: 1,
    userName: 'Ahli Demo',
    title: 'Test Run $id',
    type: ActivityType.run,
    startedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    distanceKm: km,
    duration: duration,
    location: 'Taman Botani',
    latitude: 3.0733,
    longitude: 101.5185,
    elevationGainM: 30,
    splits: splits,
  );
}

void main() {
  testWidgets('profile progress renders all cards without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final activities = [
      _activity(
        id: 'p1',
        daysAgo: 1,
        km: 5,
        duration: const Duration(minutes: 28, seconds: 41),
        splits: const [
          Duration(minutes: 5, seconds: 12),
          Duration(minutes: 5, seconds: 38),
          Duration(minutes: 5, seconds: 49),
          Duration(minutes: 5, seconds: 46),
          Duration(minutes: 6, seconds: 16),
        ],
      ),
      _activity(
        id: 'p2',
        daysAgo: 4,
        km: 8.1,
        duration: const Duration(minutes: 47, seconds: 5),
        splits: const [
          Duration(minutes: 5, seconds: 48),
          Duration(minutes: 5, seconds: 52),
          Duration(minutes: 5, seconds: 45),
          Duration(minutes: 5, seconds: 50),
          Duration(minutes: 5, seconds: 57),
        ],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [myActivitiesProvider.overrideWith((ref) async => activities)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfilePage(
            user: AppUser(id: 1, name: 'Ahli Demo', email: 'ahli@nubi.test', role: 'user', apps: {'nubi': 'ahli'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12 minggu lepas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Best Efforts'), 400, scrollable: scrollable);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Pelan latihan'), 400, scrollable: scrollable);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Lagi'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(find.text('Subscription overview'), findsOneWidget);
    expect(find.text('Challenges'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final moreScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Trophy Case'), 300, scrollable: moreScrollable);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('All trophies'), 300, scrollable: moreScrollable);
    expect(tester.takeException(), isNull);
  });
}
