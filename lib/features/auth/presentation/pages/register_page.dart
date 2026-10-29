import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/brand.dart';
import '../../domain/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_box.dart';
import '../widgets/captcha.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final captchaToken = await ref.read(captchaSolverProvider)('register');
      if (captchaToken == null) throw const AuthFailure(AuthFailureReason.captcha);
      await ref
          .read(authControllerProvider.notifier)
          .register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            captchaToken: captchaToken,
          );
      if (mounted) setState(() => _done = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = registerMessage(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _done
                    ? _VerifyEmail(onBack: () => Navigator.of(context).pop())
                    : AutofillGroup(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: BrandCrest(size: 100)),
                              const SizedBox(height: 24),
                              Text('Create account', style: theme.textTheme.headlineLarge, textAlign: TextAlign.center),
                              const SizedBox(height: 6),
                              Text(
                                'One account for Nubi Sport and hafizbahtiar.com.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(labelText: 'Name', counterText: ''),
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                enabled: !_busy,
                                maxLength: 100,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  return (value.isEmpty || value.length > 100)
                                      ? 'Enter a name (maximum 100 characters).'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'Email', counterText: ''),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email, AutofillHints.username],
                                autocorrect: false,
                                enabled: !_busy,
                                maxLength: 255,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  return (!value.contains('@') || value.length > 255) ? 'Enter a valid email.' : null;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _password,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  counterText: '',
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                                    icon: Icon(
                                      _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    ),
                                    onPressed: () => setState(() => _showPassword = !_showPassword),
                                  ),
                                ),
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.newPassword],
                                enabled: !_busy,
                                maxLength: 200,
                                validator: (v) {
                                  final value = v ?? '';
                                  return (value.length < 12 || value.length > 200)
                                      ? 'Password must be 12 to 200 characters.'
                                      : null;
                                },
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _password,
                                builder: (context, value, _) => _PasswordStrength(password: value.text),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _password2,
                                decoration: const InputDecoration(labelText: 'Confirm password', counterText: ''),
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.newPassword],
                                enabled: !_busy,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) => v != _password.text ? 'Passwords do not match.' : null,
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
                                    : const Text('Sign up'),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'By signing up, you agree to the Nubi Sport Terms and Privacy Policy.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                                child: const Text('Already have an account? Log in'),
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

/// Live password strength: a 3-step level bar plus the counts behind it, so the
/// user can see exactly what is missing (length, upper/lower case, digits, symbols).
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strongColor = theme.brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

    final upper = RegExp(r'[A-Z]').allMatches(password).length;
    final lower = RegExp(r'[a-z]').allMatches(password).length;
    final digits = RegExp(r'\d').allMatches(password).length;
    final symbols = RegExp(r'[^A-Za-z0-9\s]').allMatches(password).length;
    final lengthOk = password.length >= 12 && password.length <= 200;

    final rules = <_PasswordRule>[
      _PasswordRule('12+ characters', password.length, lengthOk),
      _PasswordRule('Uppercase', upper, upper > 0),
      _PasswordRule('Lowercase', lower, lower > 0),
      _PasswordRule('Number', digits, digits > 0),
      _PasswordRule('Symbol', symbols, symbols > 0),
    ];
    final met = rules.where((r) => r.ok).length;
    final level = !lengthOk ? 1 : (met >= 5 ? 3 : (met >= 4 ? 2 : 1));
    final color = switch (level) {
      3 => strongColor,
      2 => scheme.primary,
      _ => scheme.error,
    };
    final label = switch (level) {
      3 => 'Kuat',
      2 => 'Sederhana',
      _ => 'Lemah',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                          decoration: BoxDecoration(
                            color: i < level ? color : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final itemWidth = (constraints.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final rule in rules)
                    SizedBox(
                      width: itemWidth,
                      child: _RuleChip(label: rule.label, count: rule.count, ok: rule.ok, okColor: strongColor),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PasswordRule {
  const _PasswordRule(this.label, this.count, this.ok);
  final String label;
  final int count;
  final bool ok;
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.count, required this.ok, required this.okColor});
  final String label;
  final int count;
  final bool ok;
  final Color okColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok ? okColor : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? okColor.withValues(alpha: 0.10) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: ok ? okColor.withValues(alpha: 0.35) : scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.circle_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _VerifyEmail extends StatelessWidget {
  const _VerifyEmail({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text('Check your email', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'If this email can be registered, a verification link is on its way. '
          'Click the link within 24 hours, then log in.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'No email? Check your spam folder.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: onBack, child: const Text('Back to log in')),
      ],
    );
  }
}

/// Same wording as the web register page (nubisport-astro src/pages/register.astro).
String registerMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.invalidName => 'Enter a name (maximum 100 characters).',
  AuthFailureReason.invalidEmail => 'Enter a valid email.',
  AuthFailureReason.weakPassword => 'Password must be 12 to 200 characters.',
  AuthFailureReason.emailTaken => 'This email is already registered. Try logging in.',
  AuthFailureReason.captcha => 'Spam check failed. Try again.',
  AuthFailureReason.rateLimited => 'Too many attempts. Wait a minute.',
  AuthFailureReason.network => 'No connection. Check your internet and try again.',
  _ => 'Can\'t sign up right now. Try again shortly.',
};
