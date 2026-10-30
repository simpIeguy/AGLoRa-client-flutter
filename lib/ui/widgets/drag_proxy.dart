import 'package:flutter/material.dart';

/// How a card or a chip looks while it is dragged: rounded like itself, a
/// soft shadow, no square background (the list's own picks a rectangle).
/// [color]: a fill for items with no background of their own.
ReorderItemProxyDecorator dragProxy(double radius, {Color? color}) =>
    (child, index, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                    color:
                        Colors.black.withValues(alpha: 0.25 * animation.value),
                    blurRadius: 10 * animation.value),
              ],
            ),
            child: child,
          ),
        );
