import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/ai_assistants_page.dart';

void main() {
  testWidgets('AI assistants page renders the Claude connection flow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const AiAssistantsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Get more from your training with Claude'), findsOneWidget);
    expect(find.text('How to connect'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final connectButton = find.widgetWithText(FilledButton, 'Connect to Claude');
    await tester.scrollUntilVisible(connectButton, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(connectButton);
    await tester.pump();

    expect(find.text('Claude connector is coming soon.'), findsOneWidget);
  });
}
