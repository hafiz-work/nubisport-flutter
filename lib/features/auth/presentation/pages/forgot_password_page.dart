import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/brand.dart';
import '../../domain/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_box.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
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
      await ref.read(authControllerProvider.notifier).forgotPassword(email: _email.text.trim());
      if (mounted) setState(() => _done = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = forgotPasswordMessage(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _done
                    ? _ResetSent(onBack: () => Navigator.of(context).pop())
                    : AutofillGroup(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: BrandCrest(size: 100)),
                              const SizedBox(height: 24),
                              Text(
                                'Forgot password',
                                style: theme.textTheme.headlineLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter your account email. If the account exists, we\'ll send a reset link to that email.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'Email', counterText: ''),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enabled: !_busy,
                                maxLength: 255,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  return (!value.contains('@') || value.length > 255) ? 'Enter a valid email.' : null;
                                },
                              ),
                              if (_error != null) ...[const SizedBox(height: 16), AuthErrorBox(message: _error!)],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : const Text('Send reset link'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                                child: const Text('Remember your password? Log in'),
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

class _ResetSent extends StatelessWidget {
  const _ResetSent({required this.onBack});
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
          'If this email has an account, a reset link is on its way. '
          'Check your inbox and spam folder. The link is valid for 1 hour.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: onBack, child: const Text('Back to log in')),
      ],
    );
  }
}

/// Same wording as the web forgot-password page (nubisport-astro src/pages/forgot-password.astro).
String forgotPasswordMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.invalidEmail => 'Enter a valid email.',
  AuthFailureReason.rateLimited => 'Too many attempts. Wait a minute.',
  AuthFailureReason.network => 'No connection. Check your internet and try again.',
  _ => 'Can\'t send right now. Try again shortly.',
};
