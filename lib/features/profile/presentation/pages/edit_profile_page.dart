import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, required this.user});
  final AppUser user;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _username = TextEditingController(text: widget.user.username);
  late final _location = TextEditingController(text: widget.user.location);
  late final _bio = TextEditingController(text: widget.user.bio);
  late bool _public = widget.user.profilePublic;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  String? _validateUsername(String value) {
    final handle = value.trim();
    if (handle.isEmpty) return _public ? 'Set a username before making your profile public.' : null;
    if (handle.length < 3 || handle.length > 30 || !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(handle)) {
      return 'Username must be 3-30 lowercase letters, numbers or single hyphens.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            location: _location.text.trim(),
            bio: _bio.text.trim(),
            profilePublic: _public,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = profileMessage(e.reason));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name', counterText: ''),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      maxLength: 100,
                      enabled: !_busy,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        return value.isEmpty ? 'Enter a name.' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: widget.user.email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'Login email cannot be changed.',
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        helperText: '3-30 lowercase letters, numbers or single hyphens. Required for a public profile.',
                        counterText: '',
                      ),
                      autocorrect: false,
                      enabled: !_busy,
                      maxLength: 30,
                      validator: (v) => _validateUsername(v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        helperText: 'Example: Shah Alam, Selangor.',
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_busy,
                      maxLength: 100,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bio,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        helperText: 'Maximum 1,000 characters.',
                        counterText: '',
                        alignLabelWithHint: true,
                      ),
                      minLines: 3,
                      maxLines: 5,
                      enabled: !_busy,
                      maxLength: 1000,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: _public,
                      onChanged: _busy ? null : (value) => setState(() => _public = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Public profile'),
                      subtitle: const Text('Visible to anyone with the /u/username link. Private by default.'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
                            )
                          : const Text('Save'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String profileMessage(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.usernameTaken => 'This username is taken. Choose another.',
  AuthFailureReason.usernameRequired => 'Set a username before making your profile public.',
  AuthFailureReason.invalidUsername => 'Username must be 3-30 lowercase letters, numbers or single hyphens.',
  AuthFailureReason.invalidName => 'Enter a name (maximum 100 characters).',
  AuthFailureReason.rateLimited => 'Too many attempts. Wait a minute.',
  AuthFailureReason.network => 'No connection. Check your internet and try again.',
  _ => 'Can\'t save right now. Try again shortly.',
};
