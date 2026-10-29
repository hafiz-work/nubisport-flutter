import 'package:flutter/material.dart';

import '../../features/auth/domain/models/app_user.dart';
import '../../features/plans/domain/models/plan.dart';
import '../../features/plans/presentation/pages/plan_form_page.dart';
import 'app_routes.dart';

abstract final class AppNavigator {
  static Future<T?> push<T>(BuildContext context, String routeName, {Object? arguments}) =>
      Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);

  static Future<void> activityDetail(BuildContext context, String id) =>
      push<void>(context, AppRoutes.activityDetail, arguments: id);

  static Future<void> editProfile(BuildContext context, AppUser user) =>
      push<void>(context, AppRoutes.editProfile, arguments: user);

  static Future<void> changeEmail(BuildContext context, String email) =>
      push<void>(context, AppRoutes.changeEmail, arguments: email);

  static Future<void> planView(BuildContext context, CloudPlan plan) =>
      push<void>(context, AppRoutes.planView, arguments: plan);

  static Future<void> planBuilder(BuildContext context, [PlanFormArgs args = const PlanFormArgs()]) =>
      push<void>(context, AppRoutes.planBuilder, arguments: args);
}
