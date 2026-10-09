import 'package:flutter/material.dart';
import 'camera_controller.dart';
import 'package:dali_camera_core/dali_camera_core.dart';

const treatmentTitles = {
  'enhance': 'General Enhance',
  'portrait': 'Portrait Polish',
  'landscape': 'Landscape Polish',
};

class PhotoEffectControls extends StatelessWidget {
  const PhotoEffectControls({
    super.key,
    required this.camera,
    this.review = false,
    this.allowedTreatments = const ['enhance', 'portrait', 'landscape'],
    this.showTreatmentSelector = true,
  });
  final CameraController camera;
  final bool review;
  final List<String> allowedTreatments;
  final bool showTreatmentSelector;
  @override
  Widget build(BuildContext context) {
    final treatment = review ? camera.reviewTreatment : camera.customBeautifier;
    final profiles = review
        ? camera.reviewTreatments
        : camera.captureTreatments;
    final settings = profiles[treatment]!;
    final flags = settings['flags'] as Map;
    final strength = (settings['strength'] as num).toInt().clamp(0, 5);
    final names = treatment == 'enhance'
        ? {
            'autoTone': 'Auto tone',
            'warmth': 'Warmth',
            'vibrance': 'Vibrance',
            'clarity': 'Clarity',
            'noiseReduction': 'Noise reduction',
            'subjectEmphasis': 'Subject emphasis',
          }
        : treatment == 'portrait'
        ? {
            'faceBrightness': 'Brighten and even skin',
            'skinSmoothing': 'Smooth skin',
            'blemishReduction': 'Reduce blemishes',
            'eyeEnlargement': 'Enlarge eyes',
            'lipPlumping': 'Plump lips',
          }
        : {
            'sky': 'Blue sky & cloud detail',
            'landscapeColor': 'Rich landscape color',
          };
    void update() => review
        ? camera.requestReviewTreatment(camera.reviewTreatment)
        : camera.persistSettings();
    return ExpansionTile(
      initiallyExpanded: review,
      title: Text(review ? 'Photo treatment' : 'Beautifier'),
      children: [
        if (!review)
          Wrap(
            spacing: 8,
            children: [
              for (final mode in ['auto', 'custom', 'off'])
                ChoiceChip(
                  label: Text(
                    mode == 'auto'
                        ? 'Auto'
                        : mode == 'custom'
                        ? 'Custom'
                        : 'Off',
                  ),
                  selected: camera.beautifier == mode,
                  onSelected: camera.busy
                      ? null
                      : (_) {
                          camera.beautifier = mode;
                          update();
                        },
                ),
            ],
          ),
        if (!review && camera.beautifier == 'auto')
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Auto uses ${treatmentTitles[camera.captureTreatment]} for ${camera.activeSituation.title}.',
            ),
          ),
        if (review || camera.beautifier == 'custom') ...[
          if (showTreatmentSelector)
            DropdownButtonFormField<String>(
              key: ValueKey('beautifierType_${review}_$treatment'),
              initialValue: treatment,
              decoration: InputDecoration(
                labelText: review && treatment != 'portrait'
                    ? 'Enhancement type'
                    : 'Beautifier type',
              ),
              isExpanded: true,
              items: [
                for (final entry in treatmentTitles.entries)
                  if (allowedTreatments.contains(entry.key))
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
              ],
              onChanged: camera.busy && !review
                  ? null
                  : (value) {
                      if (value == null) return;
                      if (review) {
                        camera.reviewTreatment = value;
                      } else {
                        camera.customBeautifier = value;
                        camera.beautifier = 'custom';
                      }
                      update();
                    },
            ),
          if (treatment != 'enhance') ...[
            DropdownButtonFormField<String>(
              key: ValueKey(
                'beautifierPreset_${review}_${treatment}_${settings['preset']}',
              ),
              initialValue: settings['preset'] as String? ?? 'Custom',
              decoration: InputDecoration(
                labelText: treatment == 'portrait'
                    ? 'Portrait preset'
                    : 'Landscape preset',
              ),
              isExpanded: true,
              items: [
                for (final preset
                    in treatment == 'portrait'
                        ? ['Natural', 'Polished', 'Glam', 'Custom']
                        : ['Natural', 'Vivid', 'Dramatic', 'Custom'])
                  DropdownMenuItem(value: preset, child: Text(preset)),
              ],
              onChanged: camera.busy && !review
                  ? null
                  : (preset) {
                      if (preset == null) return;
                      settings['preset'] = preset;
                      if (preset != 'Custom') {
                        settings['strength'] = preset == 'Natural'
                            ? 2
                            : (preset == 'Polished' || preset == 'Vivid')
                            ? 3
                            : 4;
                        settings['flags'] = treatment == 'portrait'
                            ? <String, bool>{
                                'eyeEnlargement': preset != 'Natural',
                                'lipPlumping': preset == 'Glam',
                              }
                            : <String, bool>{'sky': preset != 'Natural'};
                      }
                      update();
                    },
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                "${settings['preset'] ?? 'Custom'} combines the settings below. Changing any individual setting creates Custom.",
              ),
            ),
          ],
          if (treatment != 'enhance')
            ExpansionTile(
              key: ValueKey('beautifierIndividual_${review}_$treatment'),
              title: Text(
                treatment == 'portrait'
                    ? 'Portrait individual settings'
                    : 'Landscape individual settings',
              ),
              children: [
                ...individualControls(
                  camera,
                  settings,
                  names,
                  flags,
                  strength,
                  update,
                ),
              ],
            )
          else
            ...individualControls(
              camera,
              settings,
              names,
              flags,
              strength,
              update,
            ),
        ],
      ],
    );
  }

  List<Widget> individualControls(
    CameraController camera,
    Map<String, dynamic> settings,
    Map<String, String> names,
    Map flags,
    int strength,
    VoidCallback update,
  ) => [
    Text('Level $strength of 5'),
    Slider(
      min: review ? 0 : 1,
      max: 5,
      divisions: review ? 5 : 4,
      value: strength.toDouble().clamp(review ? 0 : 1, 5),
      onChanged: camera.busy && !review
          ? null
          : (value) {
              settings['strength'] = value.round();
              settings['preset'] = 'Custom';
              update();
            },
    ),
    if (review || settings != camera.captureTreatments['enhance'])
      for (final entry in names.entries)
        SwitchListTile(
          title: Text(entry.value),
          value:
              flags[entry.key] as bool? ??
              (entry.key != 'lipPlumping' || review),
          onChanged: camera.busy && !review
              ? null
              : (value) {
                  flags[entry.key] = value;
                  settings['preset'] = 'Custom';
                  update();
                },
        ),
  ];
}

