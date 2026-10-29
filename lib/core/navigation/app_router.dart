import 'package:flutter/material.dart';

import '../../features/activities/presentation/pages/activities_page.dart';
import '../../features/activities/presentation/pages/activity_detail_page.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/plans/domain/models/plan.dart';
import '../../features/plans/presentation/pages/plan_form_page.dart';
import '../../features/plans/presentation/pages/plan_view_page.dart';
import '../../features/plans/presentation/pages/training_plans_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/settings/presentation/pages/ai_assistants_page.dart';
import '../../features/settings/presentation/pages/change_email_page.dart';
import '../../features/settings/presentation/pages/email_notifications_page.dart';
import '../../features/settings/presentation/pages/help_page.dart';
import '../../features/settings/presentation/pages/phone_number_page.dart';
import '../../features/settings/presentation/pages/push_notifications_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/theme_page.dart';
import '../../features/settings/presentation/pages/training_zones_page.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final page = _page(settings);
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  static Widget? _page(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return const LoginPage();
      case AppRoutes.register:
        return const RegisterPage();
      case AppRoutes.forgotPassword:
        return const ForgotPasswordPage();
      case AppRoutes.settings:
        return const SettingsPage();
      case AppRoutes.editProfile:
        final user = settings.arguments;
        return user is AppUser ? EditProfilePage(user: user) : null;
      case AppRoutes.activityDetail:
        final id = settings.arguments;
        return id is String ? ActivityDetailPage(activityId: id) : null;
      case AppRoutes.activities:
        return const ActivitiesPage();
      case AppRoutes.trainingPlans:
        return const TrainingPlansPage();
      case AppRoutes.planBuilder:
        final arguments = settings.arguments;
        return PlanFormPage(args: arguments is PlanFormArgs ? arguments : const PlanFormArgs());
      case AppRoutes.planView:
        final plan = settings.arguments;
        return plan is CloudPlan ? PlanViewPage(plan: plan) : null;
      case AppRoutes.changePassword:
        return const ChangePasswordPage();
      case AppRoutes.changeEmail:
        final email = settings.arguments;
        return email is String ? ChangeEmailPage(currentEmail: email) : null;
      case AppRoutes.phoneNumber:
        return const PhoneNumberPage();
      case AppRoutes.help:
        return const HelpPage();
      case AppRoutes.appearance:
        return const ThemePage();
      case AppRoutes.trainingZones:
        return const TrainingZonesPage();
      case AppRoutes.pushNotifications:
        return const PushNotificationsPage();
      case AppRoutes.emailNotifications:
        return const EmailNotificationsPage();
      case AppRoutes.aiAssistants:
        return const AiAssistantsPage();
      default:
        return null;
    }
  }
}
