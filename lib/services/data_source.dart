/// Where the tracker's messages come from: the real BLE link or the demo
/// player. Both feed the same parsing code through TrackerLink.
abstract class TrackerDataSource {
  /// raw chunks, the way BLE notifications deliver them
  Stream<List<int>> get chunks;

  /// true once requests can be sent, false when the link is lost
  Stream<bool> get ready;

  /// app → tracker request: crc, clear, all, id<N>
  Future<void> send(String request);

  void dispose();
}
