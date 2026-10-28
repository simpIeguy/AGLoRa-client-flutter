import 'protocol.dart';

/// Glues BLE chunks (20 bytes each from the firmware) into whole messages.
/// An unfinished message stays in the buffer until its terminator comes.
class MessageBuffer {
  /// the buffer never grows above this, bytes
  static const int maxLength = 520;

  String _buffer = '';
  String _previousChunk = '';

  /// drop buffered data, so a new link starts clean
  void reset() {
    _buffer = '';
    _previousChunk = '';
  }

  /// adds a chunk, returns the messages it completed, without the prefix and
  /// the terminator: `point&ver=2.3&name=…`
  List<String> add(List<int> chunk) {
    final text = String.fromCharCodes(chunk);

    if (_buffer.length > maxLength) {
      // keep the tail: an unfinished message is always at the end
      _buffer = _buffer.substring(_buffer.length - maxLength);
    }

    // a chunk equal to the previous one is taken for a repeated notification
    // and skipped (see docs/audit.md, it is kept as it was)
    if (text != _previousChunk) {
      _buffer += text;
      _previousChunk = text;
    }

    final (messages, rest) = splitMessages(_buffer);
    _buffer = rest;
    return messages;
  }
}

/// whole messages of [stream] and the unfinished tail to keep
(List<String>, String) splitMessages(String stream) {
  final messages = <String>[];
  String rest = '';

  final parts = stream.split(messagePrefix);
  for (int i = 0; i < parts.length; i++) {
    final part = parts[i].trim();
    if (part.endsWith(messageTerminator)) {
      final message = part.substring(0, part.length - messageTerminator.length);
      if (message.isNotEmpty) messages.add(message);
    } else if (i == parts.length - 1 && i > 0) {
      // the last message may not be complete yet: wait for the rest, so
      // a point is not stored with a cut timestamp and without its sensors
      rest = messagePrefix + part;
    } else if (i == 0 && parts.length == 1) {
      // no prefix at all: noise, but its end may be the start of a prefix
      // cut between two chunks ("…AGLo" + "Ra-point…")
      rest = _prefixStartAtEnd(stream);
    }
    // anything else is a cut-off message or noise
  }
  return (messages, rest);
}

String _prefixStartAtEnd(String text) {
  for (int length = messagePrefix.length - 1; length > 0; length--) {
    if (text.endsWith(messagePrefix.substring(0, length))) {
      return messagePrefix.substring(0, length);
    }
  }
  return '';
}
