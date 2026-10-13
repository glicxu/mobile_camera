import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Native reference uses drag distance, so deliberate slow swipes navigate too.
class DistanceSwipe extends StatefulWidget {
  const DistanceSwipe({
    super.key,
    required this.child,
    required this.minimumDistance,
    this.onSwipe,
    this.onTap,
  });
  final Widget child;
  final double minimumDistance;
  final ValueChanged<int>? onSwipe;
  final VoidCallback? onTap;
  @override
  State<DistanceSwipe> createState() => _DistanceSwipeState();
}

class _DistanceSwipeState extends State<DistanceSwipe> {
  double startX = 0, distance = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    dragStartBehavior: DragStartBehavior.down,
    onTap: widget.onTap,
    onHorizontalDragStart: widget.onSwipe == null
        ? null
        : (details) {
            startX = details.globalPosition.dx;
            distance = 0;
          },
    onHorizontalDragUpdate: widget.onSwipe == null
        ? null
        : (details) {
            distance = details.globalPosition.dx - startX;
          },
    onHorizontalDragEnd: widget.onSwipe == null
        ? null
        : (_) {
            if (distance.abs() >= widget.minimumDistance) {
              widget.onSwipe!(distance < 0 ? 1 : -1);
            }
            distance = 0;
          },
    onHorizontalDragCancel: widget.onSwipe == null ? null : () => distance = 0,
    child: widget.child,
  );
}
