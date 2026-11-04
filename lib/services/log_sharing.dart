import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../util/log.dart';

/// Gives the journal to the phone's "Share" window as a text file: the user
/// picks Telegram, mail or "save". Nothing is sent by the app itself.
Future<void> shareLog([AppLog? log]) async {
  final journal = log ?? AppLog.instance;
  await journal.flush();
  final t = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final name = 'poisk-bla-journal-${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}.txt';
  try {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(utf8.encode(journal.text),
            mimeType: 'text/plain', name: name)
      ],
      fileNameOverrides: [name],
    ));
  } catch (e) {
    appLog('share: $e');
    rethrow;
  }
}
