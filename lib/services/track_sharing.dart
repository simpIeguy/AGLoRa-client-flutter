import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../data/track_export.dart';
import '../util/log.dart';

enum TrackFormat { gpx, csv }

/// Gives the points to the phone's "Share" window as a file: the user picks
/// Telegram, mail, the drive or "save". Not kept anywhere by the app.
Future<void> shareTrack(ExportTrack track, TrackFormat format,
    {required String fileBase}) async {
  final isGpx = format == TrackFormat.gpx;
  final text = isGpx ? tracksToGpx([track]) : tracksToCsv([track]);
  final name = '$fileBase.${isGpx ? 'gpx' : 'csv'}';
  try {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(utf8.encode(text),
            mimeType: isGpx ? 'application/gpx+xml' : 'text/csv', name: name)
      ],
      fileNameOverrides: [name],
    ));
  } catch (e) {
    appLog('share: $e');
    rethrow;
  }
}
