import 'package:flutter/material.dart';

/// A list whose items are picked up by a long press and moved. While one is
/// held the list does not change: a tracker that appears or vanishes at that
/// moment waits for the drop, otherwise the held item loses its place and
/// falls. The data of the items still updates.
class SteadyReorderList<T> extends StatefulWidget {
  const SteadyReorderList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    required this.onOrder,
    this.proxyDecorator,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<T> items;
  final String Function(T) keyOf;

  /// the widget must have the key `ValueKey(keyOf(item))`
  final Widget Function(T) itemBuilder;

  /// the keys of the items in the new order
  final void Function(List<String> keys) onOrder;

  final ReorderItemProxyDecorator? proxyDecorator;
  final Axis scrollDirection;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  State<SteadyReorderList<T>> createState() => _SteadyReorderListState<T>();
}

class _SteadyReorderListState<T> extends State<SteadyReorderList<T>> {
  /// the keys as they were when the item was picked up; null: nothing held
  List<String>? _frozen;

  List<T> _shown() {
    final frozen = _frozen;
    if (frozen == null) return widget.items;
    final byKey = {for (final i in widget.items) widget.keyOf(i): i};
    return [
      for (final k in frozen)
        if (byKey[k] != null) byKey[k] as T,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown();
    return ReorderableListView(
      scrollDirection: widget.scrollDirection,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      proxyDecorator: widget.proxyDecorator,
      onReorderStart: (_) => setState(
          () => _frozen = [for (final i in widget.items) widget.keyOf(i)]),
      onReorderEnd: (_) => setState(() => _frozen = null),
      onReorderItem: (from, to) {
        final keys = [for (final i in shown) widget.keyOf(i)];
        keys.insert(to, keys.removeAt(from));
        widget.onOrder(keys);
      },
      children: [for (final i in shown) widget.itemBuilder(i)],
    );
  }
}
