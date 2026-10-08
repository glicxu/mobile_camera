import 'package:flutter/material.dart';
import 'camera_controller.dart';
import 'package:dali_camera_core/dali_camera_core.dart';

/// The reference app's situation / effects / reference controls.
class CameraSelectionRow extends StatelessWidget {
  const CameraSelectionRow({
    super.key,
    required this.camera,
    required this.onPackages,
    required this.onEffects,
  });

  final CameraController camera;
  final VoidCallback onPackages;
  final VoidCallback onEffects;

  @override
  Widget build(BuildContext context) {
    final situation = camera.shootingMode.title;
    final reference = camera.activeSituation.catalogKind == 'food'
        ? 'Food'
        : camera.activeSituation.catalogKind == 'landscape'
        ? 'Landscape'
        : 'Posture';
    final filterTitle = camera.filter == 'off'
        ? 'Off'
        : camera.filter == 'auto'
        ? 'Auto'
        : 'Custom';
    final controls = [
      PopupMenuButton<PhotographicSituation>(
        key: const Key('situationMenu'),
        tooltip: 'Choose situation',
        enabled: !camera.busy,
        onSelected: (value) {
          camera.setSituation(value);
        },
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
        child: _SelectionLabel(
          title: 'Situation',
          value: situation,
          icon: Icons.camera_alt_outlined,
        ),
      ),
      PopupMenuButton<String>(
        key: const Key('effectsMenu'),
        tooltip: 'Choose effects',
        enabled: !camera.busy,
        onSelected: (value) {
          if (value == 'settings') {
            onEffects();
          } else if (value.startsWith('beauty:')) {
            camera.beautifier = value.split(':').last;
            camera.persistSettings();
            if (camera.beautifier == 'custom') onEffects();
          } else if (value.startsWith('both:')) {
            camera.filter = camera.beautifier = value.split(':').last;
            camera.persistSettings();
          } else if (value == 'custom') {
            if (camera.filter == 'auto' || camera.filter == 'off') {
              camera.filter = 'custom';
              camera.persistSettings();
            }
            onEffects();
          } else {
            camera.filter = value;
            camera.persistSettings();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(enabled: false, child: Text('Filters')),
          for (final mode in ['auto', 'custom', 'off'])
            CheckedPopupMenuItem(
              value: mode,
              checked: filterTitle.toLowerCase() == mode,
              child: Text(
                mode == 'auto'
                    ? 'Auto'
                    : mode == 'off'
                    ? 'Off'
                    : 'Custom',
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(enabled: false, child: Text('Beautifier')),
          for (final mode in ['auto', 'custom', 'off'])
            CheckedPopupMenuItem(
              value: 'beauty:$mode',
              checked: camera.beautifier == mode,
              child: Text(
                mode == 'auto'
                    ? 'Auto'
                    : mode == 'custom'
                    ? 'Custom'
                    : 'Off',
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'both:auto', child: Text('Both Auto')),
          const PopupMenuItem(value: 'both:off', child: Text('Both Off')),
          const PopupMenuItem(
            value: 'settings',
            child: Text('Effects settings and watermark'),
          ),
        ],
        child: _SelectionLabel(
          title: 'Effects',
          value: 'Filters $filterTitle',
          icon: Icons.auto_awesome,
        ),
      ),
      if (camera.activeSituation.catalogKind != null)
        Semantics(
          button: true,
          label: '$reference, ${camera.guidance.entry?.title ?? 'Natural'}',
          excludeSemantics: true,
          onTap: camera.busy ? null : onPackages,
          child: InkWell(
            key: const Key('referenceMenu'),
            borderRadius: BorderRadius.circular(12),
            onTap: camera.busy ? null : onPackages,
            child: _SelectionLabel(
              title: reference,
              value: camera.guidance.entry?.title ?? 'Natural',
              icon: camera.food
                  ? Icons.restaurant
                  : camera.landscape
                  ? Icons.landscape
                  : Icons.accessibility_new,
            ),
          ),
        ),
    ];
    return LayoutBuilder(
      builder: (context, bounds) {
        // Preserve readable labels at large text sizes instead of shrinking text.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (bounds.maxWidth < 300 || scale > 1.5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final control in controls) control],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final control in controls) Expanded(child: control)],
        );
      },
    );
  }
}

class _SelectionLabel extends StatelessWidget {
  const _SelectionLabel({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(3),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );
}
