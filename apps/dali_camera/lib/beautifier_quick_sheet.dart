import 'package:flutter/material.dart';

import 'beautifier_preset_guidance.dart';
import 'camera_controller.dart';

Future<void> showBeautifierQuickSheet(
  BuildContext context,
  CameraController camera,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => BeautifierQuickSheet(
    camera: camera,
    onSelected: () => Navigator.of(sheetContext).pop(),
  ),
);

class BeautifierQuickSheet extends StatelessWidget {
  const BeautifierQuickSheet({
    super.key,
    required this.camera,
    required this.onSelected,
  });

  final CameraController camera;
  final VoidCallback onSelected;

  Future<void> chooseAuto() async {
    await camera.selectBeautifierAuto();
    onSelected();
  }

  Future<void> chooseOff() async {
    await camera.selectBeautifierOff();
    onSelected();
  }

  Future<void> choosePreset(String treatment, String preset) async {
    await camera.selectBeautifierPreset(treatment, preset);
    final guidance = guidanceForBeautifierPreset(treatment, preset);
    onSelected();
    if (guidance != null) {
      camera.showPresetGuidance('$preset: $guidance');
    }
  }

  @override
  Widget build(BuildContext context) {
    final portraitPreset =
        camera.captureTreatments['portrait']!['preset'] as String? ?? 'Custom';
    final landscapePreset =
        camera.captureTreatments['landscape']!['preset'] as String? ?? 'Custom';
    final selectedTreatment = camera.beautifierMode == 'custom'
        ? camera.customBeautifier
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Beautifier', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Choose Auto, a portrait or landscape preset, or turn Beautifier off.',
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('beautifierQuickAuto'),
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Auto'),
              subtitle: const Text(
                'Uses Portrait or Landscape Beautifier when the scene needs it.',
              ),
              trailing:
                  camera.beautifierEnabled && camera.beautifierMode == 'auto'
                  ? const Icon(Icons.check)
                  : null,
              onTap: chooseAuto,
            ),
            const Divider(),
            _PresetSection(
              title: 'Portrait',
              description: 'Face-aware skin and feature refinement',
              presets: const ['Natural', 'Polished', 'Glam', 'Max'],
              selected: selectedTreatment == 'portrait' ? portraitPreset : null,
              keyPrefix: 'portrait',
              onSelected: (preset) => choosePreset('portrait', preset),
            ),
            const SizedBox(height: 16),
            _PresetSection(
              title: 'Landscape',
              description: 'Rich scenery with optional blue sky and clouds',
              presets: const ['Natural', 'Vivid', 'Dramatic'],
              selected: selectedTreatment == 'landscape'
                  ? landscapePreset
                  : null,
              keyPrefix: 'landscape',
              onSelected: (preset) => choosePreset('landscape', preset),
            ),
            const Divider(height: 32),
            ListTile(
              key: const Key('beautifierQuickOff'),
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Off'),
              trailing: !camera.beautifierEnabled
                  ? const Icon(Icons.check)
                  : null,
              onTap: chooseOff,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetSection extends StatelessWidget {
  const _PresetSection({
    required this.title,
    required this.description,
    required this.presets,
    required this.selected,
    required this.keyPrefix,
    required this.onSelected,
  });

  final String title;
  final String description;
  final List<String> presets;
  final String? selected;
  final String keyPrefix;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      Text(description, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in presets)
            ChoiceChip(
              key: Key('beautifierQuick${keyPrefix}_$preset'),
              label: Text(preset),
              selected: selected == preset,
              onSelected: (_) => onSelected(preset),
            ),
          TextButton.icon(
            key: Key('beautifierQuick${keyPrefix}_Custom'),
            onPressed: () => onSelected('Custom'),
            icon: Icon(
              selected == 'Custom' ? Icons.check : Icons.tune,
              size: 18,
            ),
            label: const Text('Customize…'),
          ),
        ],
      ),
    ],
  );
}
