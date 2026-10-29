import 'package:flutter/widgets.dart';

import '../../services/app_services.dart';
import '../format.dart';
import '../theme.dart';

/// "53.90228, 27.56183" or "53°54′08″N 27°33′42″E", as the settings say;
/// digits of equal width
class CoordinatesText extends StatelessWidget {
  const CoordinatesText(this.latitude, this.longitude, {super.key, this.style});

  final double latitude;
  final double longitude;

  /// over the default: Mono, the main size
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Text(
          formatCoordinates(latitude, longitude, settings.coordinates),
          style: const TextStyle(
              fontFamily: AppText.mono,
              fontSize: AppText.main,
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()]).merge(style)),
    );
  }
}
