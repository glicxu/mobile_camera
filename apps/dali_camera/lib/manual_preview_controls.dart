import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'camera_controller.dart';
import 'camera_header.dart';

enum ManualTool { focus, depth, exposure }

/// Native preview workspace: a tool rail, with only the selected editor open.
class ManualPreviewControls extends StatefulWidget {
  const ManualPreviewControls({super.key, required this.camera});
  final CameraController camera;
  @override
  State<ManualPreviewControls> createState() => _ManualPreviewControlsState();
}

class _ManualPreviewControlsState extends State<ManualPreviewControls> {
  ManualTool? selected;
  CameraController get camera => widget.camera;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Stack(
      key: const Key('manualPreviewControls'),
      children: [
        if (selected != null)
          Positioned(
            left: math.max(10, bounds.maxWidth - 418),
            right: 78,
            bottom: 10,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0, bounds.maxHeight - 20),
              ),
              child: Container(
                key: Key('manualEditor_${selected!.name}'),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .28),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        () {}, // Editor taps must not meter the camera behind it.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(11),
                      child: editor(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 8,
          top: 8,
          bottom: 8,
          width: 58,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'M',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final tool in ManualTool.values) ...[
                    const SizedBox(height: 7),
                    toolButton(tool),
                  ],
                  const SizedBox(height: 7),
                  railButton(
                    'Auto',
                    Icons.auto_mode,
                    const Key('returnToAutoFromPreview'),
                    false,
                    camera.controlBusy
                        ? null
                        : () async {
                            await camera.returnAuto();
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget toolButton(ManualTool tool) {
    final title = switch (tool) {
      ManualTool.focus => 'Focus',
      ManualTool.depth => 'Depth',
      ManualTool.exposure => 'Exposure',
    };
    final icon = switch (tool) {
      ManualTool.focus => Icons.center_focus_strong,
      ManualTool.depth => Icons.camera,
      ManualTool.exposure => Icons.timer_outlined,
    };
    return railButton(
      title,
      icon,
      Key('manualTool$title'),
      selected == tool,
      () => setState(() => selected = selected == tool ? null : tool),
    );
  }

  Widget railButton(
    String title,
    IconData icon,
    Key key,
    bool active,
    VoidCallback? onTap,
  ) => Semantics(
    button: true,
    label: title,
    value: active ? 'Open' : 'Closed',
    onTap: onTap,
    excludeSemantics: true,
    child: Tooltip(
      message: title,
      child: Material(
        key: key,
        color: active
            ? cameraTeal.withValues(alpha: .90)
            : Colors.black.withValues(alpha: .72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: active ? .75 : .25),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 58,
            height: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19),
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget editor() {
    if (selected == ManualTool.focus) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus point',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            camera.snapshot?.supportsTap != true
                ? 'Focus point unavailable on this lens.'
                : camera.focusX == null
                ? 'Tap a point in the preview to focus there.'
                : 'Focus point selected. Tap elsewhere to move it.',
            key: const Key('manualFocusPrompt'),
            style: TextStyle(
              color: camera.focusX == null ? Colors.yellow : Colors.green,
            ),
          ),
        ],
      );
    }
    if (selected == ManualTool.depth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Background blur · ${camera.depthLevel == 0 ? "Off" : camera.depthLevel}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            key: const Key('digitalDepthOfFocus'),
            value: camera.depthLevel.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            semanticFormatterCallback: (value) =>
                'Depth of focus ${value.round()}',
            onChanged: camera.busy
                ? null
                : (value) => camera.setDepth(value.round()),
          ),
          const Text('Tap the subject first for the best separation.'),
        ],
      );
    }
    final state = camera.snapshot;
    final manualAvailable =
        state?.minimumISO != null &&
        state?.maximumISO != null &&
        state!.maximumISO! > state.minimumISO! &&
        state.minimumShutter != null &&
        state.maximumShutter != null &&
        state.maximumShutter! > state.minimumShutter!;
    final fixed = state?.manualExposure == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exposure', style: TextStyle(fontWeight: FontWeight.bold)),
        if (!manualAvailable)
          const Text('Unavailable on this lens')
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exposure time · Auto'),
            value: !fixed,
            key: const Key('manualShutterAuto'),
            onChanged: camera.controlBusy
                ? null
                : (auto) => auto
                      ? camera.returnAuto(stayInManual: true)
                      : camera.enableManualExposure(),
          ),
          if (fixed) ...[
            exposureSlider(
              'Tv',
              'previewShutterSlider',
              state.currentShutter ?? 1 / 125,
              state.minimumShutter!,
              state.maximumShutter!,
              camera.changeShutter,
              shutterLabel,
            ),
            exposureSlider(
              'ISO',
              'previewISOSlider',
              state.currentISO ?? 100,
              state.minimumISO!,
              state.maximumISO!,
              camera.changeISO,
              (value) => '${value.round()}',
            ),
          ],
        ],
        if (state != null && state.maximumEV > state.minimumEV) ...[
          const Divider(),
          Text(
            'Under / over exposure · ${(fixed ? camera.linkedEV : state.currentEV).toStringAsFixed(1)} EV',
          ),
          Slider(
            key: const Key('proExposureAdjustment'),
            min: math.max(-2, state.minimumEV),
            max: math.min(2, state.maximumEV),
            value: (fixed ? camera.linkedEV : state.currentEV).clamp(
              math.max(-2, state.minimumEV),
              math.min(2, state.maximumEV),
            ),
            divisions: 40,
            onChanged: camera.controlBusy
                ? null
                : (value) => fixed
                      ? camera.changeLinkedEV(value)
                      : camera.controls(value, state.locked),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Under'),
              TextButton(
                key: const Key('resetExposureAdjustment'),
                onPressed: camera.controlBusy
                    ? null
                    : () => fixed
                          ? camera.changeLinkedEV(0)
                          : camera.controls(0, state.locked),
                child: const Text('Reset to 0'),
              ),
              const Text('Over'),
            ],
          ),
          const Text(
            'The camera preview changes live while you drag. No Apply step is needed.',
          ),
        ],
      ],
    );
  }

  Widget exposureSlider(
    String title,
    String key,
    double value,
    double minimum,
    double maximum,
    ValueChanged<double> onChanged,
    String Function(double) label,
  ) {
    final low = math.log(minimum) / math.ln2,
        high = math.log(maximum) / math.ln2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title ${label(value)}'),
        Slider(
          key: Key(key),
          min: low,
          max: high,
          value: (math.log(value.clamp(minimum, maximum)) / math.ln2).clamp(
            low,
            high,
          ),
          divisions: math.max(
            1,
            ((high - low) * (title == 'Tv' ? 3 : 10)).round(),
          ),
          onChanged: camera.controlBusy
              ? null
              : (stop) => onChanged(math.pow(2, stop).toDouble()),
        ),
      ],
    );
  }
}

String shutterLabel(double seconds) => seconds < 1
    ? '1/${(1 / seconds).round()}s'
    : '${seconds.toStringAsFixed(1)}s';
