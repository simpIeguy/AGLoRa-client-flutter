import 'package:flutter/material.dart';

import '../../data/tracker_status.dart';
import '../../data/wait_names.dart';
import '../../protocol/tracker_name.dart';
import '../../services/app_services.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/status_dot.dart';
import '../widgets/tracker_card.dart';

/// "Ждать трекер", as in the Wait mockup: a name typed in, or several quick
/// picks at once (UAV4, UAV5, GROUND3 — all ticked, one button). A name of
/// its own only for a single tracker. Waited silently unless the switch
/// says otherwise.
class WaitTrackerScreen extends StatefulWidget {
  const WaitTrackerScreen({super.key});

  @override
  State<WaitTrackerScreen> createState() => _WaitTrackerScreenState();
}

class _WaitTrackerScreenState extends State<WaitTrackerScreen> {
  final _name = TextEditingController();
  final _alias = TextEditingController();

  /// the trackers to wait for, keys in the order picked
  final List<String> _chosen = [];
  bool _notify = false;

  @override
  void dispose() {
    _name.dispose();
    _alias.dispose();
    super.dispose();
  }

  /// typing replaces the picks: the typed name is the one
  void _typed(String text, bool Function(String) isKnown) {
    final name = parseTrackerName(text);
    setState(() {
      _chosen.clear();
      if (name.isKnown && !isKnown(name.key)) _chosen.add(name.key);
    });
  }

  /// a quick pick toggles; with one pick the field shows it
  void _picked(String key) {
    setState(() {
      if (!_chosen.remove(key)) _chosen.add(key);
      _name.text = _chosen.length == 1 ? _chosen.single : '';
    });
  }

  void _wait(BuildContext context) {
    final store = AppScope.of(context).store;
    for (final key in _chosen) {
      store.addWaiting(parseTrackerName(key),
          alias: _chosen.length == 1 ? _alias.text : null, notify: _notify);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final quick = quickWaitNames(store.isKnown);
    final one = _chosen.length == 1;
    final label = textTheme.labelLarge?.copyWith(color: p.muted);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSizes.gap, AppSizes.gap, 0, 0),
            child: Row(children: [
              IconButton(
                tooltip: S.back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSizes.gap),
              Text(S.waitTracker,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                Text(S.trackerName, style: label),
                const SizedBox(height: AppSizes.gap),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      fontFamily: AppText.mono,
                      fontSize: AppText.main,
                      fontWeight: FontWeight.w500),
                  decoration: _field(p),
                  onChanged: (text) => _typed(text, store.isKnown),
                ),
                const SizedBox(height: AppSizes.gap),
                _NameCheck(text: _name.text, chosen: _chosen),
                const SizedBox(height: AppSizes.screenPadding * 1.5),
                Wrap(
                  spacing: AppSizes.gap,
                  runSpacing: AppSizes.gap,
                  children: [
                    for (final q in quick)
                      _QuickPick(
                        name: q.key,
                        taken: q.taken,
                        chosen: _chosen.contains(q.key),
                        onTap: () => _picked(q.key),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.screenPadding * 1.5),
                Text(S.aliasOptional, style: label),
                const SizedBox(height: AppSizes.gap),
                TextField(
                  controller: _alias,
                  enabled: one,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _field(p).copyWith(
                    hintText: S.aliasExample,
                    helperText: one ? null : S.aliasOnlyForOne,
                  ),
                ),
                const SizedBox(height: AppSizes.screenPadding),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.notifyWhenOnAir, style: textTheme.titleMedium),
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
                AppSizes.padding, AppSizes.screenPadding, 24),
            child: FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.bigButton)),
              onPressed: _chosen.isEmpty ? null : () => _wait(context),
              child: Text(_chosen.isEmpty
                  ? S.waitTracker
                  : one
                      ? S.waitFor(displayName(parseTrackerName(_chosen.single)))
                      : S.waitForCount(_chosen.length)),
            ),
          ),
        ]),
      ),
    );
  }

  static InputDecoration _field(AppPalette p) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        borderSide: BorderSide(color: color, width: width));
    return InputDecoration(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding, vertical: AppSizes.screenPadding),
      enabledBorder: border(p.line, AppSizes.outline),
      disabledBorder: border(p.line, AppSizes.outline),
      focusedBorder: border(p.ink, 2),
    );
  }
}

/// under the name field: "● БЛА 4 UAV4", what is wrong, or the picks
class _NameCheck extends StatelessWidget {
  const _NameCheck({required this.text, required this.chosen});

  final String text;
  final List<String> chosen;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    Widget note(String s, {Color? color}) =>
        Text(s, style: textTheme.bodyMedium?.copyWith(color: color ?? p.muted));

    if (chosen.length > 1) return note(S.chosen(chosen));
    if (text.trim().isEmpty) return note(S.waitNameHint);
    final name = parseTrackerName(text);
    final error = Theme.of(context).colorScheme.error;
    if (!name.isKnown) return note(S.notRecognized, color: error);
    if (store.isKnown(name.key)) return note(S.alreadyInList, color: error);
    return Row(children: [
      const StatusDot(status: TrackerStatus.active),
      const SizedBox(width: AppSizes.gap),
      Flexible(child: TrackerTitle(name: parseTrackerName(name.key))),
    ]);
  }
}

/// a quick pick: filled when chosen, dashed and greyed when the tracker is
/// already in the list
class _QuickPick extends StatelessWidget {
  const _QuickPick(
      {required this.name,
      required this.taken,
      required this.chosen,
      required this.onTap});

  final String name;
  final bool taken;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = Text(name,
        style: TextStyle(
            fontFamily: AppText.mono,
            fontSize: AppText.main,
            fontWeight: chosen ? FontWeight.w600 : FontWeight.w500));
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius));
    const padding = EdgeInsets.symmetric(horizontal: AppSizes.screenPadding);

    if (taken) {
      return Semantics(
        label: '$name, ${S.alreadyInList}',
        excludeSemantics: true,
        child: CustomPaint(
          painter: DashedFrame(p.muted, radius: AppSizes.buttonRadius),
          child: Container(
            height: AppSizes.minTap,
            padding: padding,
            // as wide as the name, like the other picks
            child: Center(
              widthFactor: 1,
              child: DefaultTextStyle.merge(
                  style: TextStyle(color: p.muted), child: text),
            ),
          ),
        ),
      );
    }
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.minTap)),
      padding: const WidgetStatePropertyAll(padding),
      shape: WidgetStatePropertyAll(shape),
    );
    return Semantics(
      selected: chosen,
      child: chosen
          ? FilledButton(style: style, onPressed: onTap, child: text)
          : OutlinedButton(style: style, onPressed: onTap, child: text),
    );
  }
}
