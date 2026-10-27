import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 12) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() => _error = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Verification code sent to your new number.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Number')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'We\'ll send a verification code to your new number before making the change.',
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
                    Text('Current number', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('••••••••0074', style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('New number', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: '12 345 6789', prefixText: '+60 ', errorText: _error),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
                child: const Text('Save number'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
