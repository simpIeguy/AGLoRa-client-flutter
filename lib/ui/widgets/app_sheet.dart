import 'package:flutter/material.dart';

/// A sheet from the bottom that goes away with a swipe down: by the handle,
/// or by the list inside it pulled down past its top. Every sheet of the app
/// is opened through this.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: true,
      builder: (sheet) => _PullDownToClose(child: builder(sheet)),
    );

/// A list that ends at its top and is pulled further down closes the sheet.
/// The lists inside must scroll even when short ([AlwaysScrollableScrollPhysics]),
/// otherwise there is no pull to notice.
class _PullDownToClose extends StatefulWidget {
  const _PullDownToClose({required this.child});

  final Widget child;

  @override
  State<_PullDownToClose> createState() => _PullDownToCloseState();
}

class _PullDownToCloseState extends State<_PullDownToClose> {
  /// how far the finger pulled past the top, in logical pixels
  double _pulled = 0;

  /// pulled this far: let go of the sheet
  static const double _enough = 60;

  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _pulled -= n.overscroll;
      if (_pulled > _enough) {
        _pulled = 0;
        Navigator.of(context).maybePop();
      }
    } else if (n is ScrollStartNotification || n is ScrollEndNotification) {
      _pulled = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
          onNotification: _onScroll, child: widget.child);
}
