import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/shared/widgets/family_bottom_sheet/family_modal_sheet.dart';

void main() {
  testWidgets('family sheet floats with app theme', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => FamilyModalSheet.show<void>(
                context: context,
                contentBackgroundColor: Colors.red,
                showDragHandle: true,
                builder: (sheetContext) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // Theme.of inside builder used to throw before initState completed.
                  children: [Text('x', style: Theme.of(sheetContext).textTheme.bodyMedium)],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.red));
    expect(rect.left, greaterThan(0));
    expect(rect.right, lessThan(400));
    expect(rect.bottom, lessThan(800));
    // The outer sheet layer must not paint the theme surface behind the margin.
    final outer = tester.widget<Material>(find.ancestor(of: find.byWidgetPredicate((w) => w is ColoredBox && w.color == Colors.red), matching: find.byType(Material)).first);
    expect(outer.color, Colors.transparent);
    // The drag handle must sit on the content background, not the transparent outer layer.
    final handle = tester.getRect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DragHandle'));
    expect(rect.contains(handle.center), isTrue);
  });
}
