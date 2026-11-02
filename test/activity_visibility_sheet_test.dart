import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/activities/domain/models/activity.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_visibility_sheet.dart';

final _mine = Activity(
  id: '12',
  userId: 1,
  userName: 'Aina',
  title: 'Run',
  type: ActivityType.run,
  startedAt: DateTime(2026, 10, 25),
  distanceKm: 5,
  duration: const Duration(minutes: 30),
  location: '',
  latitude: 0,
  longitude: 0,
  visibility: ActivityVisibility.members,
);

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(ActivityVisibility, bool) onSave,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                showActivityVisibilitySheet(context, _mine, onSave: onSave),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pick Public + heart rate, save, sheet closes', (tester) async {
    final saved = <(ActivityVisibility, bool)>[];
    await _open(tester, (v, hr) async => saved.add((v, hr)));
    await tester.tap(find.text('Public link'));
    await tester.tap(find.text('Share heart rate'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, [(ActivityVisibility.public, true)]);
    expect(find.text('Who can see this activity'), findsNothing);
  });

  testWidgets(
    'Only me turns heart rate off; a failed save keeps the sheet with a message',
    (tester) async {
      final saved = <(ActivityVisibility, bool)>[];
      await _open(tester, (v, hr) async {
        saved.add((v, hr));
        throw Exception('offline');
      });
      await tester.tap(find.text('Share heart rate'));
      await tester.tap(find.text('Only me'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, [(ActivityVisibility.private, false)]);
      expect(find.text('Couldn\'t change sharing. Try again.'), findsOneWidget);
      expect(find.text('Who can see this activity'), findsOneWidget);
    },
  );
}
