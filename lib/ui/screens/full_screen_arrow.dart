import 'package:flutter/material.dart';

import '../../protocol/tracker_name.dart';
import '../../services/app_services.dart';
import '../../util/geo.dart';
import '../format.dart';
import '../names.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/direction_arrow.dart';
import 'tracker_log_screen.dart';

/// A big arrow to the tracker on a black screen: readable in the sun,
/// cheap on AMOLED batteries. A double tap goes back.
class FullScreenArrow extends StatelessWidget {
  const FullScreenArrow({super.key, required this.identifier});

  final String identifier;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.amoledBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              services.store,
              services.location,
              services.compass,
              services.clock,
            ]),
            builder: (context, _) => _content(context, services),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppServices services) {
    final textTheme = Theme.of(context).textTheme;
    final points = services.store.pointsOf(identifier);
    final name = displayName(parseTrackerName(identifier),
        alias: services.store.aliasOf(identifier));
    const text = TextStyle(color: AppColors.amoledText);
    const muted = TextStyle(color: AppColors.amoledMuted);

    if (points.isEmpty) {
      return Center(child: Text(S.noPointsYet, style: textTheme.titleLarge));
    }
    final point = points.first;
    final direction =
        currentDirection(services, point.latitude, point.longitude);
    final problem = directionProblemText(direction.problem);
    final bearing = direction.bearing;

    // on a short screen the arrow shrinks and the rest scrolls
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding * 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSizes.padding * 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: textTheme.headlineMedium?.merge(text),
                  textAlign: TextAlign.center),
              DirectionArrow(
                bearing: bearing,
                reliable: direction.isReliable,
                size: AppSizes.bigArrow
                    .clamp(AppSizes.cardArrow, constraints.maxHeight * 0.4),
                color: AppColors.amoledText,
                mutedColor: AppColors.amoledMuted.withValues(alpha: 0.5),
              ),
              if (problem != null)
                Text(problem,
                    style: textTheme.titleLarge?.merge(muted),
                    textAlign: TextAlign.center),
              if (direction.distance != null)
                Text(formatDistance(direction.distance!),
                    style: textTheme.displayLarge
                        ?.merge(text)
                        .copyWith(fontWeight: FontWeight.bold)),
              if (bearing != null)
                Text('${S.azimuth} ${formatBearing(normalizeDegrees(bearing))}',
                    style: textTheme.headlineSmall?.merge(text)),
              Text(formatAge(services.clock.now.toUtc().difference(point.time)),
                  style: textTheme.titleLarge?.merge(muted)),
              if (services.store.isSearchingSatellites(point.identifier))
                Text(S.noFixLastGoodPoint,
                    style: textTheme.titleLarge?.merge(muted),
                    textAlign: TextAlign.center),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amoledText,
                    side:
                        const BorderSide(color: AppColors.amoledText, width: 2),
                    minimumSize: const Size.fromHeight(AppSizes.minTap * 1.5),
                    textStyle: textTheme.titleLarge,
                  ),
                  icon: const Icon(Icons.copy),
                  label:
                      Text(formatCoordinates(point.latitude, point.longitude)),
                  onPressed: () =>
                      copyCoordinates(context, point.latitude, point.longitude),
                ),
              ),
              const Text(S.exitFullScreen, style: muted),
            ],
          ),
        ),
      ),
    );
  }
}
