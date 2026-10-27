import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/controllers/activity_providers.dart';
import 'package:nubisport_flutter/features/auth/domain/models/app_user.dart';
import 'package:nubisport_flutter/features/home/home_page.dart';

void main() {
  testWidgets('dashboard renders stats and recent activities on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final activity = Activity(
      id: 't1',
      userId: 1,
      userName: 'Demo Member',
      title: 'Test Run',
      type: ActivityType.run,
      startedAt: DateTime.now().subtract(const Duration(days: 1)),
      distanceKm: 5,
      duration: const Duration(minutes: 30),
      location: 'Taman Botani',
      latitude: 3.0733,
      longitude: 101.5185,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myActivitiesProvider.overrideWith((ref) async => [activity]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomePage(
            user: AppUser(id: 1, name: 'Demo Member', email: 'ahli@nubi.test', role: 'user', apps: {'nubi': 'ahli'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Member'), findsOneWidget);
    expect(find.text('Nubi Member'), findsOneWidget);
    expect(find.text('Last 7 days summary'), findsOneWidget);
    expect(find.text('Shortcuts'), findsOneWidget);
    expect(find.text('Recent activities'), findsOneWidget);
    expect(find.text('Test Run'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
