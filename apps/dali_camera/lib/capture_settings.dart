import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'camera_controller.dart';
import 'dart:math' as math;

class ManualCameraTools extends StatelessWidget {
  const ManualCameraTools({super.key, required this.camera});
  final CameraController camera;
  @override
  Widget build(BuildContext context) {
    final state = camera.snapshot;
    if (state?.minimumISO == null || state?.minimumShutter == null) {
      return const SizedBox.shrink();
    }
    final seconds = (state!.currentShutter ?? 1 / 125).clamp(
      state.minimumShutter!,
      state.maximumShutter!,
    );
    final iso = (state.currentISO ?? 100).clamp(
      state.minimumISO!,
      state.maximumISO!,
    );
    final fixed = state.manualExposure == true;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('Focus and Exposure'),
          const Text('Tap the preview to choose a focus point.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto exposure'),
            value: !fixed,
            onChanged: camera.controlBusy
                ? null
                : (auto) =>
                      auto ? camera.returnAuto() : camera.manual(seconds, iso),
          ),
          Text(
            'Tv ${seconds < 1 ? '1/${(1 / seconds).round()}' : seconds.toStringAsFixed(1)}s · ISO ${iso.round()}',
          ),
          if (fixed) ...[
            const Text('Shutter time'),
            Slider(
              min: math.log(state.minimumShutter!),
              max: math.log(state.maximumShutter!),
              value: math.log(seconds),
              onChanged: camera.controlBusy
                  ? null
                  : (value) => camera.manual(math.exp(value), iso),
            ),
            const Text('ISO'),
            Slider(
              min: state.minimumISO!,
              max: state.maximumISO!,
              value: iso,
              onChanged: camera.controlBusy
                  ? null
                  : (value) => camera.manual(seconds, value),
            ),
          ],
          TextButton(
            onPressed: camera.controlBusy ? null : camera.returnAuto,
            child: const Text('Return to Auto'),
          ),
        ],
      ),
    );
  }
}

class ShutterSettings extends StatelessWidget {
  const ShutterSettings({super.key, required this.camera});
  final CameraController camera;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Shutter controls'),
    children: [
      const Text('Timer'),
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
      const SizedBox(height: 12),
      const Text('Hold shutter'),
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
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextFormField(
          initialValue: camera.voicePhrase,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Custom voice phrase',
            hintText: 'Cheese, Take photo, Capture photo, Snap a photo',
          ),
          onChanged: (text) {
            camera.voicePhrase = text;
            camera.persistSettings();
          },
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
  });
  final CameraController camera;
  final bool review;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Filters and watermark'),
    subtitle: const Text(
      'Creates a separate review copy. Original stays unchanged.',
    ),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in [
            'off',
            'auto',
            ...(camera.catalog.data['filters'] as Map).keys.cast<String>(),
            'custom',
          ])
            ChoiceChip(
              label: Text(
                name == 'off'
                    ? 'Off'
                    : name == 'auto'
                    ? 'Auto'
                    : name == 'custom'
                    ? 'Custom'
                    : camera.catalog.data['filters'][name]['title'] as String,
              ),
              selected: camera.filter == name,
              onSelected: camera.busy
                  ? null
                  : (_) {
                      camera.filter = name;
                      camera.persistSettings();
                    },
            ),
        ],
      ),
      if (camera.filter == 'custom')
        for (final field in PhotoStyle.fields)
          Column(
            children: [
              Text('$field: ${camera.style.value(field)}'),
              Slider(
                value: camera.style.value(field).toDouble(),
                min: ['exposure', 'warmth', 'contrast'].contains(field)
                    ? -5
                    : 0,
                max: 5,
                divisions: ['exposure', 'warmth', 'contrast'].contains(field)
                    ? 10
                    : 5,
                onChanged: camera.busy
                    ? null
                    : (value) {
                        camera.customStyle[field] = value.round();
                        camera.persistSettings();
                      },
              ),
            ],
          ),
      SwitchListTile(
        title: const Text('Dali watermark'),
        value: camera.watermark,
        onChanged: camera.busy
            ? null
            : (value) {
                camera.watermark = value;
                camera.persistSettings();
              },
      ),
      if (review)
        FilledButton.tonal(
          onPressed: camera.busy ? null : camera.applyStyle,
          child: const Text('Prepare styled copy'),
        ),
      if (review && camera.styled)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Styled copy selected. Use Save selected to export it.'),
        ),
      const SizedBox(height: 12),
    ],
  );
}
