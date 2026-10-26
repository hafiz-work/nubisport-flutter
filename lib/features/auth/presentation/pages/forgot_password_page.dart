import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/brand.dart';
import '../../domain/auth_repository.dart';
import '../controllers/auth_controller.dart';

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
      appBar: AppBar(title: const Text('Lupa kata laluan')),
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
                                'Lupa kata laluan',
                                style: theme.textTheme.headlineLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Masukkan e-mel akaun anda. Kalau akaun itu wujud, kami hantar pautan reset ke e-mel itu.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'E-mel', counterText: ''),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enabled: !_busy,
                                maxLength: 255,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  return (!value.contains('@') || value.length > 255)
                                      ? 'Masukkan e-mel yang sah.'
                                      : null;
                                },
                              ),
                              if (_error != null) ...[const SizedBox(height: 16), _ErrorBox(message: _error!)],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : const Text('Hantar pautan reset'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                                child: const Text('Ingat kata laluan? Log masuk'),
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
        Text('Semak e-mel anda', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Kalau e-mel ini ada akaun, pautan reset sedang dihantar. '
          'Semak peti masuk dan folder spam. Pautan sah 1 jam.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: onBack, child: const Text('Kembali ke log masuk')),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}

/// Same wording as the web forgot-password page (nubisport-astro src/pages/forgot-password.astro).
String forgotPasswordMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.invalidEmail => 'Masukkan e-mel yang sah.',
  AuthFailureReason.rateLimited => 'Terlalu banyak cubaan. Tunggu seminit.',
  AuthFailureReason.network => 'Tiada sambungan. Semak internet anda dan cuba lagi.',
  _ => 'Tak dapat hantar sekarang. Cuba lagi sekejap.',
};
