import 'package:flutter/material.dart';

/// Confirms an actual successful capture, independently of save/processing work.
class CaptureFeedback extends StatefulWidget {
  const CaptureFeedback({super.key, required this.sequence});
  final int sequence;

  @override
  State<CaptureFeedback> createState() => _CaptureFeedbackState();
}

class _CaptureFeedbackState extends State<CaptureFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController feedback = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(CaptureFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sequence != oldWidget.sequence) feedback.forward(from: 0);
  }

  @override
  void dispose() {
    feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: feedback,
        builder: (context, _) {
          if (!feedback.isAnimating) return const SizedBox.shrink();
          return Stack(
            fit: StackFit.expand,
            children: [
              if (!reducedMotion)
                Opacity(
                  key: const Key('captureFlash'),
                  opacity: .55 * (1 - (feedback.value * 5).clamp(0.0, 1.0)),
                  child: const ColoredBox(color: Colors.white),
                ),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: const Chip(
                      avatar: Icon(Icons.check, size: 18),
                      label: Text('Photo taken'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
