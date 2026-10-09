import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'camera_controller.dart';

class ShutterSettings extends StatelessWidget {
  const ShutterSettings({super.key, required this.camera});
  final CameraController camera;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('shutterControlsGroup'),
    title: const Text('Shutter Controls'),
    children: [
      const Text('Photo timer'),
      Wrap(
        spacing: 8,
        children: [0, 3, 5, 10]
            .map(
              (seconds) => ChoiceChip(
                label: Text(seconds == 0 ? 'Off' : '${seconds}s'),
                selected: camera.timerSeconds == seconds,
                onSelected: (_) {
                  camera.timerSeconds = seconds;
                  camera.persistSettings();
                },
              ),
            )
            .toList(),
      ),
      SwitchListTile(
        title: const Text('Voice shutter'),
        value: camera.voicePreferred,
        subtitle: Text(camera.voiceStatus),
        onChanged: camera.busy ? null : camera.setVoice,
      ),
      if (camera.voicePreferred)
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextFormField(
            initialValue: camera.voicePhrase,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Your shutter word or phrase',
              hintText:
                  'Cheese, Take photo, Take a picture, Capture photo, Snap a photo',
            ),
            onChanged: (text) {
              camera.voicePhrase = text;
              camera.persistSettings();
            },
          ),
        ),
      if (camera.voiceStatus.toLowerCase().contains('denied'))
        TextButton(
          onPressed: camera.host.openSettings,
          child: const Text('Open Settings'),
        ),
      const SizedBox(height: 12),
      const Text('Long-press shutter'),
      Wrap(
        spacing: 8,
        children: ['burst', 'timer', 'disabled']
            .map(
              (action) => ChoiceChip(
                label: Text(
                  action == 'burst'
                      ? 'Burst'
                      : action == 'timer'
                      ? 'Timer'
                      : 'Disabled',
                ),
                selected: camera.longPress == action,
                onSelected: (_) {
                  camera.longPress = action;
                  camera.persistSettings();
                },
              ),
            )
            .toList(),
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Burst takes up to 25 photos, saving each original before the next. Hold Timer uses 3s if the timer is Off.',
        ),
      ),
    ],
  );
}

class CaptureStyleControls extends StatelessWidget {
  const CaptureStyleControls({
    super.key,
    required this.camera,
    this.review = false,
    this.initiallyExpanded = false,
  });
  final CameraController camera;
  final bool review;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    key: const Key('filterControlsGroup'),
    title: const Text('Filters'),
    subtitle: const Text(
      'Creates a separate review copy. Original stays unchanged.',
    ),
    children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Auto chooses for the scene, Custom lets you select and fine-tune a preset, and Off applies nothing.',
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final mode in ['auto', 'custom', 'off'])
            ChoiceChip(
              label: Text(mode[0].toUpperCase() + mode.substring(1)),
              selected: mode == 'custom'
                  ? camera.filter != 'auto' && camera.filter != 'off'
                  : camera.filter == mode,
              onSelected: camera.busy
                  ? null
                  : (_) {
                      camera.useFilterMode(mode);
                      camera.persistSettings();
                    },
            ),
        ],
      ),
      if (camera.filter != 'auto' && camera.filter != 'off') ...[
        DropdownButtonFormField<String>(
          key: ValueKey('filterPreset-${camera.filter}'),
          initialValue: camera.filter,
          decoration: const InputDecoration(labelText: 'Filter preset'),
          isExpanded: true,
          items: [
            for (final name in [
              ...(camera.catalog.data['filters'] as Map).keys.cast<String>(),
              'custom',
            ])
              DropdownMenuItem(
                value: name,
                child: Text(
                  name == 'custom'
                      ? 'Custom'
                      : camera.catalog.data['filters'][name]['title'] as String,
                ),
              ),
          ],
          onChanged: camera.busy
              ? null
              : (name) {
                  if (name != null) {
                    camera.filter = name;
                    camera.persistSettings();
                  }
                },
        ),
        ExpansionTile(
          title: const Text('Individual settings'),
          children: [
            const Text(
              'Moving any slider copies the current preset into Custom, then changes that individual setting.',
            ),
            for (final field in PhotoStyle.fields)
              Column(
                children: [
                  Text(
                    '${field == "blueSky" ? "Blue sky" : field[0].toUpperCase() + field.substring(1)}: ${camera.style.value(field)}',
                  ),
                  Slider(
                    key: Key('photoFilter$field'),
                    value: camera.style.value(field).toDouble(),
                    min: ['exposure', 'warmth', 'contrast'].contains(field)
                        ? -5
                        : 0,
                    max: 5,
                    divisions:
                        ['exposure', 'warmth', 'contrast'].contains(field)
                        ? 10
                        : 5,
                    onChanged: camera.busy
                        ? null
                        : (value) {
                            camera.customStyle = {
                              for (final name in PhotoStyle.fields)
                                name: camera.style.value(name),
                            };
                            camera.customStyle[field] = value.round();
                            camera.filter = 'custom';
                            camera.persistSettings();
                          },
                  ),
                ],
              ),
          ],
        ),
      ],
      if (review)
        FilledButton.tonal(
          onPressed: camera.busy ? null : camera.applyStyle,
          child: const Text('Apply filter'),
        ),
      if (review && camera.styled)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Filter applied. Tap Save to keep the edited photo.'),
        ),
      const SizedBox(height: 12),
    ],
  );
}

