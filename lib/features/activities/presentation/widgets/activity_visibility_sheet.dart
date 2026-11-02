import 'package:flutter/material.dart';

import '../../../../shared/widgets/family_bottom_sheet/family_modal_sheet.dart';
import '../../domain/models/activity.dart';

/// Who can see the owner's activity - same three levels as the web activity page.
/// [onSave] does the request; it throws on failure and the sheet stays open with a message.
Future<void> showActivityVisibilitySheet(
  BuildContext context,
  Activity activity, {
  required Future<void> Function(ActivityVisibility visibility, bool shareHr)
  onSave,
}) {
  return FamilyModalSheet.show<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _VisibilitySheet(activity: activity, onSave: onSave),
  );
}

String visibilityLabel(ActivityVisibility v) => switch (v) {
  ActivityVisibility.private => 'Only me',
  ActivityVisibility.members => 'Nubi members',
  ActivityVisibility.public => 'Public link',
};

class _VisibilitySheet extends StatefulWidget {
  const _VisibilitySheet({required this.activity, required this.onSave});
  final Activity activity;
  final Future<void> Function(ActivityVisibility visibility, bool shareHr)
  onSave;

  @override
  State<_VisibilitySheet> createState() => _VisibilitySheetState();
}

class _VisibilitySheetState extends State<_VisibilitySheet> {
  late ActivityVisibility _choice =
      widget.activity.visibility ?? ActivityVisibility.private;
  late bool _shareHr = widget.activity.shareHr;
  bool _saving = false;
  String? _error;

  static const _hints = {
    ActivityVisibility.private: 'Nobody else sees it. Removes its kudos.',
    ActivityVisibility.members:
        'In the members\' feed: full route, splits, pace and weather.',
    ActivityVisibility.public:
        'Members, plus anyone with the link: summary and map without the first and last 200 m.',
  };

  Future<void> _save() async {
    setState(() => (_saving = true, _error = null));
    try {
      await widget.onSave(
        _choice,
        _choice != ActivityVisibility.private && _shareHr,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => (
            _saving = false,
            _error = 'Couldn\'t change sharing. Try again.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shared = _choice != ActivityVisibility.private;
    // The sheet paints a coloured box; the tiles need their own Material for the tap ripple.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Who can see this activity',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            RadioGroup<ActivityVisibility>(
              groupValue: _choice,
              onChanged: (v) {
                if (!_saving && v != null) setState(() => _choice = v);
              },
              child: Column(
                children: [
                  for (final v in ActivityVisibility.values)
                    RadioListTile<ActivityVisibility>(
                      value: v,
                      contentPadding: EdgeInsets.zero,
                      title: Text(visibilityLabel(v)),
                      subtitle: Text(_hints[v]!),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share heart rate'),
              value: shared && _shareHr,
              onChanged: shared && !_saving
                  ? (v) => setState(() => _shareHr = v)
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
