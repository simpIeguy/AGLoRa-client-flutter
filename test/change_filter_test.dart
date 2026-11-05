import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/util/change_filter.dart';

class _Source extends ChangeNotifier {
  void tick() => notifyListeners();
}

void main() {
  test('passes a tick on only when the signature changed', () {
    final source = _Source();
    var value = 'a';
    final filter = ChangeFilter(source, () => value);
    var calls = 0;
    filter.addListener(() => calls++);

    source.tick();
    source.tick();
    expect(calls, 0, reason: 'nothing changed');

    value = 'b';
    source.tick();
    expect(calls, 1);
    source.tick();
    expect(calls, 1, reason: 'the same again');

    filter.dispose();
    value = 'c';
    source.tick();
    expect(calls, 1, reason: 'a disposed filter is silent');
  });
}
