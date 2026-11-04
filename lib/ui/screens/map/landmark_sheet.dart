import 'package:flutter/material.dart';

import '../../../data/landmark.dart';
import '../../../services/app_services.dart';
import '../../../util/coordinate_parser.dart';
import '../../strings.dart';
import '../../theme.dart';
import '../../widgets/coordinates_text.dart';

/// The sheet "Ориентиры": type or paste coordinates in any of the formats,
/// see how they were understood, add them to the map; below, the landmarks
/// already there. [zone] is the 6° zone of the map, for a Y without one.
/// [onShow] is told of the landmark to go to.
Future<void> showLandmarkSheet(BuildContext context,
    {required int zone, required void Function(Landmark) onShow}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LandmarkSheet(zone: zone, onShow: onShow),
  );
}

class _LandmarkSheet extends StatefulWidget {
  const _LandmarkSheet({required this.zone, required this.onShow});

  final int zone;
  final void Function(Landmark) onShow;

  @override
  State<_LandmarkSheet> createState() => _LandmarkSheetState();
}

class _LandmarkSheetState extends State<_LandmarkSheet> {
  final _text = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    super.dispose();
  }

  ParsedCoordinates? get _parsed =>
      parseCoordinates(_text.text, defaultZone: widget.zone);

  String _kind(ParsedCoordinates p) => switch (p.kind) {
        CoordinateKind.decimal => S.kindDecimal,
        CoordinateKind.degreesMinutes => S.kindDegreesMinutes,
        CoordinateKind.degreesMinutesSeconds => S.kindDegreesMinutesSeconds,
        CoordinateKind.gaussKruger => S.kindGaussKruger(p.zone ?? widget.zone),
      };

  void _add(ParsedCoordinates p) {
    final settings = AppScope.of(context).settings;
    final name = _name.text.trim();
    final landmark = settings.addLandmark(
        name.isEmpty
            ? S.landmarkDefaultName(settings.landmarks.length + 1)
            : name,
        p.latitude,
        p.longitude);
    Navigator.of(context).pop();
    widget.onShow(landmark);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final parsed = _parsed;
    final typed = _text.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 0,
              AppSizes.screenPadding, AppSizes.screenPadding),
          children: [
            Text(S.landmarks, style: textTheme.titleMedium),
            const SizedBox(height: AppSizes.padding),
            TextField(
              controller: _text,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                  fontFamily: AppText.mono,
                  fontSize: AppText.main,
                  fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                labelText: S.landmarkCoordinates,
                hintText: S.landmarkCoordinatesHint,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.gap),
            if (typed && parsed == null)
              Text(S.landmarkNotUnderstood,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error))
            else if (parsed != null) ...[
              Text(S.landmarkUnderstoodAs(_kind(parsed)),
                  style: textTheme.bodyMedium?.copyWith(color: p.muted)),
              CoordinatesText(parsed.latitude, parsed.longitude),
              if (parsed.zoneGuessed)
                Text(S.landmarkZoneGuessed,
                    style: textTheme.bodyMedium?.copyWith(color: p.muted)),
            ],
            const SizedBox(height: AppSizes.padding),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: S.landmarkName,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.padding),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.bigButton)),
              onPressed: parsed == null ? null : () => _add(parsed),
              child: const Text(S.landmarkAdd),
            ),
            const SizedBox(height: AppSizes.screenPadding),
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                final landmarks = settings.landmarks;
                if (landmarks.isEmpty) {
                  return Text(S.landmarkListEmpty,
                      style: textTheme.bodyMedium?.copyWith(color: p.muted));
                }
                return Column(children: [
                  for (final l in landmarks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: AppSizes.gap,
                      title: Text(l.name),
                      subtitle: CoordinatesText(l.latitude, l.longitude,
                          style: const TextStyle(fontSize: AppText.small)),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onShow(l);
                      },
                      trailing: IconButton(
                        tooltip: S.landmarkDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => settings.removeLandmark(l.id),
                      ),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
