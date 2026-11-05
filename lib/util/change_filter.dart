import 'package:flutter/foundation.dart';

/// Passes a tick of [source] on only when [signature] has changed since the
/// last time. The map listens to the clock through it: the clock ticks every
/// second, but the map has to be built again only when a tracker changes its
/// status (the ages on the cards and markers tick by themselves).
class ChangeFilter extends ChangeNotifier {
  ChangeFilter(this._source, this._signature) : _last = _signature() {
    _source.addListener(_check);
  }

  final Listenable _source;
  final String Function() _signature;
  String _last;

  void _check() {
    final now = _signature();
    if (now == _last) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_check);
    super.dispose();
  }
}
