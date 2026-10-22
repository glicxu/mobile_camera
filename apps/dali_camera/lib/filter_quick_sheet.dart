import 'package:flutter/material.dart';

import 'camera_controller.dart';

Future<void> showFilterQuickSheet(
  BuildContext context,
  CameraController camera,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => _FilterQuickSheet(
    camera: camera,
    onSelected: () => Navigator.of(sheetContext).pop(),
  ),
);

class _FilterQuickSheet extends StatelessWidget {
  const _FilterQuickSheet({required this.camera, required this.onSelected});

  final CameraController camera;
  final VoidCallback onSelected;

  Future<void> choose(Future<void> Function() selection) async {
    await selection();
    onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final filters = camera.catalog.data['filters'] as Map;
    final selected = camera.filterEnabled
        ? camera.filterMode == 'auto'
              ? 'auto'
              : camera.customFilter
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Choose a color look for new photos, use Auto, or turn Filters off.',
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('filterQuickAuto'),
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Auto'),
              subtitle: const Text('Chooses a filter for the detected scene.'),
              trailing: selected == 'auto' ? const Icon(Icons.check) : null,
              onTap: () => choose(camera.selectFilterAuto),
            ),
            const Divider(),
            Text('Presets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in filters.entries)
                  ChoiceChip(
                    key: Key('filterQuick_${entry.key}'),
                    label: Text(entry.value['title'] as String),
                    selected: selected == entry.key,
                    onSelected: (_) => choose(
                      () => camera.selectFilterPreset(entry.key as String),
                    ),
                  ),
                TextButton.icon(
                  key: const Key('filterQuickCustom'),
                  onPressed: () => choose(camera.selectFilterCustom),
                  icon: Icon(
                    selected == 'custom' ? Icons.check : Icons.tune,
                    size: 18,
                  ),
                  label: const Text('Customize…'),
                ),
              ],
            ),
            const Divider(height: 32),
            ListTile(
              key: const Key('filterQuickOff'),
              leading: const Icon(Icons.filter_alt_off_outlined),
              title: const Text('Off'),
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () => choose(camera.selectFilterOff),
            ),
          ],
        ),
      ),
    );
  }
}
