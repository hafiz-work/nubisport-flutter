import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/brand.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';

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
      await ref
          .read(authControllerProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = loginMessage(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
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
                      Text(
                        'Log masuk',
                        style: theme.textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pelan, aktiviti dan larian kumpulan anda.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-mel'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        autocorrect: false,
                        enabled: !_busy,
                        validator: (v) => (v == null || !v.trim().contains('@'))
                            ? 'Masukkan e-mel yang sah.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: 'Kata laluan',
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Sorok kata laluan'
                                : 'Tunjuk kata laluan',
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_busy,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Masukkan kata laluan.'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBox(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Log masuk'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada akaun atau lupa kata laluan? Guna nubisport.hafizbahtiar.com.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}

/// Same wording as the web login (nubisport-astro src/pages/login.astro).
String loginMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.invalidCredentials => 'E-mel atau kata laluan salah.',
  AuthFailureReason.emailUnverified =>
    'Sahkan e-mel anda dulu - semak peti masuk untuk pautan pengesahan.',
  AuthFailureReason.banned => 'Akaun ini disekat. Hubungi pentadbir Nubi.',
  AuthFailureReason.captcha =>
    'Semakan spam gagal. Log masuk dari aplikasi belum dibuka untuk pelayan ini.',
  AuthFailureReason.rateLimited => 'Terlalu banyak cubaan. Tunggu seminit.',
  AuthFailureReason.network =>
    'Tiada sambungan. Semak internet anda dan cuba lagi.',
  AuthFailureReason.unknown =>
    'Tak dapat log masuk sekarang. Cuba lagi sekejap.',
};
