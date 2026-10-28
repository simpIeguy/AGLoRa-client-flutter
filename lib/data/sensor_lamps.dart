/// green, yellow, red, grey lamps in the header
enum LampLevel { good, fair, bad, off }

/// phone GPS better than this, metres: green
const double gpsGoodAccuracy = 15;

/// a fix older than this is stale: yellow at best
const Duration gpsFreshFix = Duration(seconds: 10);

/// Android's compass accuracy, degrees: 15 high, 30 medium, 45 low
const double compassGoodAccuracy = 15;
const double compassFairAccuracy = 30;

/// [accuracy] metres, null when unknown; [fixTime] null without a position
LampLevel gpsLamp({
  required DateTime? fixTime,
  required double? accuracy,
  required DateTime now,
}) {
  if (fixTime == null) return LampLevel.bad;
  final fresh = now.difference(fixTime) <= gpsFreshFix;
  if (fresh && accuracy != null && accuracy <= gpsGoodAccuracy) {
    return LampLevel.good;
  }
  return LampLevel.fair;
}

/// [accuracy] null when the compass gives no estimate
LampLevel compassLamp({
  required bool useCompass,
  required bool hasReading,
  required double? accuracy,
}) {
  if (!useCompass) return LampLevel.off;
  if (!hasReading) return LampLevel.bad;
  if (accuracy == null) return LampLevel.fair;
  if (accuracy <= compassGoodAccuracy) return LampLevel.good;
  if (accuracy <= compassFairAccuracy) return LampLevel.fair;
  return LampLevel.bad;
}