class PhotoAnalysisCard extends StatelessWidget {
  const PhotoAnalysisCard({super.key, required this.camera});
  final CameraController camera;
  @override
  Widget build(BuildContext context) {
    final analysis = camera.photoAnalysis;
    if (analysis == null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(camera.analysisError ?? 'Analyzing photo…'),
      );
    }
    final faces = analysis['faces'] as List? ?? [];
    final points = analysis['poseKeypoints'] as Map? ?? {};
    final faceCount =
        (analysis['groupAnalysis'] as Map?)?['faceCount'] as int? ??
        faces.length;
    final luminance = analysis['backgroundLuminance'] as num?;
    return ExpansionTile(
      title: const Text('Photo analysis'),
      subtitle: Text(
        '$faceCount ${faceCount == 1 ? 'face' : 'faces'} · ${points.length} pose landmarks',
      ),
      children: [
        DropdownButton<PosePackageId>(
          value: camera.coachingPackage,
          items: [
            for (final value in PosePackageId.values)
              DropdownMenuItem(
                value: value,
                child: Text(
                  value == PosePackageId.neutral
                      ? 'Natural'
                      : value == PosePackageId.groupPortrait
                      ? 'Group'
                      : value.name[0].toUpperCase() + value.name.substring(1),
                ),
              ),
          ],
          onChanged: camera.busy
              ? null
              : (value) {
                  if (value != null) camera.setCoachingPackage(value);
                },
        ),
        for (final signal in ['people', 'face', 'pose', 'horizon', 'saliency'])
          if (analysis['${signal}Status'] == 'unavailable' ||
              analysis['${signal}Status'] == 'unsupported')
            Text('$signal detection ${analysis['${signal}Status']}'),
        if (luminance != null)
          Text(
            'Background brightness: ${(luminance * (analysis['luminanceScale'] == 255 ? 1 : 255)).round()} / 255',
          ),
        if (analysis['reframe'] is Map)
          Text(
            (analysis['reframe'] as Map)['instruction'] as String? ??
                'Reframe available',
          ),
        if (analysis['horizon'] is Map)
          Text(
            'Horizon tilt: ${((analysis['horizon'] as Map)['angleDegrees'] as num).toStringAsFixed(1)}°',
          ),
        if (analysis['faceLuminance'] is num)
          Text(
            'Face brightness: ${(analysis['faceLuminance'] as num).round()} / 255',
          ),
        if (analysis['poseAnalysis'] is Map) ...[
          if ((analysis['poseAnalysis'] as Map)['shoulderLineAngleDegrees']
              is num)
            Text(
              'Shoulder angle: ${((analysis['poseAnalysis'] as Map)['shoulderLineAngleDegrees'] as num).toStringAsFixed(1)}°',
            ),
          if ((analysis['poseAnalysis'] as Map)['armVisibilityScore'] is num)
            Text(
              'Arm visibility: ${(((analysis['poseAnalysis'] as Map)['armVisibilityScore'] as num) * 100).round()}%',
            ),
        ],
        for (final issue
            in (analysis['issues'] as List? ?? []).whereType<Map>())
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${issue['recipient']}: ${issue['instruction']}'),
          ),
        if (camera.debug) SelectableText(analysis.toString()),
      ],
    );
  }
}
