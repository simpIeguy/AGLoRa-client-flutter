import 'package:flutter/material.dart';

/// A sheet from the bottom that goes away with a swipe down: by the handle,
/// or by the list inside it pulled down past its top. Every sheet of the app
/// is opened through this.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,

  /// a tall sheet stops at this part of the screen height, so there is always
  /// a free strip above it to tap or to pull the sheet down by
  double? maxHeightFraction,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      constraints: maxHeightFraction == null
          ? null
          : BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction),
      builder: (sheet) => _PullDownToClose(
        // our own handle: the stock one leaves 48 px of empty space above
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(sheet).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Flexible(child: builder(sheet)),
        ]),
      ),
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
