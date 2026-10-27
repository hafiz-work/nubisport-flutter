import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/training_zones_page.dart';

void main() {
  testWidgets('training zones page renders all three tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const TrainingZonesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Training Zones'), findsOneWidget);
    expect(find.text('Heart Rate'), findsOneWidget);
    expect(find.text('Power'), findsOneWidget);
    expect(find.text('Pace'), findsOneWidget);
    expect(find.text('Max Heart Rate (bpm)'), findsOneWidget);
    expect(find.text('Zone 5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Power'));
    await tester.pumpAndSettle();
    expect(find.text('Functional Threshold Power (Watts)'), findsOneWidget);
    expect(find.text('Zone 7'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Pace'));
    await tester.pumpAndSettle();
    expect(find.text('Distance'), findsOneWidget);
    expect(find.textContaining('Add your event and time'), findsOneWidget);

    await tester.tap(find.text('Distance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 km'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('10 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
