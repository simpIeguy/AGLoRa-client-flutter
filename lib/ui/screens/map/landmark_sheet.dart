import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/landmark.dart';
import '../../../services/app_services.dart';
import '../../../services/app_settings.dart';
import '../../../util/coordinate_parser.dart';
import '../../../util/geo.dart';
import '../../format.dart';
import '../../strings.dart';
import '../../theme.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/coordinates_text.dart';

/// The sheet "Метки": the landmarks already there (nearest first, with the
/// distance and direction), and a button to add one by coordinates in any of
/// the formats. [zone] is the 6° zone of the map, for a Y without one.
/// [onShow] is told of a landmark just added (the map goes to it and the line
/// leads to it), [onGo] of one picked in the list (the map goes to it),
/// [onAim] of the "lead to" button. [aimedId] is the landmark the line leads
/// to now.
Future<void> showLandmarkSheet(BuildContext context,
    {required int zone,
    required void Function(Landmark) onShow,
    required void Function(Landmark) onGo,
    required bool Function(Landmark) onAim,
    int? aimedId}) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LandmarkSheet(
        zone: zone, onShow: onShow, onGo: onGo, onAim: onAim, aimedId: aimedId),
  );
}

class _LandmarkSheet extends StatefulWidget {
  const _LandmarkSheet({
    required this.zone,
    required this.onShow,
    required this.onGo,
    required this.onAim,
    required this.aimedId,
  });

  final int zone;
  final void Function(Landmark) onShow;
  final void Function(Landmark) onGo;
  final bool Function(Landmark) onAim;
  final int? aimedId;

  @override
  State<_LandmarkSheet> createState() => _LandmarkSheetState();
}

class _LandmarkSheetState extends State<_LandmarkSheet> {
  final _text = TextEditingController();
  final _name = TextEditingController();
  late int? _aimed = widget.aimedId;
  bool _adding = false;

  // the landmark just swiped away, to bring it back
  ({Landmark landmark, int index})? _removed;
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
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

  /// "Метка N" with the first N nobody uses yet
  String _freeName(AppSettings settings) {
    final taken = settings.landmarks.map((l) => l.name.toLowerCase()).toSet();
    var n = settings.landmarks.length + 1;
    while (taken.contains(S.landmarkDefaultName(n).toLowerCase())) {
      n++;
    }
    return S.landmarkDefaultName(n);
  }

  /// why this one cannot be added: the same place or the same name is there;
  /// [except] is the landmark being edited
  String? _duplicate(AppSettings settings, ParsedCoordinates p, String name,
      {int? except}) {
    final lower = name.trim().toLowerCase();
    for (final l in settings.landmarks) {
      if (l.id == except) continue;
      if ((l.latitude - p.latitude).abs() < 1e-6 &&
          (l.longitude - p.longitude).abs() < 1e-6) {
        return S.landmarkSamePlace(l.name);
      }
      if (lower.isNotEmpty && l.name.toLowerCase() == lower) {
        return S.landmarkSameName;
      }
    }
    return null;
  }

