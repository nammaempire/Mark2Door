import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/features/catalog/data/live_list.dart';

void main() {
  late StreamController<LiveSnapshot<String>> source;
  late int opened;
  late int changes;
  late LiveList<String> list;

  setUp(() {
    opened = 0;
    changes = 0;
    list = LiveList<String>(
      () {
        opened++;
        source = StreamController<LiveSnapshot<String>>();
        return source.stream;
      },
      () => changes++,
      patience: const Duration(milliseconds: 200),
    );
  });

  LiveSnapshot<String> snap(
    List<String> items, {
    bool fromCache = false,
    bool changed = true,
  }) =>
      LiveSnapshot(items, fromCache: fromCache, changed: changed);

  test('the list is read once and then answered from memory', () async {
    final first = list.items();
    source.add(snap(['apple', 'milk']));
    expect(await first, ['apple', 'milk']);
    // Asking again, as every screen and every search does, opens nothing.
    expect(await list.items(), ['apple', 'milk']);
    expect(await list.items(), ['apple', 'milk']);
    expect(opened, 1);
    expect(changes, 0);
  });

  test('a change by the store updates the list and is announced', () async {
    final first = list.items();
    source.add(snap(['apple']));
    await first;
    source.add(snap(['apple', 'honey']));
    await Future<void>.delayed(Duration.zero);
    expect(await list.items(), ['apple', 'honey']);
    expect(changes, 1);
    // The server agreeing with what was sent is not a change.
    source.add(snap(['apple', 'honey'], changed: false));
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);
  });

  test('a saved copy shows at once; an empty saved copy waits for the server',
      () async {
    final first = list.items();
    source.add(snap([], fromCache: true));
    var done = false;
    unawaited(first.then((_) => done = true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse);
    source.add(snap(['apple']));
    expect(await first, ['apple']);

    // A saved copy with products in it is used straight away.
    final other = LiveList<String>(
      () => Stream.value(snap(['milk'], fromCache: true)),
      () {},
    );
    expect(await other.items(), ['milk']);
  });

  test('a refused or silent connection fails and is tried again next time',
      () async {
    final refused = list.items();
    source.addError(StateError('permission-denied'));
    await expectLater(refused, throwsStateError);
    expect(list.connected, isFalse);

    // Nothing arrives: given up after the wait.
    await expectLater(list.items(), throwsA(isA<TimeoutException>()));
    expect(list.connected, isFalse);

    // The next request opens a new connection and works.
    final again = list.items();
    source.add(snap(['apple']));
    expect(await again, ['apple']);
    expect(opened, 3);
  });
}
