import 'package:flutter/material.dart';

/// How a card or a chip looks while it is dragged: rounded like itself, a
/// soft shadow, no square background (the list's own picks a rectangle).
/// [color]: a fill for items with no background of their own.
/// [gap]: the empty margin the item carries around the card (the space
/// between items); the shadow and the fill must not cover it, or a round
/// stub sticks out beside the card.
ReorderItemProxyDecorator dragProxy(double radius,
        {Color? color, EdgeInsets gap = EdgeInsets.zero}) =>
    (child, index, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Stack(children: [
            Positioned.fill(
              left: gap.left,
              top: gap.top,
              right: gap.right,
              bottom: gap.bottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.25 * animation.value),
                        blurRadius: 10 * animation.value),
                  ],
                ),
              ),
            ),
            child!,
          ]),
        );
