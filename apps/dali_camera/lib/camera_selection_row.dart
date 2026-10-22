import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';

import 'camera_controller.dart';
import 'capture_layout.dart';

/// The compact situation selector used in the always-visible camera header.
class SituationMenuButton extends StatelessWidget {
  const SituationMenuButton({super.key, required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final situation = camera.shootingMode.title;
    return PopupMenuButton<PhotographicSituation>(
      key: const Key('situationMenu'),
      tooltip: 'Situation: $situation',
      padding: EdgeInsets.zero,
      enabled: !camera.busy,
      onSelected: camera.setSituation,
      itemBuilder: (_) => [
        for (final mode in PhotographicSituation.values)
          PopupMenuItem(
            key: Key('situationOption_${mode.name}'),
            value: mode,
            height: 56,
            child: Tooltip(
              message: mode.title,
              child: Semantics(
                label: mode.title,
                selected: camera.shootingMode == mode,
                child: Center(
                  child: _SituationIcon(
                    icon: _situationIcon(mode),
                    selected: camera.shootingMode == mode,
                  ),
                ),
              ),
            ),
          ),
      ],
      child: UprightCaptureControl(
        child: _SituationIcon(
          icon: _situationIcon(camera.shootingMode),
          selected: false,
          neutral: true,
          disabled: camera.busy,
          dropdown: true,
        ),
      ),
    );
  }
}

/// Three compact effect shortcuts with a shared green-on / grey-off language.
class CameraSelectionRow extends StatelessWidget {
  const CameraSelectionRow({
    super.key,
    required this.camera,
    required this.onBeautifierLongPress,
    this.showGuides = true,
  });

  final CameraController camera;
  final VoidCallback onBeautifierLongPress;
  final bool showGuides;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
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
        if (showGuides)
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

IconData _situationIcon(PhotographicSituation situation) => switch (situation) {
  PhotographicSituation.auto => Icons.auto_mode,
  PhotographicSituation.portrait => Icons.person_outline,
  PhotographicSituation.group => Icons.groups_outlined,
  PhotographicSituation.personScene => Icons.person_pin_circle_outlined,
  PhotographicSituation.landscape => Icons.landscape_outlined,
  PhotographicSituation.action => Icons.directions_run,
  PhotographicSituation.closeUp => Icons.center_focus_strong,
  PhotographicSituation.food => Icons.restaurant_outlined,
};

class _SituationIcon extends StatelessWidget {
  const _SituationIcon({
    required this.icon,
    required this.selected,
    this.neutral = false,
    this.disabled = false,
    this.dropdown = false,
  });

  final IconData icon;
  final bool selected;
  final bool neutral;
  final bool disabled;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? Colors.grey.shade700
        : neutral
        ? Colors.white
        : selected
        ? Colors.greenAccent.shade400
        : Colors.grey.shade500;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          if (dropdown)
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.arrow_drop_down, size: 13, color: color),
            ),
        ],
      ),
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
        child: UprightCaptureControl(
          child: _StateIcon(icon: icon, enabled: enabled, disabled: busy),
        ),
      ),
    ),
  );
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({
    required this.icon,
    required this.enabled,
    this.disabled = false,
  });

  final IconData icon;
  final bool enabled;
  final bool disabled;

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
      child: Icon(icon, size: 23, color: color),
    );
  }
}
