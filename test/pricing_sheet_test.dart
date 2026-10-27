import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/features/settings/presentation/widgets/pricing_sheet.dart';

void main() {
  testWidgets('pricing sheet fits and scrolls horizontally', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(onPressed: () => showPricingSheet(context), child: const Text('Buka')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.text('Member'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
