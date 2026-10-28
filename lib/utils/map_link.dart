import 'package:url_launcher/url_launcher.dart';

/// "geo:" opens the map app the phone offers (Google Maps and others),
/// the pin is labeled with the tracker's name
Uri geoUri(double latitude, double longitude, String label) {
  final point =
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  return Uri.parse('geo:$point?q=$point(${Uri.encodeComponent(label)})');
}

/// same point as a web link, for phones without a map app
Uri webMapUri(double latitude, double longitude) => Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query':
            '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
      },
    );

/// opens a link outside the app; false when nothing could open it
typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// map app first, the browser as a fallback
Future<bool> openPointInMaps(
  double latitude,
  double longitude,
  String label, {
  UrlOpener open = openExternally,
}) async {
  if (await open(geoUri(latitude, longitude, label))) return true;
  return open(webMapUri(latitude, longitude));
}
