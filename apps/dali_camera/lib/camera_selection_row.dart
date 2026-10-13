import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';

import 'camera_controller.dart';

/// Four compact camera shortcuts with a shared green-on / grey-off language.
class CameraSelectionRow extends StatelessWidget {
  const CameraSelectionRow({
    super.key,
    required this.camera,
    required this.onBeautifierLongPress,
  });

  final CameraController camera;
  final VoidCallback onBeautifierLongPress;

  @override
  Widget build(BuildContext context) {
    final situation = camera.shootingMode.title;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        PopupMenuButton<PhotographicSituation>(
          key: const Key('situationMenu'),
          tooltip: 'Situation: $situation',
          enabled: !camera.busy,
          onSelected: camera.setSituation,
          itemBuilder: (_) => [
            for (final mode in PhotographicSituation.values)
              PopupMenuItem(
                value: mode,
                child: Row(
                  children: [
                    Expanded(child: Text(mode.title)),
                    if (camera.shootingMode == mode)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
          ],
          child: _StateIcon(
            icon: Icons.camera_alt_outlined,
            enabled: camera.shootingMode != PhotographicSituation.auto,
            disabled: camera.busy,
            dropdown: true,
          ),
        ),
        _EffectToggle(
          key: const Key('filterToggle'),
          title: 'Filters',
          icon: Icons.filter_alt_outlined,
          enabled: camera.filterEnabled,
          busy: camera.busy,
          onTap: camera.toggleFilter,
        ),
        _EffectToggle(
          key: const Key('beautifierToggle'),
          title: 'Beautifier',
          icon: Icons.auto_awesome,
          enabled: camera.beautifierEnabled,
          busy: camera.busy,
          onTap: camera.toggleBeautifier,
          onLongPress: onBeautifierLongPress,
        ),
        _EffectToggle(
          key: const Key('guidesToggle'),
          title: 'Guides',
          icon: Icons.collections_bookmark_outlined,
          enabled: camera.guidesEnabled,
          busy: camera.busy,
          onTap: camera.toggleGuides,
        ),
      ],
    );
  }
}

class _EffectToggle extends StatelessWidget {
  const _EffectToggle({
    super.key,
    required this.title,
    required this.icon,
    required this.enabled,
    required this.busy,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final IconData icon;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$title: ${enabled ? 'On' : 'Off'}',
    child: Semantics(
      button: true,
      toggled: enabled,
      label:
          '$title ${enabled ? 'on' : 'off'}${onLongPress == null ? '' : '. Long press for choices'}',
      onLongPress: busy ? null : onLongPress,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: busy ? null : onTap,
        onLongPress: busy ? null : onLongPress,
        child: _StateIcon(icon: icon, enabled: enabled, disabled: busy),
      ),
    ),
  );
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({
    required this.icon,
    required this.enabled,
    this.disabled = false,
    this.dropdown = false,
  });

  final IconData icon;
  final bool enabled;
  final bool disabled;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? Colors.grey.shade700
        : enabled
        ? Colors.greenAccent.shade400
        : Colors.grey.shade500;
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: enabled ? .18 : .10),
        border: Border.all(color: color, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 23, color: color),
          if (dropdown)
            Positioned(
              right: 4,
              bottom: 4,
              child: Icon(Icons.arrow_drop_down, size: 14, color: color),
            ),
        ],
      ),
    );
  }
}
