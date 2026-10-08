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
  });
  final CameraController camera;
  final bool review;
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
            'faceBrightness': 'Face brightness',
            'skinSmoothing': 'Skin smoothing',
            'blemishReduction': 'Blemish reduction',
            'eyeEnlargement': 'Eye enlargement',
            'lipPlumping': 'Lip plumping',
          }
        : {'sky': 'Sky enhancement', 'landscapeColor': 'Landscape color'};
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in treatmentTitles.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: treatment == entry.key,
                  onSelected: camera.busy
                      ? null
                      : (_) {
                          if (review) {
                            camera.reviewTreatment = entry.key;
                          } else {
                            camera.customBeautifier = entry.key;
                            camera.beautifier = 'custom';
                          }
                          update();
                        },
                ),
            ],
          ),
          if (treatment != 'enhance')
            Wrap(
              spacing: 8,
              children: [
                for (final preset
                    in treatment == 'portrait'
                        ? ['Natural', 'Polished', 'Glam', 'Custom']
                        : ['Natural', 'Vivid', 'Dramatic', 'Custom'])
                  ChoiceChip(
                    label: Text(preset),
                    selected: (settings['preset'] ?? 'Custom') == preset,
                    onSelected: camera.busy
                        ? null
                        : (_) {
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
              ],
            ),
          Text('Level $strength of 5'),
          Slider(
            min: 0,
            max: 5,
            divisions: 5,
            value: strength.toDouble(),
            onChanged: camera.busy
                ? null
                : (value) {
                    settings['strength'] = value.round();
                    settings['preset'] = 'Custom';
                    update();
                  },
          ),
          for (final entry in names.entries)
            SwitchListTile(
              title: Text(entry.value),
              value:
                  flags[entry.key] as bool? ??
                  (entry.key != 'lipPlumping' || review),
              onChanged: camera.busy
                  ? null
                  : (value) {
                      flags[entry.key] = value;
                      settings['preset'] = 'Custom';
                      update();
                    },
            ),
        ],
      ],
    );
  }
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
