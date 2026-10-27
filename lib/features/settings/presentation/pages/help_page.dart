import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = [
    _Faq(
      question: 'How do I import a run?',
      answer:
          'Open Settings → Connect an app or device and follow the prompts. Once connected, your workouts will appear in your activity list.',
    ),
    _Faq(
      question: 'How do I change my training plan?',
      answer:
          'Open Training Plans from Settings or your profile, choose the plan you want, and continue. You can rebuild a 5K plan at any time.',
    ),
    _Faq(
      question: 'How do I cancel my subscription?',
      answer:
          'Subscriptions are managed by the store you used to subscribe. Open your App Store or Google Play subscriptions and cancel from there.',
    ),
    _Faq(
      question: 'How do I delete my account?',
      answer:
          'Go to Settings → Help and contact support. We will verify the request and remove your account and activity data.',
    ),
    _Faq(
      question: 'Why is my activity missing?',
      answer:
          'Check that the source app is connected, the activity has GPS data, and the sync has finished. Pull to refresh your feed after syncing.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text('Popular topics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final faq in _faqs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(faq.question, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.answer,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  const _Faq({required this.question, required this.answer});
  final String question;
  final String answer;
}
