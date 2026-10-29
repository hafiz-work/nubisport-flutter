import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/activities/presentation/widgets/activity_stream_chart.dart';

void main() {
  testWidgets(
    'pace chart with elevation background renders, animates in and scrubs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityStreamChart(
              xKm: [for (var i = 0; i < 50; i++) i * 0.05],
              values: [
                for (var i = 0; i < 50; i++)
                  i == 10 ? null : 600.0 + (i % 7) * 40,
              ],
              background: [for (var i = 0; i < 50; i++) 50.0 + i],
              color: Colors.blue,
              format: (v) => '${v.round()}',
              unit: '/km',
              inverted: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('/km'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LineChart)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
