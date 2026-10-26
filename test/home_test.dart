import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/activities/domain/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/activity_providers.dart';
import 'package:nubisport_flutter/features/auth/domain/app_user.dart';
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
      userName: 'Ahli Demo',
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
            user: AppUser(id: 1, name: 'Ahli Demo', email: 'ahli@nubi.test', role: 'user', apps: {'nubi': 'ahli'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ahli Demo'), findsOneWidget);
    expect(find.text('Ahli Nubi'), findsOneWidget);
    expect(find.text('Ringkasan 7 hari terakhir'), findsOneWidget);
    expect(find.text('Pintasan'), findsOneWidget);
    expect(find.text('Aktiviti terkini'), findsOneWidget);
    expect(find.text('Test Run'), findsOneWidget);
    expect(find.text('Lihat semua'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
