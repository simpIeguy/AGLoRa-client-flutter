import 'package:flutter/material.dart';

import '../../data/tracker_status.dart';
import '../../services/app_services.dart';
import '../format.dart';
import '../strings.dart';
import '../theme.dart';
import 'tracker_screen.dart';

/// The Settings mockup without the language (the app is in Russian only)
/// and without "Слежение при выключенном экране", which comes with the
/// background service (plan step 8).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _themes = {
    AppThemeChoice.auto: S.themeAuto,
    AppThemeChoice.light: S.themeLight,
    AppThemeChoice.dark: S.themeDark,
    AppThemeChoice.night: S.themeNight,
  };

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final settings = services.settings;
    final store = services.store;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: p.muted);

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
              Text(S.settings,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([settings, store]),
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding,
                    AppSizes.gap, AppSizes.screenPadding, 24),
                children: [
                  const _Section(S.sectionLook, first: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSizes.gap),
                    child: Text(S.theme, style: textTheme.titleMedium),
                  ),
                  SizedBox(
                    height: AppSizes.minTap,
                    child: SegmentedButton<AppThemeChoice>(
                      showSelectedIcon: false,
                      segments: [
                        for (final e in _themes.entries)
                          ButtonSegment(value: e.key, label: Text(e.value)),
                      ],
                      selected: {settings.theme},
                      onSelectionChanged: (choice) =>
                          settings.theme = choice.single,
                    ),
                  ),
                  _Hint(S.themeNightHint, style: muted),
                  const _Section(S.sectionCoordinates),
                  _Group(children: [
                    for (final format in CoordinateFormat.values)
                      _CoordinatesChoice(
                        format: format,
                        chosen: settings.coordinates == format,
                        onTap: () => settings.coordinates = format,
                      ),
                  ]),
                  const _Section(S.sectionNotifications),
                  _Group(children: [
                    _Switch(
                      title: S.everyNewUav,
                      hint: S.everyNewUavHint,
                      value: store.alertNewUavs,
                      onChanged: (v) => store.alertNewUavs = v,
                    ),
                  ]),
                  const _Section(S.sectionLink),
                  _Group(children: [
                    _Threshold(
                      title: S.fadingAfter,
                      value: store.fadingAfter,
                      choices: fadingAfterChoices,
                      // a choice not shorter than "потеряна" would mix them up
                      allowed: (d) => d < store.lostAfter,
                      onChosen: (d) => store.setThresholds(fadingAfter: d),
                    ),
                    _Threshold(
                      title: S.lostAfter,
                      value: store.lostAfter,
                      choices: lostAfterChoices,
                      allowed: (d) => d > store.fadingAfter,
                      onChosen: (d) => store.setThresholds(lostAfter: d),
                    ),
                  ]),
                  _Hint(S.thresholdsHint, style: muted),
                  const _Section(S.sectionScreen),
                  _Group(children: [
                    _Switch(
                      title: S.keepScreenOn,
                      hint: S.keepScreenOnHint,
                      value: settings.keepScreenOn,
                      onChanged: (v) => settings.keepScreenOn = v,
                    ),
                  ]),
                  const _Section(S.sectionData),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSizes.bigButton),
                        textStyle: const TextStyle(
                            fontFamily: AppText.sans,
                            fontSize: AppText.main,
                            fontWeight: FontWeight.w600)),
                    onPressed: () => _clear(context),
                    child: const Text(S.clearMemory),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 32, 4, 0),
                    child: Text(S.about, style: muted),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final store = AppScope.of(context).store;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.clearMemoryQuestion),
        content: const Text(S.clearMemoryHint),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(S.cancel)),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(S.delete)),
        ],
      ),
    );
    if (yes != true) return;
    store.clearTrackers();
    if (context.mounted) showMessage(context, S.memoryCleared);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, first ? 16 : 32, 4, AppSizes.gap),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppPalette.of(context).muted)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSizes.gap, 4, 0),
        child: Text(text, style: style),
      );
}

/// rows in one card, lines between them
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, color: p.line),
          children[i],
        ],
      ]),
    );
  }
}

class _CoordinatesChoice extends StatelessWidget {
  const _CoordinatesChoice(
      {required this.format, required this.chosen, required this.onTap});

  final CoordinateFormat format;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding, vertical: AppSizes.gap),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: chosen ? p.ink : p.muted, width: 2)),
              child: chosen
                  ? Center(
                      child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: p.ink, shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: AppSizes.padding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // the example: where a UAV fell in Minsk, written both ways
                  Text(formatCoordinates(53.90228, 27.56183, format),
                      style: const TextStyle(
                          fontFamily: AppText.mono,
                          fontSize: AppText.main,
                          fontWeight: FontWeight.w500)),
                  Text(
                      format == CoordinateFormat.decimal
                          ? S.coordinatesDecimal
                          : S.coordinatesDms,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: p.muted)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(
      {required this.title,
      required this.hint,
      required this.value,
      required this.onChanged});

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding, AppSizes.gap, AppSizes.gap, AppSizes.gap),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(hint,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppPalette.of(context).muted)),
        value: value,
        onChanged: onChanged,
      );
}

/// "Связь пропадает после ... 1 мин"; a tap opens the choices
class _Threshold extends StatelessWidget {
  const _Threshold({
    required this.title,
    required this.value,
    required this.choices,
    required this.allowed,
    required this.onChosen,
  });

  final String title;
  final Duration value;
  final List<Duration> choices;
  final bool Function(Duration) allowed;
  final ValueChanged<Duration> onChosen;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return InkWell(
      onTap: () => _choose(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
        child: Row(children: [
          Expanded(child: Text(title, style: style)),
          const SizedBox(width: AppSizes.screenPadding),
          Text(formatDuration(value),
              style: style?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final chosen = await showDialog<Duration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final d in choices)
            ListTile(
              enabled: allowed(d),
              leading: Icon(d == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(formatDuration(d)),
              onTap: () => Navigator.of(context).pop(d),
            ),
        ],
      ),
    );
    if (chosen != null) onChosen(chosen);
  }
}
