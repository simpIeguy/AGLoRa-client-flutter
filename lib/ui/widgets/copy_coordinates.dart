import 'package:flutter/material.dart';

import '../../services/app_services.dart';
import '../../util/sk42.dart';
import '../format.dart';
import '../screens/tracker_screen.dart';
import '../strings.dart';
import '../theme.dart';

/// The copy button: a tap copies in WGS 84, a long press offers WGS 84 or
/// СК-42. Not an [IconButton]: that one shows its tooltip on a long press.
class CopyCoordinatesButton extends StatelessWidget {
  const CopyCoordinatesButton({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.tooltip,
  });

  final double latitude;
  final double longitude;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.manual,
        child: Semantics(
          button: true,
          label: tooltip,
          child: InkResponse(
            onTap: () => copyCoordinates(context, latitude, longitude),
            onLongPress: () => showCopyFormats(context, latitude, longitude),
            radius: AppSizes.minTap / 2,
            child: const SizedBox.square(
                dimension: AppSizes.minTap, child: Icon(Icons.copy_outlined)),
          ),
        ),
      );
}

/// "Copy as": WGS 84 or СК-42, each with the text it would copy
Future<void> showCopyFormats(
    BuildContext context, double latitude, double longitude) {
  final format = AppScope.of(context).settings.coordinates;
  final sk = wgs84ToGaussKruger(latitude, longitude);
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            title:
                Text(S.copyAs, style: Theme.of(sheet).textTheme.titleMedium)),
        ListTile(
          title: const Text(S.datumWgs84),
          subtitle: Text(formatCoordinates(latitude, longitude, format)),
          onTap: () {
            Navigator.of(sheet).pop();
            copyCoordinates(context, latitude, longitude);
          },
        ),
        ListTile(
          title: const Text(S.datumSk42),
          subtitle: Text(formatGaussKruger(sk)),
          onTap: () {
            Navigator.of(sheet).pop();
            copyCoordinates(context, latitude, longitude, sk42: true);
          },
        ),
      ]),
    ),
  );
}
