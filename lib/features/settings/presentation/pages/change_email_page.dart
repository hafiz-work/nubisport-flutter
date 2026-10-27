import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key, this.currentEmail = ''});
  final String currentEmail;

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    final email = _emailController.text.trim();
    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!validEmail) {
      setState(() {
        _emailError = 'Enter a valid email address.';
        _passwordError = null;
      });
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _emailError = null;
        _passwordError = 'Enter your current password.';
      });
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Verification link sent to $email.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Email')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'We\'ll send a verification link to the new address. Your current email stays active until it is confirmed.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current email', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      widget.currentEmail.isEmpty ? '—' : widget.currentEmail,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('New email', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(hintText: 'name@example.com', errorText: _emailError),
            ),
            const SizedBox(height: 16),
            Text('Current password', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: 'Password', errorText: _passwordError),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                child: const Text('Send verification link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
