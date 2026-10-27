import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubisport_flutter/core/navigation/app_navigator.dart';
import 'package:nubisport_flutter/core/navigation/app_router.dart';
import 'package:nubisport_flutter/core/navigation/app_routes.dart';
import 'package:nubisport_flutter/core/theme/app_theme.dart';
import 'package:nubisport_flutter/features/auth/domain/models/app_user.dart';

void main() {
  test('router generates every named route', () {
    const plainRoutes = [
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.settings,
      AppRoutes.activities,
      AppRoutes.trainingPlans,
      AppRoutes.planBuilder,
      AppRoutes.changePassword,
      AppRoutes.phoneNumber,
      AppRoutes.help,
      AppRoutes.appearance,
      AppRoutes.trainingZones,
      AppRoutes.pushNotifications,
      AppRoutes.emailNotifications,
      AppRoutes.aiAssistants,
    ];
    for (final name in plainRoutes) {
      expect(AppRouter.onGenerateRoute(RouteSettings(name: name)), isA<MaterialPageRoute<void>>());
    }

    const user = AppUser(id: 1, name: 'Demo Member', email: 'member@nubi.test', role: 'user', apps: {'nubi': 'ahli'});
    expect(
      AppRouter.onGenerateRoute(RouteSettings(name: AppRoutes.editProfile, arguments: user)),
      isA<MaterialPageRoute<void>>(),
    );
    expect(
      AppRouter.onGenerateRoute(RouteSettings(name: AppRoutes.activityDetail, arguments: 'a1')),
      isA<MaterialPageRoute<void>>(),
    );
    expect(
      AppRouter.onGenerateRoute(RouteSettings(name: AppRoutes.changeEmail, arguments: 'member@nubi.test')),
      isA<MaterialPageRoute<void>>(),
    );
    expect(AppRouter.onGenerateRoute(const RouteSettings(name: '/missing')), isNull);
  });

  testWidgets('AppNavigator pushes the named help route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AppNavigator.push<void>(context, AppRoutes.help),
                child: const Text('Open help'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open help'));
    await tester.pumpAndSettle();

    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Popular topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
