import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dali_camera_core/dali_camera_core.dart';

IconData coachingDirectionIcon(String direction) => switch (direction) {
  'left' => Icons.arrow_back,
  'right' => Icons.arrow_forward,
  'up' => Icons.arrow_upward,
  'down' => Icons.arrow_downward,
  'closer' => Icons.compress,
  'farther' => Icons.open_in_full,
  'rotateLeft' => Icons.rotate_left,
  _ => Icons.rotate_right,
};

class CoachingOverlay extends StatefulWidget {
  const CoachingOverlay({
    super.key,
    required this.advice,
    this.frame,
    this.guidedAction,
    this.animate = true,
  });
  final Advice advice;
  final Map<String, dynamic>? frame;
  final GuidedAction? guidedAction;
  final bool animate;
  @override
  State<CoachingOverlay> createState() => _CoachingOverlayState();
}

class _CoachingOverlayState extends State<CoachingOverlay>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate ||
        widget.advice.direction == null ||
        MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
      animation.value = 0;
    } else if (!animation.isAnimating) {
      animation.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CoachingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate ||
        widget.advice.direction == null ||
        MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
      animation.value = 0;
    } else if (!animation.isAnimating) {
      animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final color = switch (widget.advice.tone) {
            AdviceTone.ready => Colors.green,
            AdviceTone.warning || AdviceTone.danger => Colors.orange,
            AdviceTone.waiting => Colors.yellow,
          };
          final direction = widget.advice.direction;
          final x = switch (direction) {
            'left' => math.min(112.0, bounds.maxWidth * .27),
            'right' => bounds.maxWidth - math.min(112.0, bounds.maxWidth * .27),
            _ => bounds.maxWidth / 2,
          };
          final y = switch (direction) {
            'up' => math.min(132.0, bounds.maxHeight * .25),
            'down' =>
              bounds.maxHeight - math.min(132.0, bounds.maxHeight * .25),
            _ => bounds.maxHeight / 2,
          };
          final width = math.min(200.0, math.max(140.0, bounds.maxWidth * .48));
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: CoachingFramePainter(widget.frame)),
              Positioned(
                top: 14,
                left: bounds.maxWidth / 2 - 16,
                child: Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xad000000),
                    shape: BoxShape.circle,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: .95),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (direction != null)
                Positioned(
                  left: x - width / 2,
                  top: y - 66,
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: animation,
                        builder: (_, child) => Transform.translate(
                          offset: switch (direction) {
                            'left' => Offset(-14 * animation.value, 0),
                            'right' => Offset(14 * animation.value, 0),
                            'up' => Offset(0, -14 * animation.value),
                            'down' => Offset(0, 14 * animation.value),
                            _ => Offset.zero,
                          },
                          child: child,
                        ),
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .92),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Icon(
                            coachingDirectionIcon(direction),
                            size: 52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xb8000000),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          widget.advice.instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              if (direction == null && widget.guidedAction != null)
                Center(
                  child: Icon(
                    switch (widget.guidedAction!) {
                      GuidedAction.subjectPose => Icons.accessibility_new,
                      GuidedAction.cameraHeight => Icons.height,
                      GuidedAction.cameraPitch => Icons.cameraswitch,
                      GuidedAction.photographerMove => Icons.directions_walk,
                    },
                    size: 40,
                    color: color,
                  ),
                ),
              if (direction == null &&
                  widget.guidedAction == null &&
                  widget.advice.type != 'ready')
                Center(
                  child: Icon(
                    switch (widget.advice.type) {
                      'camera_tilted' || 'horizon_tilted' => Icons.cameraswitch,
                      'headroom_too_large' ||
                      'headroom_too_small' => Icons.height,
                      'limb_cropped' => Icons.directions_walk,
                      _ =>
                        widget.advice.recipient == 'Subject'
                            ? Icons.accessibility_new
                            : null,
                    },
                    size: 40,
                    color: color,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class CoachingFramePainter extends CustomPainter {
  CoachingFramePainter(this.frame);
  final Map<String, dynamic>? frame;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        paint,
      );
    }
    if (frame == null) return;
    for (final key in ['people', 'faces']) {
      paint
        ..color = key == 'faces' ? Colors.yellow : Colors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final box in frame![key] as List? ?? []) {
        canvas.drawRect(
          Rect.fromLTWH(
            (box['x'] as num) * size.width,
            (box['y'] as num) * size.height,
            (box['width'] as num) * size.width,
            (box['height'] as num) * size.height,
          ),
          paint,
        );
      }
    }
    final horizon = frame!['horizon'] as Map?;
    if (horizon != null) {
      final center = Offset(
        size.width / 2,
        (horizon['normalizedY'] as num? ?? .5) * size.height,
      );
      final dy =
          math.tan(
            (horizon['angleDegrees'] as num).toDouble() * math.pi / 180,
          ) *
          size.width /
          2;
      canvas.drawLine(
        center - Offset(size.width / 2, dy),
        center + Offset(size.width / 2, dy),
        paint
          ..color = Colors.cyan
          ..strokeWidth = 2,
      );
    }
    final points = frame!['poseKeypoints'] as Map? ?? {};
    Offset? point(String name) {
      final aliases = <String, List<String>>{
        'leftForearm': ['leftForearm', 'leftElbow'],
        'rightForearm': ['rightForearm', 'rightElbow'],
        'leftHand': ['leftHand', 'leftWrist'],
        'rightHand': ['rightHand', 'rightWrist'],
        'leftUpLeg': ['leftUpLeg', 'leftHip'],
        'rightUpLeg': ['rightUpLeg', 'rightHip'],
        'leftLeg': ['leftLeg', 'leftKnee'],
        'rightLeg': ['rightLeg', 'rightKnee'],
        'leftFoot': ['leftFoot', 'leftAnkle'],
        'rightFoot': ['rightFoot', 'rightAnkle'],
      };
      String normalize(String value) =>
          value.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
      for (final entry in points.entries) {
        if ((aliases[name] ?? [name]).any(
          (alias) => normalize(entry.key.toString()).contains(normalize(alias)),
        )) {
          final p = entry.value as Map;
          if ((p['confidence'] as num? ?? 0) > .2) {
            return Offset(
              (p['x'] as num) * size.width,
              (p['y'] as num) * size.height,
            );
          }
        }
      }
      return null;
    }

    paint
      ..color = Colors.orange.withValues(alpha: .86)
      ..strokeWidth = 3;
    for (final pair in [
      ['leftShoulder', 'rightShoulder'],
      ['leftShoulder', 'leftForearm'],
      ['leftForearm', 'leftHand'],
      ['rightShoulder', 'rightForearm'],
      ['rightForearm', 'rightHand'],
      ['leftShoulder', 'leftUpLeg'],
      ['rightShoulder', 'rightUpLeg'],
      ['leftUpLeg', 'rightUpLeg'],
      ['leftUpLeg', 'leftLeg'],
      ['leftLeg', 'leftFoot'],
      ['rightUpLeg', 'rightLeg'],
      ['rightLeg', 'rightFoot'],
      ['neck', 'nose'],
    ]) {
      final a = point(pair[0]), b = point(pair[1]);
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
    paint.style = PaintingStyle.fill;
    for (final p in points.values.whereType<Map>()) {
      if ((p['confidence'] as num? ?? 0) > .2) {
        canvas.drawCircle(
          Offset((p['x'] as num) * size.width, (p['y'] as num) * size.height),
          4,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CoachingFramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
