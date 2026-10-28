/// Demo scenario file (assets/demo/*.txt), one item per line:
///
///   # comment
///   connected Tracker1             name of the tracker the phone "is on"
///   start 2009-11-27T21:40:09Z     scenario time of the first chunk
///   1500 AGLoRa-point&...\r\n      wait 1500 ms, then send the text
///
/// The text after the delay is sent as written, only `\r` and `\n` become
/// the line breaks the firmware ends its messages with. It may be a whole
/// message, a piece of one or several glued together. Files are made by
/// tool/make_demo_scenarios.dart from a recorded NMEA track.

/// line breaks as `\r` and `\n`, so a message stays on one line of the file
String escapeLineBreaks(String text) =>
    text.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

String unescapeLineBreaks(String text) =>
    text.replaceAll(r'\r', '\r').replaceAll(r'\n', '\n');

class DemoChunk {
  const DemoChunk(this.atMs, this.text);

  /// scenario time, ms from the start
  final int atMs;
  final String text;
}

class DemoScenario {
  const DemoScenario({
    required this.connectedTracker,
    required this.start,
    required this.chunks,
  });

  final String connectedTracker;
  final DateTime start;
  final List<DemoChunk> chunks;

  int get durationMs => chunks.isEmpty ? 0 : chunks.last.atMs;
}

DemoScenario parseDemoScenario(String source) {
  String connectedTracker = 'Tracker1';
  DateTime start = DateTime.utc(2000);
  final chunks = <DemoChunk>[];
  int atMs = 0;

  for (final rawLine in source.split('\n')) {
    final line = rawLine.replaceAll('\r', '');
    if (line.trim().isEmpty || line.startsWith('#')) continue;

    final space = line.indexOf(' ');
    if (space < 0) continue;
    final head = line.substring(0, space);
    final rest = line.substring(space + 1);

    if (head == 'connected') {
      connectedTracker = rest.trim();
    } else if (head == 'start') {
      start = DateTime.parse(rest.trim()).toUtc();
    } else {
      final delay = int.tryParse(head);
      if (delay == null) continue;
      atMs += delay;
      chunks.add(DemoChunk(atMs, unescapeLineBreaks(rest)));
    }
  }

  return DemoScenario(
      connectedTracker: connectedTracker, start: start, chunks: chunks);
}

final RegExp _timestampPattern =
    RegExp(r'timestamp=(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)');

/// the firmware's format, always 20 characters
String formatAgloraTimestamp(DateTime time) {
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
}

/// Moves packet times to the playback moment: a point that was N seconds
/// old when its chunk was due in the scenario is N seconds old when the
/// chunk is played. Works on the joined text, so a timestamp split between
/// two chunks is moved too; the chunk lengths do not change.
List<DemoChunk> shiftScenarioTimes(
    DemoScenario scenario, DateTime playbackStart,
    {double speed = 1}) {
  final chunks = scenario.chunks;
  final joined = StringBuffer();
  final chunkStarts = <int>[];
  for (final chunk in chunks) {
    chunkStarts.add(joined.length);
    joined.write(chunk.text);
  }

  int chunkIndexAt(int position) {
    int index = 0;
    while (
        index + 1 < chunkStarts.length && chunkStarts[index + 1] <= position) {
      index++;
    }
    return index;
  }

  final shifted = joined.toString().replaceAllMapped(_timestampPattern, (m) {
    final packetTime = DateTime.parse(m.group(1)!);
    final dueMs = chunks[chunkIndexAt(m.start)].atMs;
    final age = scenario.start
        .add(Duration(milliseconds: dueMs))
        .difference(packetTime);
    final playedAt = playbackStart.add(Duration(milliseconds: dueMs ~/ speed));
    return 'timestamp=${formatAgloraTimestamp(playedAt.subtract(age))}';
  });

  final result = <DemoChunk>[];
  for (int i = 0; i < chunks.length; i++) {
    final from = chunkStarts[i];
    final to = from + chunks[i].text.length;
    result.add(DemoChunk(chunks[i].atMs, shifted.substring(from, to)));
  }
  return result;
}
