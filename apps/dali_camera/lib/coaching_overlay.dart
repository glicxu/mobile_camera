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
    this.visualFirst = false,
  });
  final Advice advice;
  final Map<String, dynamic>? frame;
  final GuidedAction? guidedAction;
  final bool animate;
  final bool visualFirst;
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
              CustomPaint(
                painter: CoachingFramePainter(
                  widget.frame,
                  showGrid: !widget.visualFirst,
                ),
              ),
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
              if (widget.visualFirst)
                Center(
                  child: _PortraitVisualCue(
                    key: ValueKey('portraitCue-${widget.advice.type}'),
                    advice: widget.advice,
                    color: color,
                    animation: animation,
                    guidedAction: widget.guidedAction,
                  ),
                )
              else if (direction != null)
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
  CoachingFramePainter(this.frame, {this.showGrid = true});
  final Map<String, dynamic>? frame;
  final bool showGrid;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 1;
    if (showGrid) {
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
      oldDelegate.frame != frame || oldDelegate.showGrid != showGrid;
}

class _PortraitVisualCue extends StatelessWidget {
  const _PortraitVisualCue({
    super.key,
    required this.advice,
    required this.color,
    required this.animation,
    this.guidedAction,
  });

  final Advice advice;
  final Color color;
  final Animation<double> animation;
  final GuidedAction? guidedAction;

  @override
  Widget build(BuildContext context) {
    final direction = advice.direction;
    if (advice.type == 'ready') {
      return _CueDisc(
        key: const Key('portraitVisualReady'),
        color: color,
        icon: Icons.check,
        size: 72,
      );
    }
    if (advice.type == 'subject_missing') {
      return _PortraitFrameCue(color: color);
    }
    if (advice.type == 'face_missing') {
      return _CueDisc(
        key: const Key('portraitVisualFace'),
        color: color,
        icon: Icons.face_retouching_natural,
      );
    }
    if (advice.type == 'subject_too_close' ||
        advice.type == 'subject_too_far' ||
        advice.type == 'feet_cropped' ||
        advice.type == 'scene_excluded') {
      return _DistanceCue(
        color: color,
        moveCloser: advice.type == 'subject_too_far',
      );
    }
    if (advice.type == 'camera_tilted' || advice.type == 'horizon_tilted') {
      return _LevelCue(color: color, tiltLeft: direction == 'rotateLeft');
    }
    if (advice.type == 'subject_backlit' ||
        advice.type == 'face_underexposed') {
      return _CueDisc(
        key: const Key('portraitVisualLight'),
        color: color,
        icon: Icons.light_mode_outlined,
      );
    }
    if (advice.type == 'camera_unstable' || advice.type == 'waiting') {
      return _CueDisc(
        key: const Key('portraitVisualSteady'),
        color: color,
        icon: Icons.motion_photos_paused_outlined,
      );
    }
    if (direction != null) {
      final moves = const {'left', 'right', 'up', 'down'}.contains(direction);
      return AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Transform.translate(
          offset: !moves
              ? Offset.zero
              : switch (direction) {
                  'left' => Offset(-14 * animation.value, 0),
                  'right' => Offset(14 * animation.value, 0),
                  'up' => Offset(0, -14 * animation.value),
                  _ => Offset(0, 14 * animation.value),
                },
          child: child,
        ),
        child: _CueDisc(
          key: const Key('portraitVisualDirection'),
          color: color,
          icon: coachingDirectionIcon(direction),
        ),
      );
    }
    if (guidedAction != null) {
      return _CueDisc(
        key: const Key('portraitVisualGuidedAction'),
        color: color,
        icon: switch (guidedAction!) {
          GuidedAction.subjectPose => Icons.accessibility_new,
          GuidedAction.cameraHeight => Icons.height,
          GuidedAction.cameraPitch => Icons.cameraswitch,
          GuidedAction.photographerMove => Icons.directions_walk,
        },
      );
    }
    return _CueDisc(
      key: const Key('portraitVisualSubject'),
      color: color,
      icon: advice.recipient == 'Subject'
          ? Icons.accessibility_new
          : Icons.center_focus_strong,
    );
  }
}

class _CueDisc extends StatelessWidget {
  const _CueDisc({
    super.key,
    required this.color,
    required this.icon,
    this.size = 82,
  });
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .9),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 12),
      ],
    ),
    child: Icon(icon, size: size * .58, color: Colors.white),
  );
}

class _PortraitFrameCue extends StatelessWidget {
  const _PortraitFrameCue({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('portraitVisualFrame'),
    width: 132,
    height: 210,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(66),
      border: Border.all(color: color, width: 4),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .35), blurRadius: 14),
      ],
    ),
    alignment: Alignment.center,
    child: Icon(Icons.person_outline, size: 88, color: color),
  );
}

class _DistanceCue extends StatelessWidget {
  const _DistanceCue({required this.color, required this.moveCloser});
  final Color color;
  final bool moveCloser;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('portraitVisualDistance'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .46),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: color, width: 3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          moveCloser ? Icons.chevron_right : Icons.chevron_left,
          size: 42,
          color: color,
        ),
        Icon(Icons.person_outline, size: 66, color: Colors.white),
        Icon(
          moveCloser ? Icons.chevron_left : Icons.chevron_right,
          size: 42,
          color: color,
        ),
      ],
    ),
  );
}

class _LevelCue extends StatelessWidget {
  const _LevelCue({required this.color, required this.tiltLeft});
  final Color color;
  final bool tiltLeft;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('portraitVisualLevel'),
    width: 164,
    height: 76,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .46),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color, width: 3),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(height: 2, color: Colors.white54),
        Transform.rotate(
          angle: tiltLeft ? -.13 : .13,
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Icon(
          tiltLeft ? Icons.rotate_left : Icons.rotate_right,
          size: 34,
          color: Colors.white,
        ),
      ],
    ),
  );
}
