import 'package:flutter/material.dart';
import 'camera_controller.dart';
import 'photo_effect_controls.dart';

class ReviewTreatmentControls extends StatelessWidget {
  const ReviewTreatmentControls({super.key, required this.camera});
  final CameraController camera;
  @override
  Widget build(BuildContext context) {
    final treatment = camera.reviewTreatment;
    final settings = camera.reviewTreatments[treatment]!;
    final strength = (settings['strength'] as num).toInt();
    final levelName = (treatment == 'enhance'
        ? ['Original', 'Natural', 'Balanced', 'Vivid', 'Dramatic', 'Max']
        : [
            'Original',
            'Natural',
            'Fresh',
            'Polished',
            'Glam',
            'Max',
          ])[strength];
    final faces = camera.photoAnalysis?['faces'] as List?;
    final status = strength == 0
        ? 'Original image unchanged'
        : camera.busy
        ? 'Updating...'
        : treatment == 'enhance'
        ? '$levelName - Whole-photo enhancement'
        : treatment == 'portrait'
        ? faces == null
              ? 'Ready'
              : faces.isEmpty
              ? 'No face detected'
              : '$levelName - Face-aware portrait polish'
        : '$levelName - Landscape polish';
    return Card(
      color: Colors.white.withValues(alpha: .07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  treatment == 'enhance'
                      ? Icons.auto_fix_high
                      : treatment == 'portrait'
                      ? Icons.face
                      : Icons.landscape,
                  color: treatment == 'enhance' ? Colors.orange : Colors.teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PopupMenuButton<String>(
                        key: const Key('reviewTreatmentMenu'),
                        tooltip: 'Photo treatment',
                        onSelected: camera.requestReviewTreatment,
                        itemBuilder: (_) => [
                          for (final item in treatmentTitles.entries)
                            CheckedPopupMenuItem(
                              value: item.key,
                              checked: item.key == treatment,
                              child: Text(item.value),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  treatmentTitles[treatment]!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(Icons.unfold_more, size: 16),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$strength \u00b7 $levelName',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              key: const Key('reviewTreatmentStrength'),
              value: strength.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              semanticFormatterCallback: (value) =>
                  '${treatmentTitles[treatment]} level ${value.round()} of 5',
              onChanged: (value) {
                settings['strength'] = value.round();
                camera.requestReviewTreatment(treatment);
              },
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  key: const Key('resetReviewTreatment'),
                  onPressed: () {
                    settings['strength'] = 0;
                    camera.requestReviewTreatment(treatment);
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
                const Text(
                  'Updates automatically',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
