import 'package:flutter/material.dart';

import '../../protocol/tracker_name.dart';
import '../../services/app_services.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';

/// quick picks: the usual names of the group
const List<String> quickTrackerNames = [
  'UAV1', 'UAV2', 'UAV3', 'UAV4', 'UAV5', //
  'GROUND1', 'GROUND2', 'GROUND3', 'GROUND4', 'GROUND5',
];

/// what the name field says under the input
String waitInputHint(String input, bool Function(String key) isKnown) {
  if (input.trim().isEmpty) return S.waitNameHint;
  final name = parseTrackerName(input);
  if (!name.isKnown) return S.notRecognized;
  if (isKnown(name.key)) return S.alreadyInList;
  return S.recognized(name.key, displayName(name));
}

Future<void> showWaitTrackerDialog(BuildContext context) => showDialog<void>(
    context: context, builder: (_) => const _WaitTrackerDialog());

class _WaitTrackerDialog extends StatefulWidget {
  const _WaitTrackerDialog();

  @override
  State<_WaitTrackerDialog> createState() => _WaitTrackerDialogState();
}

class _WaitTrackerDialogState extends State<_WaitTrackerDialog> {
  final _name = TextEditingController();
  final _alias = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final name = parseTrackerName(_name.text);
    final canAdd = name.isKnown && !store.isKnown(name.key);
    final hint = waitInputHint(_name.text, store.isKnown);
    final hintColor = _name.text.trim().isEmpty || canAdd
        ? null
        : Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: const Text(S.waitTracker),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                helperText: hint,
                helperMaxLines: 3,
                helperStyle: TextStyle(color: hintColor),
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            Wrap(
              spacing: AppSizes.gap,
              runSpacing: AppSizes.gap,
              children: [
                for (final quick in quickTrackerNames)
                  _quickChip(quick, store.isKnown(quick)),
              ],
            ),
            const SizedBox(height: AppSizes.gap),
            TextField(
              controller: _alias,
              decoration: const InputDecoration(labelText: S.aliasOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(S.cancel)),
        FilledButton(
          onPressed: canAdd
              ? () {
                  store.addWaiting(name, alias: _alias.text);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text(S.add),
        ),
      ],
    );
  }

  /// trackers already in the list are greyed out
  Widget _quickChip(String quick, bool known) => ChoiceChip(
        label: Text(quick),
        selected: parseTrackerName(_name.text).key == quick,
        onSelected: known
            ? null
            : (_) => setState(() {
                  _name.text = quick;
                }),
      );
}
