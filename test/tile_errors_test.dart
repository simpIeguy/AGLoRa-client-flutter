import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/util/tile_errors.dart';

void main() {
  const lib = 'image resource service';

  test('a tile that did not come is not a failure', () {
    expect(isTileLoadFailure(ArgumentError('No host specified in URI '), lib),
        isTrue);
    expect(isTileLoadFailure(const SocketException('no network'), lib), isTrue);
    expect(isTileLoadFailure(TimeoutException('slow'), lib), isTrue);
  });

  test('other errors and other places stay failures', () {
    expect(isTileLoadFailure(StateError('bug'), lib), isFalse);
    expect(isTileLoadFailure(ArgumentError('bad value'), lib), isFalse);
    expect(isTileLoadFailure(const SocketException('x'), 'widgets'), isFalse);
    expect(isTileLoadFailure(const SocketException('x'), null), isFalse);
  });
}
