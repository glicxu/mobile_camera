import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'camera_controller.dart';
import 'coaching_overlay.dart';
import 'distance_swipe.dart';

Color guidanceColor(AdviceTone tone) => switch (tone) {
  AdviceTone.ready => Colors.green,
  AdviceTone.waiting => Colors.yellow,
  _ => Colors.orange,
};

class LiveGuidancePanel extends StatelessWidget {
  const LiveGuidancePanel({
    super.key,
    required this.camera,
    required this.onExample,
  });
  final CameraController camera;
  final ValueChanged<CatalogEntry> onExample;
  @override
  Widget build(BuildContext context) {
    final reference = camera.guidance.entry;
    final pose = reference?.kind == 'pose';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reference != null)
          _ReferenceCard(
            camera: camera,
            item: reference,
            onExample: () => onExample(reference),
          ),
        if (!pose) _SceneCard(camera: camera),
        if (pose)
          Container(
            key: const Key('guidedControls'),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  camera.guidance.complete
                      ? 'Sequence finished'
                      : 'Step ${camera.guidance.index + 1} of ${camera.guidance.cues.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                TextButton(
                  onPressed: () => camera.choose(null),
                  child: const Text('Natural'),
                ),
                if (!camera.guidance.complete)
                  OutlinedButton(
                    onPressed: camera.next,
                    child: const Text('Next'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.camera});
  final CameraController camera;
  @override
  Widget build(BuildContext context) {
    final color = guidanceColor(camera.advice.tone);
    final situation = camera.activeSituation;
    final icon = camera.advice.direction != null
        ? coachingDirectionIcon(camera.advice.direction!)
        : switch (situation) {
            PhotographicSituation.group => Icons.groups,
            PhotographicSituation.action => Icons.directions_run,
            PhotographicSituation.landscape => Icons.landscape,
            PhotographicSituation.food => Icons.restaurant,
            PhotographicSituation.closeUp => Icons.center_focus_strong,
            _ => Icons.person_outline,
          };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('situationGuidanceCard'),
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .9), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (camera.shootingMode == PhotographicSituation.auto
                            ? 'Auto \u00b7 ${situation.title}'
                            : situation == PhotographicSituation.landscape
                            ? 'Landscape guidance'
                            : situation.title)
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                _StatusLight(color: color, label: camera.advice.statusTitle),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              camera.advice.instruction,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              camera.guidanceDetail.isNotEmpty
                  ? camera.guidanceDetail
                  : 'Dali is analyzing the live camera view.',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.camera,
    required this.item,
    required this.onExample,
  });
  final CameraController camera;
  final CatalogEntry item;
  final VoidCallback onExample;
  @override
  Widget build(BuildContext context) {
    final pose = item.kind == 'pose';
    final color = pose ? guidanceColor(camera.advice.tone) : Colors.teal;
    const categories = {
      'standing': 'Standing',
      'seated': 'Seated',
      'kneeling': 'Kneeling',
      'moving': 'Moving',
      'turned': 'Turned / Looking Away',
      'handsHair': 'Hands & Details',
      'lying': 'Lying Safely',
    };
    const settings = {
      'indoor': 'Indoor',
      'outdoor': 'Outdoor',
      'both': 'Indoor & Outdoor',
    };
    return Semantics(
      label: '${pose ? "Posture" : "Composition"}, ${item.title}',
      hint: pose
          ? 'Tap for a photo example. Swipe left or right for another posture.'
          : 'Tap for the full example and safety note.',
      customSemanticsActions: pose
          ? {
              const CustomSemanticsAction(label: 'Previous posture'): () =>
                  camera.adjacentReference(-1),
              const CustomSemanticsAction(label: 'Next posture'): () =>
                  camera.adjacentReference(1),
            }
          : null,
      child: DistanceSwipe(
        key: const Key('activeReferenceCard'),
        minimumDistance: 44,
        onSwipe: pose ? camera.adjacentReference : null,
        onTap: onExample,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: pose
                ? color.withValues(alpha: .16)
                : Colors.black.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: pose ? .9 : .65),
              width: pose ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  item.asset,
                  width: 86,
                  height: 96,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (pose)
                          _StatusLight(
                            color: color,
                            label: camera.advice.statusTitle,
                          ),
                      ],
                    ),
                    if (pose)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${categories[item.data['category']] ?? item.data['category']} \u00b7 ${settings[item.data['setting']] ?? item.data['setting']}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      item.cues.join(' '),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Recommended angle: ${camera.catalog.angleTitle(item)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${pose ? "Lighting" : "Best light"}: ${camera.catalog.lightTitle(item)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLight extends StatelessWidget {
  const _StatusLight({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .5),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(5),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}
