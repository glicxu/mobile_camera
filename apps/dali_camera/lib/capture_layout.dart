import 'package:flutter/material.dart';

/// Keeps the camera chrome anchored to the handset while its contents stay
/// readable in the current display orientation. The native preview is upright.
class CaptureRotation extends InheritedWidget {
  const CaptureRotation({super.key, required this.turns, required super.child});
  final int turns;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CaptureRotation>()?.turns ?? 0;

  @override
  bool updateShouldNotify(CaptureRotation oldWidget) =>
      turns != oldWidget.turns;
}

class UprightCaptureControl extends StatelessWidget {
  const UprightCaptureControl({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      RotatedBox(quarterTurns: CaptureRotation.of(context), child: child);
}