  void _add(ParsedCoordinates p) {
    final settings = AppScope.of(context).settings;
    final name = _name.text.trim();
    final landmark = settings.addLandmark(
        name.isEmpty ? _freeName(settings) : name, p.latitude, p.longitude);
    Navigator.of(context).pop();
    widget.onShow(landmark);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => _text.text = (data?.text ?? '').trim());
  }

  void _remove(Landmark l, int index) {
    final settings = AppScope.of(context).settings;
    settings.removeLandmark(l.id);
    _undoTimer?.cancel();
    setState(() => _removed = (landmark: l, index: index));
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _removed = null);
    });
  }

  void _undo() {
    final r = _removed;
    if (r == null) return;
    AppScope.of(context).settings.restoreLandmark(r.landmark, r.index);
    _undoTimer?.cancel();
    setState(() => _removed = null);
  }

  Future<void> _edit(Landmark l) async {
    final settings = AppScope.of(context).settings;
    await showDialog<void>(
      context: context,
      builder: (_) => _EditDialog(
          landmark: l,
          zone: widget.zone,
          duplicate: (p, name) => _duplicate(settings, p, name, except: l.id),
          onSave: (name, p) =>
              settings.updateLandmark(l.id, name, p.latitude, p.longitude)),
    );
  }

  /// the landmarks, nearest first when the phone knows where it is
  List<({Landmark landmark, double? distance, double? bearing})> _rows(
      AppServices services) {
    final phone = services.location.position;
    final rows = [
      for (final l in services.settings.landmarks)
        (
          landmark: l,
          distance: phone == null
              ? null
              : distanceBetween(
                  phone.latitude, phone.longitude, l.latitude, l.longitude),
          bearing: phone == null
              ? null
              : bearingBetween(
                  phone.latitude, phone.longitude, l.latitude, l.longitude),
        )
    ];
    if (phone != null) {
      rows.sort((a, b) => a.distance!.compareTo(b.distance!));
    }
    return rows;
  }

  Widget _form(BuildContext context, AppSettings settings) {
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    final parsed = _parsed;
    final typed = _text.text.trim().isNotEmpty;
    final duplicate =
        parsed == null ? null : _duplicate(settings, parsed, _name.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _paste,
          icon: const Icon(Icons.content_paste),
          label: const Text(S.landmarkPaste),
        ),
      ),
      if (typed && parsed == null)
        Text(S.landmarkNotUnderstood,
            style: textTheme.bodyMedium?.copyWith(color: error))
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
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: S.landmarkName,
          border: OutlineInputBorder(),
        ),
      ),
      if (duplicate != null) ...[
        const SizedBox(height: AppSizes.gap),
        Text(duplicate, style: textTheme.bodyMedium?.copyWith(color: error)),
      ],
      const SizedBox(height: AppSizes.padding),
      FilledButton(
        style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.bigButton)),
        onPressed:
            parsed == null || duplicate != null ? null : () => _add(parsed),
        child: const Text(S.landmarkAdd),
      ),
    ]);
  }

  Widget _row(BuildContext context, AppSettings settings,
      ({Landmark landmark, double? distance, double? bearing}) row, int index) {
    final p = AppPalette.of(context);
    final l = row.landmark;
    final aimed = _aimed == l.id;
    final far = row.distance == null
        ? null
        : '${formatDistance(row.distance!)} · ${compassPoint(row.bearing!)}';
    return Dismissible(
      key: ValueKey('landmark-${l.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSizes.screenPadding),
        child: Icon(Icons.delete_outline,
            semanticLabel: S.landmarkDelete,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => _remove(l, index),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: AppSizes.gap,
        leading: IconButton(
          tooltip: l.visible ? S.landmarkHide : S.landmarkUnhide,
          icon: Icon(l.visible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => settings.setLandmarkVisible(l.id, !l.visible),
        ),
        title: Text(far == null ? l.name : '${l.name}  ·  $far',
            style: l.visible ? null : TextStyle(color: p.muted)),
        subtitle: CoordinatesText(l.latitude, l.longitude,
            style: const TextStyle(fontSize: AppText.small)),
        onTap: () {
          Navigator.of(context).pop();
          widget.onGo(l);
        },
        onLongPress: () => _edit(l),
        trailing: IconButton(
          tooltip: aimed ? S.landmarkAimOff : S.landmarkAim,
          isSelected: aimed,
          icon: const Icon(Icons.navigation_outlined),
          selectedIcon: const Icon(Icons.navigation),
          onPressed: () {
            final on = widget.onAim(l);
            setState(() => _aimed = on ? l.id : null);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final settings = services.settings;
    final p = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 0,
              AppSizes.screenPadding, AppSizes.screenPadding),
          children: [
            Text(S.landmarks, style: textTheme.titleMedium),
            const SizedBox(height: AppSizes.gap),
            if (_adding)
              _form(context, settings)
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.bigButton)),
                onPressed: () => setState(() => _adding = true),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text(S.landmarkNew),
              ),
            const SizedBox(height: AppSizes.padding),
            if (_removed != null)
              Row(children: [
                Expanded(
                    child: Text(S.landmarkRemoved(_removed!.landmark.name),
                        style: textTheme.bodyMedium)),
                TextButton(onPressed: _undo, child: const Text(S.landmarkUndo)),
              ]),
            ListenableBuilder(
              listenable: Listenable.merge([settings, services.location]),
              builder: (context, _) {
                final rows = _rows(services);
                if (rows.isEmpty) {
                  return Text(S.landmarkListEmpty,
                      style: textTheme.bodyMedium?.copyWith(color: p.muted));
                }
                final allShown = rows.every((r) => r.landmark.visible);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(S.landmarkSwipeHint,
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: p.muted))),
                        TextButton(
                          onPressed: () =>
                              settings.setAllLandmarksVisible(!allShown),
                          child: Text(
                              allShown ? S.landmarkHideAll : S.landmarkShowAll),
                        ),
                      ]),
                      for (var i = 0; i < rows.length; i++)
                        _row(context, settings, rows[i], i),
                    ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// change the name and the coordinates of one landmark
class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.landmark,
    required this.zone,
    required this.duplicate,
    required this.onSave,
  });

  final Landmark landmark;
  final int zone;
  final String? Function(ParsedCoordinates, String) duplicate;
  final void Function(String, ParsedCoordinates) onSave;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _name = TextEditingController(text: widget.landmark.name);
  late final _text = TextEditingController(
      text: '${widget.landmark.latitude.toStringAsFixed(6)}, '
          '${widget.landmark.longitude.toStringAsFixed(6)}');

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseCoordinates(_text.text, defaultZone: widget.zone);
    final name = _name.text.trim();
    final problem = parsed == null
        ? S.landmarkNotUnderstood
        : (name.isEmpty ? null : widget.duplicate(parsed, name)) ??
            (name.isEmpty ? S.landmarkName : null);
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text(S.landmarkEdit),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: S.landmarkNameShort, border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.padding),
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
                labelText: S.landmarkCoordinates, border: OutlineInputBorder()),
          ),
          if (problem != null && name.isNotEmpty) ...[
            const SizedBox(height: AppSizes.gap),
            Text(problem,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: error)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(S.landmarkCancel)),
        FilledButton(
          onPressed: parsed == null || problem != null
              ? null
              : () {
                  widget.onSave(name, parsed);
                  Navigator.of(context).pop();
                },
          child: const Text(S.landmarkSave),
        ),
      ],
    );
  }
}
