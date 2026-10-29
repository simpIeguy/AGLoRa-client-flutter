import 'package:flutter/material.dart';

import '../../services/app_services.dart';
import '../strings.dart';
import '../theme.dart';

/// The Settings mockup. For now only the theme; the rest of the mockup
/// comes with the settings screen step of the design.
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
    final settings = AppScope.of(context).settings;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Text(S.sectionLook,
                style: textTheme.labelLarge?.copyWith(color: p.muted)),
            const SizedBox(height: AppSizes.gap),
            Text(S.theme, style: textTheme.titleMedium),
            const SizedBox(height: AppSizes.gap),
            SegmentedButton<AppThemeChoice>(
              showSelectedIcon: false,
              segments: [
                for (final e in _themes.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {settings.theme},
              onSelectionChanged: (choice) => settings.theme = choice.single,
            ),
            const SizedBox(height: AppSizes.gap),
            Text(S.themeNightHint,
                style: textTheme.bodyMedium?.copyWith(color: p.muted)),
          ],
        ),
      ),
    );
  }
}
