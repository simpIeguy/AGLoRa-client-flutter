import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsp_tracker/ui/widgets/steady_reorder_list.dart';

void main() {
  testWidgets('a new item waits until the held one is dropped', (tester) async {
    final items = ValueNotifier<List<String>>(['a', 'b']);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<List<String>>(
          valueListenable: items,
          builder: (context, list, _) => SteadyReorderList<String>(
            items: list,
            keyOf: (s) => s,
            onOrder: (_) {},
            itemBuilder: (s) => SizedBox(
                key: ValueKey(s), height: 60, child: Center(child: Text(s))),
          ),
        ),
      ),
    ));

    final hold = await tester.startGesture(tester.getCenter(find.text('a')));
    await tester.pump(const Duration(milliseconds: 600));
    items.value = ['a', 'b', 'c'];
    await tester.pump();
    expect(find.text('c'), findsNothing, reason: 'held: the list stands');

    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('c'), findsOneWidget);
  });
}
