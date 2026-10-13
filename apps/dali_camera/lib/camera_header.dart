import 'package:flutter/material.dart';

const cameraTeal = Color(0xff30b0ac);

class CameraHeader extends StatelessWidget {
  const CameraHeader({
    super.key,
    required this.manualVisible,
    required this.manualMode,
    required this.coachingEnabled,
    required this.onManual,
    required this.onCoaching,
    required this.onSettings,
    required this.onSwitch,
  });
  final bool manualVisible, manualMode, coachingEnabled;
  final VoidCallback? onManual, onCoaching, onSettings, onSwitch;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'Dali Cam',
          key: Key('cameraBrandName'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cameraTeal,
          ),
        ),
      ),
      HeaderAction(
        key: const Key('manualControlsButton'),
        tooltip: manualVisible
            ? 'Hide manual controls'
            : 'Show manual controls',
        selected: manualVisible,
        foreground: manualVisible
            ? Colors.black
            : manualMode
            ? cameraTeal
            : Colors.white,
        onPressed: onManual,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: manualVisible
                    ? Colors.black
                    : manualMode
                    ? cameraTeal
                    : Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                'M',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: manualVisible ? cameraTeal : Colors.black,
                ),
              ),
            ),
            const Text(
              'Manual',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      HeaderAction(
        key: const Key('coachingToggle'),
        tooltip: coachingEnabled ? 'Turn coaching off' : 'Turn coaching on',
        selected: coachingEnabled,
        onPressed: onCoaching,
        child: Icon(
          coachingEnabled ? Icons.lightbulb : Icons.lightbulb_outline,
          size: 20,
        ),
      ),
      const SizedBox(width: 8),
      HeaderAction(
        key: const Key('appSettingsButton'),
        tooltip: 'App settings',
        onPressed: onSettings,
        child: const Icon(Icons.settings, size: 20),
      ),
      const SizedBox(width: 8),
      HeaderAction(
        key: const Key('switchCamera'),
        tooltip: 'Switch camera',
        onPressed: onSwitch,
        child: const Icon(Icons.cameraswitch, size: 20),
      ),
    ],
  );
}

class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.tooltip,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.foreground,
    this.size = 44,
    this.radius = 8,
  });
  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? foreground;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final color = foreground ?? (selected ? Colors.black : Colors.white);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? cameraTeal : const Color(0x73000000),
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: size,
              height: size,
              child: IconTheme(
                data: IconThemeData(
                  color: onPressed == null
                      ? color.withValues(alpha: .4)
                      : color,
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: color),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
