import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/brand.dart';
import '../../domain/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_box.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = 'admin@nubi.test';
    _password.text = 'Password123!';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(email: _email.text.trim(), password: _password.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = loginMessage(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRegister() {
    FocusManager.instance.primaryFocus?.unfocus();
    AppNavigator.push<void>(context, AppRoutes.register);
  }

  void _openForgotPassword() {
    FocusManager.instance.primaryFocus?.unfocus();
    AppNavigator.push<void>(context, AppRoutes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandCrest(size: 120)),
                        const SizedBox(height: 28),
                        Text('Log in', style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                          'Your plans, activities and group runs.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email, AutofillHints.username],
                          autocorrect: false,
                          enabled: !_busy,
                          validator: (v) => (v == null || !v.trim().contains('@')) ? 'Enter a valid email.' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Hide password' : 'Show password',
                              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          enabled: !_busy,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password.' : null,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _TextLink(label: 'Forgot password?', onTap: _busy ? null : _openForgotPassword),
                        ),
                        if (_error != null) ...[const SizedBox(height: 16), AuthErrorBox(message: _error!)],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
                                )
                              : const Text('Log in'),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            _TextLink(
                              label: 'Sign up',
                              onTap: _busy ? null : _openRegister,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain text that navigates on tap - same look as the web's inline links.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap, this.style});
  final String label;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.light ? AppColors.orangeInk : AppColors.orangeHover;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: MouseRegion(
        cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              label,
              style: (style ?? theme.textTheme.bodyMedium)?.copyWith(
                color: onTap == null ? theme.colorScheme.onSurfaceVariant : color,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: onTap == null ? theme.colorScheme.onSurfaceVariant : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same wording as the web login (nubisport-astro src/pages/login.astro).
String loginMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.invalidCredentials => 'Incorrect email or password.',
  AuthFailureReason.emailUnverified => 'Verify your email first - check your inbox for the verification link.',
  AuthFailureReason.banned => 'This account is suspended. Contact a Nubi admin.',
  AuthFailureReason.captcha => 'Spam check failed. App login is not enabled for this server yet.',
  AuthFailureReason.rateLimited => 'Too many attempts. Wait a minute.',
  AuthFailureReason.network => 'No connection. Check your internet and try again.',
  _ => 'Can\'t log in right now. Try again shortly.',
};
