import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../auth/domain/auth_repository.dart';
import '../auth/presentation/controllers/auth_controller.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
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
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      await _showChanged();
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = passwordMessage(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showChanged() async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    await FamilyModalSheet.showMaterialDefault<void>(
      context: context,
      mainContentBorderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius))),
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Icon(Icons.lock_reset, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Kata laluan ditukar', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Semua sesi telah ditamatkan. Sila log masuk semula dengan kata laluan baru.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('OK')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tukar kata laluan')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _current,
                        decoration: const InputDecoration(labelText: 'Kata laluan semasa'),
                        obscureText: !_show,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.next,
                        enabled: !_busy,
                        validator: (v) => (v == null || v.isEmpty) ? 'Masukkan kata laluan semasa.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _new,
                        decoration: InputDecoration(
                          labelText: 'Kata laluan baru',
                          helperText: '12 hingga 200 aksara, ada huruf besar, huruf kecil dan nombor.',
                          suffixIcon: IconButton(
                            tooltip: _show ? 'Sorok kata laluan' : 'Tunjuk kata laluan',
                            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _show = !_show),
                          ),
                        ),
                        obscureText: !_show,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        enabled: !_busy,
                        validator: (v) {
                          final value = v ?? '';
                          if (value.length < 12 || value.length > 200) {
                            return 'Kata laluan mesti 12 hingga 200 aksara.';
                          }
                          if (!value.contains(RegExp(r'[A-Z]')) ||
                              !value.contains(RegExp(r'[a-z]')) ||
                              !value.contains(RegExp(r'[0-9]'))) {
                            return 'Kata laluan mesti ada huruf besar, huruf kecil dan nombor.';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      _Strength(password: _new.text),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        decoration: const InputDecoration(labelText: 'Ulang kata laluan baru'),
                        obscureText: !_show,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        enabled: !_busy,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => v != _new.text ? 'Kata laluan baru tak sama.' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
                          ),
                          child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Lepas ditukar, semua sesi (di Nubi Sport dan hafizbahtiar.com) ditamatkan - log masuk semula.',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Tukar kata laluan'),
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

class _Strength extends StatelessWidget {
  const _Strength({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strong = theme.brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

    final checks = <({String label, bool ok})>[
      (label: '12+ aksara', ok: password.length >= 12),
      (label: 'Huruf besar', ok: password.contains(RegExp(r'[A-Z]'))),
      (label: 'Huruf kecil', ok: password.contains(RegExp(r'[a-z]'))),
      (label: 'Nombor', ok: password.contains(RegExp(r'[0-9]'))),
    ];
    final met = checks.where((c) => c.ok).length;
    final level = met >= 4 ? 4 : met;
    final color = level >= 4
        ? strong
        : level == 3
        ? scheme.primary
        : scheme.error;
    final label = switch (level) {
      4 => 'Kuat',
      3 => 'Sederhana',
      2 => 'Lemah',
      _ => 'Sangat lemah',
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
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
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
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final check in checks)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      check.ok ? Icons.check_circle : Icons.circle_outlined,
                      size: 13,
                      color: check.ok ? strong : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      check.label,
                      style: theme.textTheme.bodySmall?.copyWith(color: check.ok ? strong : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String passwordMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.wrongPassword => 'Kata laluan semasa salah.',
  AuthFailureReason.weakPassword => 'Kata laluan baru tak cukup syarat.',
  AuthFailureReason.rateLimited => 'Terlalu banyak cubaan. Tunggu seminit.',
  AuthFailureReason.network => 'Tiada sambungan. Semak internet anda dan cuba lagi.',
  _ => 'Tak dapat tukar sekarang. Cuba lagi sekejap.',
};
