import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/change_email_page.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/email_notifications_page.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/help_page.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/phone_number_page.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/push_notifications_page.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/theme_page.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: page));
    await tester.pumpAndSettle();
  }

  testWidgets('notification pages render and toggle', (tester) async {
    await pumpPage(tester, const EmailNotificationsPage());
    expect(find.text('Email Notifications'), findsOneWidget);
    expect(find.text('Activity updates'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await pumpPage(tester, const PushNotificationsPage());
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(find.text('New followers'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone, email and help forms work', (tester) async {
    await pumpPage(tester, const PhoneNumberPage());
    expect(find.text('Phone Number'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Save number'));
    await tester.pump();
    expect(find.text('Enter a valid phone number.'), findsOneWidget);

    await pumpPage(tester, const ChangeEmailPage(currentEmail: 'ahli@nubi.test'));
    expect(find.text('ahli@nubi.test'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'baru@nubi.test');
    await tester.enterText(find.byType(TextField).at(1), 'Password123!');
    await tester.tap(find.text('Send verification link'));
    await tester.pump();
    expect(find.text('Verification link sent to baru@nubi.test.'), findsOneWidget);

    await pumpPage(tester, const HelpPage());
    expect(find.text('Popular topics'), findsOneWidget);
    expect(find.text('How do I cancel my subscription?'), findsOneWidget);
    expect(find.text('Contact support'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance page selects a theme mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const ThemePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Phone default'), findsOneWidget);
    expect(find.text('Light mode'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    await tester.tap(find.text('Light mode'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