class FocusExposureSettings extends StatelessWidget {
  const FocusExposureSettings({
    super.key,
    required this.camera,
    required this.onManual,
  });
  final CameraController camera;
  final VoidCallback onManual;
  @override
  Widget build(BuildContext context) {
    final state = camera.snapshot;
    return ExpansionTile(
      key: const Key('focusExposureControlsGroup'),
      title: const Text('Focus and Exposure'),
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Auto keeps focus and exposure under camera control. Manual closes this panel and places focus, depth, and exposure controls directly over the live preview.',
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Auto'),
              selected: !camera.manualWorkspace,
              onSelected: camera.controlBusy
                  ? null
                  : (_) => camera.returnAuto(),
            ),
            ChoiceChip(
              label: const Text('Manual'),
              selected: camera.manualWorkspace,
              onSelected: camera.controlBusy || state?.ready != true
                  ? null
                  : (_) => onManual(),
            ),
          ],
        ),
        if (state?.ready == true) ...[
          ListTile(
            title: const Text('Camera'),
            subtitle: Text(
              state!.cameraName ??
                  (state.front ? 'Front camera' : 'Rear camera'),
            ),
          ),
          if (state.lensName != null)
            ListTile(
              title: const Text('Lens'),
              subtitle: Text(state.lensName!),
            ),
          if (state.currentShutter != null)
            ListTile(
              title: const Text('Tv'),
              subtitle: Text(
                state.currentShutter! < 1
                    ? '1/${(1 / state.currentShutter!).round()}s'
                    : '${state.currentShutter!.toStringAsFixed(1)}s',
              ),
            ),
          if (state.currentAperture != null)
            ListTile(
              title: const Text('Av'),
              subtitle: Text('f/${state.currentAperture!.toStringAsFixed(1)}'),
            ),
          if (state.currentISO != null)
            ListTile(
              title: const Text('ISO'),
              subtitle: Text('${state.currentISO!.round()}'),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              camera.manualWorkspace
                  ? 'Manual controls are active on the preview'
                  : 'Continuous auto focus and exposure',
              style: TextStyle(
                color: camera.manualWorkspace ? Colors.teal : Colors.green,
              ),
            ),
          ),
          if (camera.manualWorkspace)
            TextButton(
              onPressed: camera.controlBusy ? null : camera.returnAuto,
              child: const Text('Return Focus and Exposure to Auto'),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Camera controls are unavailable. Start the camera to use them.',
            ),
          ),
      ],
    );
  }
}
