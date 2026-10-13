import 'dart:math' as math;

import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';

class LandscapeInstrumentOverlay extends StatelessWidget {
  const LandscapeInstrumentOverlay({super.key, required this.state});

  final LandscapeInstrumentState state;

  Color _color(BuildContext context, bool available, bool attention) {
    if (!available) return Theme.of(context).colorScheme.outline;
    return attention ? Colors.amber : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final horizonColor = state.horizonSevere
        ? Colors.red
        : _color(context, state.horizonAvailable, state.horizonNeedsAttention);
    final stabilityColor = _color(
      context,
      state.stabilityAvailable,
      state.stabilityNeedsAttention,
    );
    final exposureColor = _color(
      context,
      state.exposureAvailable,
      state.exposureNeedsAttention,
    );
    return IgnorePointer(
      child: Semantics(
        container: true,
        label: 'Landscape camera instruments',
        child: Container(
          key: const Key('landscapeInstrumentOverlay'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HorizonInstrument(
                angle: state.horizonAngle,
                color: horizonColor,
                available: state.horizonAvailable,
                attention: state.horizonNeedsAttention,
              ),
              const _Divider(),
              _StabilityInstrument(
                color: stabilityColor,
                available: state.stabilityAvailable,
                attention: state.stabilityNeedsAttention,
              ),
              const _Divider(),
              _ExposureInstrument(
                position: state.exposurePosition,
                color: exposureColor,
                available: state.exposureAvailable,
                attention: state.exposureNeedsAttention,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizonInstrument extends StatelessWidget {
  const _HorizonInstrument({
    required this.angle,
    required this.color,
    required this.available,
    required this.attention,
  });
  final double angle;
  final Color color;
  final bool available;
  final bool attention;

  @override
  Widget build(BuildContext context) => Semantics(
    label: !available
        ? 'Horizon unavailable'
        : attention
        ? 'Horizon tilted'
        : 'Horizon level',
    child: SizedBox(
      key: const Key('landscapeHorizonInstrument'),
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 48, height: 1, color: Colors.white30),
                Transform.rotate(
                  angle: angle * math.pi / 180,
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'LEVEL',
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: 8, color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

class _StabilityInstrument extends StatelessWidget {
  const _StabilityInstrument({
    required this.color,
    required this.available,
    required this.attention,
  });
  final Color color;
  final bool available;
  final bool attention;

  @override
  Widget build(BuildContext context) => Semantics(
    label: !available
        ? 'Stability unavailable'
        : attention
        ? 'Camera moving'
        : 'Camera steady',
    child: SizedBox(
      key: const Key('landscapeStabilityInstrument'),
      width: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.photo_camera_outlined, size: 18),
              Positioned(
                right: -5,
                top: -3,
                child: _StatusDot(color: color, pulse: available && attention),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'STEADY',
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: 8, color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

class _ExposureInstrument extends StatelessWidget {
  const _ExposureInstrument({
    required this.position,
    required this.color,
    required this.available,
    required this.attention,
  });
  final double position;
  final Color color;
  final bool available;
  final bool attention;

  @override
  Widget build(BuildContext context) => Semantics(
    label: !available
        ? 'Exposure unavailable'
        : attention
        ? position < 0
              ? 'Scene appears underexposed'
              : 'Scene appears overexposed'
        : 'Exposure balanced',
    child: SizedBox(
      key: const Key('landscapeExposureInstrument'),
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('−', style: TextStyle(fontSize: 10)),
              Expanded(
                child: SizedBox(
                  height: 16,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(height: 2, color: Colors.white38),
                      Align(
                        alignment: Alignment(position.clamp(-1, 1), 0),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 8, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const Text('+', style: TextStyle(fontSize: 10)),
            ],
          ),
          const Text(
            'EXPOSURE',
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: 8, color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: .45,
    upperBound: 1,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1),
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 7),
    color: Colors.white24,
  );
}
