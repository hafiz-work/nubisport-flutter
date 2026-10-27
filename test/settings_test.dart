import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/config/app_config.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:nubisport_flutter/flavors.dart';

void main() {
  testWidgets('settings sections render on a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: Flavor.dev, apiBaseUrl: '', webOrigin: '', isMock: true),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const SettingsPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('SUBSCRIPTIONS'), findsOneWidget);
    expect(find.text('30-Day Subscription Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('PREFERENCES'), 300, scrollable: scrollable);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Log Out'), 300, scrollable: scrollable);
    expect(tester.takeException(), isNull);
  });
}
