import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/plans/presentation/pages/training_plans_page.dart';

void main() {
  testWidgets('training plans list and all plan sheets render on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const TrainingPlansPage()));
    await tester.pumpAndSettle();

    expect(find.text('Training Plans'), findsOneWidget);
    expect(find.text('Race'), findsOneWidget);
    expect(find.text('5k improvement plan'), findsOneWidget);
    expect(find.text('Start running'), findsOneWidget);
    expect(find.text('Explore training plan'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('explore-Race')));
    await tester.pumpAndSettle();
    expect(find.text('Any race. One plan.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('explore-5k improvement plan')),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('explore-5k improvement plan')));
    await tester.pumpAndSettle();

    expect(find.text('Improve your 5k.'), findsOneWidget);
    expect(find.text('6-8 weeks'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('explore-Start running')),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('explore-Start running')));
    await tester.pumpAndSettle();

    expect(find.text('New To Running plan'), findsOneWidget);
    expect(find.text('8 - 12 weeks'), findsOneWidget);
    expect(find.text('Example week'), findsOneWidget);
    expect(find.text('Weekly total'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('explore-General training')),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('explore-General training')));
    await tester.pumpAndSettle();

    expect(find.text('Built around you.'), findsOneWidget);
    expect(find.text('Three plans to choose from:'), findsOneWidget);
    expect(find.text('Example week'), findsOneWidget);
    expect(find.text('Weekly total'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('explore-Distance Plans')),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('explore-Distance Plans')));
    await tester.pumpAndSettle();

    expect(find.text('Pick Your Distance.'), findsOneWidget);
    expect(find.text('5k - 50k'), findsOneWidget);
    expect(find.text('6+ weeks'), findsOneWidget);
    expect(find.text('Example week'), findsOneWidget);
    expect(find.text('Weekly total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
