import 'dart:math' as math;
import 'frame_analysis.dart';
import 'models.dart';

enum PhotographicSituation {
  auto('Auto'),
  portrait('Portrait'),
  group('Group'),
  personScene('Person + Scene'),
  landscape('Landscape'),
  action('Action'),
  closeUp('Close-up'),
  food('Food');

  const PhotographicSituation(this.title);
  final String title;
  bool get showsPersonOverlay =>
      [portrait, group, personScene, action].contains(this);
  bool get supportsPoseGuidance => this == portrait || this == personScene;
  String? get catalogKind => showsPersonOverlay
      ? 'pose'
      : this == landscape
      ? 'landscape'
      : this == food
      ? 'food'
      : null;
}

class SituationSignals {
  const SituationSignals({
    this.person,
    this.face,
    this.group,
    this.salientObject,
    this.faceCount = 0,
    this.peopleAvailable = false,
    this.groupAvailable = false,
    this.saliencyAvailable = false,
    this.motion,
    this.subjectMotion,
    this.horizon,
    this.horizonConfidence = 0,
    this.openAreaRatio,
  });
  final DetectionBox? person;
  final DetectionBox? face;
  final GroupAnalysis? group;
  final DetectionBox? salientObject;
  final int faceCount;
  final bool peopleAvailable;
  final bool groupAvailable;
  final bool saliencyAvailable;
  final MotionAnalysis? motion;
  final double? subjectMotion;
  final HorizonAnalysis? horizon;
  final double horizonConfidence;
  final double? openAreaRatio;

  SituationSignals withSubjectMotion(double? value) => SituationSignals(
    person: person,
    face: face,
    group: group,
    salientObject: salientObject,
    faceCount: faceCount,
    peopleAvailable: peopleAvailable,
    groupAvailable: groupAvailable,
    saliencyAvailable: saliencyAvailable,
    motion: motion,
    subjectMotion: value,
    horizon: horizon,
    horizonConfidence: horizonConfidence,
    openAreaRatio: openAreaRatio,
  );
}

/// Mirrors the reference's three-candidate-frame hysteresis and ambiguous hold.
class SituationClassifier {
  SituationClassifier({this.requiredStableFrames = 3});
  final int requiredStableFrames;
  PhotographicSituation recommendation = PhotographicSituation.personScene;
  PhotographicSituation? _candidate;
  int _count = 0;

  PhotographicSituation update(SituationSignals signals) {
    final next = candidate(signals);
    if (next == null || next == recommendation) {
      _candidate = null;
      _count = 0;
    } else {
      _count = _candidate == next ? _count + 1 : 1;
      _candidate = next;
      if (_count >= math.max(1, requiredStableFrames)) {
        recommendation = next;
        _candidate = null;
        _count = 0;
      }
    }
    return recommendation;
  }

  static PhotographicSituation? candidate(SituationSignals signals) {
    if (math.max(signals.group?.peopleCount ?? 0, signals.faceCount) >= 2) {
      return PhotographicSituation.group;
    }
    if (signals.person != null) {
      if ((signals.subjectMotion ?? 0) >= .16) {
        return PhotographicSituation.action;
      }
      if (signals.person!.rect.area >= .2 ||
          (signals.face?.rect.area ?? 0) >= .035) {
        return PhotographicSituation.portrait;
      }
      return PhotographicSituation.personScene;
    }
    if (signals.horizonConfidence >= .45) {
      return PhotographicSituation.landscape;
    }
    final object = signals.salientObject;
    if (object != null && object.confidence >= .35 && object.rect.area >= .18) {
      return PhotographicSituation.closeUp;
    }
    if ((signals.openAreaRatio ?? 0) >= .5) {
      return PhotographicSituation.landscape;
    }
    return null;
  }
}

/// Reference subject speed requires closely spaced frames and a steady camera.
class SubjectMotionTracker {
  DetectionBox? _previous;
  DateTime? _timestamp;
  void reset() {
    _previous = null;
    _timestamp = null;
  }

  double? update(SituationSignals signals, DateTime timestamp) {
    final previous = _previous;
    final priorTime = _timestamp;
    _previous = signals.person;
    _timestamp = signals.person == null ? null : timestamp;
    if (signals.motion == null ||
        signals.motion!.magnitude >= .3 ||
        signals.person == null ||
        previous == null ||
        priorTime == null) {
      return null;
    }
    final interval = timestamp.difference(priorTime).inMicroseconds / 1000000;
    if (interval <= .08 || interval >= .8) return null;
    final next = signals.person!.rect;
    final prior = previous.rect;
    return math.sqrt(
          math.pow(next.x + next.width / 2 - prior.x - prior.width / 2, 2) +
              math.pow(
                next.y + next.height / 2 - prior.y - prior.height / 2,
                2,
              ),
        ) /
        interval;
  }
}

/// Only use multi-person-capable detections here, never a single-pose extent.
GroupAnalysis? analyzeGroup(
  List<DetectionBox> people,
  List<DetectionBox> faces,
) {
  final boxes = people.isEmpty
      ? faces.map((face) {
          final r = face.rect;
          final width = math.min(.9, r.width * 3);
          final height = math.min(.95, r.height * 6.2);
          return DetectionBox(
            rect: NormalizedRect(
              x: (r.x + r.width / 2 - width / 2).clamp(0, 1 - width),
              y: (r.y - r.height * .45).clamp(0, 1 - height),
              width: width,
              height: height,
            ),
            confidence: face.confidence * .72,
            label: 'person_estimated',
          );
        }).toList()
      : people;
  if (boxes.length <= 1 && faces.length <= 1) return null;
  if (boxes.isEmpty) return null;
  final nearestEdge = boxes
      .expand(
        (box) => [
          box.rect.minX,
          box.rect.minY,
          1 - box.rect.maxX,
          1 - box.rect.maxY,
        ],
      )
      .reduce(math.min);
  final centers = boxes.map((box) => box.rect.x + box.rect.width / 2).toList()
    ..sort();
  final averageWidth =
      boxes.fold(0.0, (sum, box) => sum + box.rect.width) / boxes.length;
  final left = boxes.map((box) => box.rect.minX).reduce(math.min);
  final top = boxes.map((box) => box.rect.minY).reduce(math.min);
  final right = boxes.map((box) => box.rect.maxX).reduce(math.max);
  final bottom = boxes.map((box) => box.rect.maxY).reduce(math.max);
  return GroupAnalysis(
    peopleCount: boxes.length,
    faceCount: faces.length,
    groupBounds: NormalizedRect(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    ),
    faceVisibilityRatio: (faces.length / boxes.length).clamp(0, 1),
    edgeCrowdingScore: ((.06 - nearestEdge) / .06).clamp(0, 1),
    spacingScore: centers.length <= 1
        ? null
        : (centers.last - centers.first) /
              (centers.length - 1) /
              math.max(.001, averageWidth),
  );
}

class SituationGuidance {
  const SituationGuidance(this.title, this.detail, this.tone);
  final String title;
  final String detail;
  final AdviceTone tone;
  Advice get advice => Advice(
    type: 'situation',
    recipient: 'Photographer',
    instruction: title,
    tone: tone,
  );
}

SituationGuidance situationGuidance(
  PhotographicSituation situation,
  SituationSignals signals,
) {
  const warning = AdviceTone.warning;
  const ready = AdviceTone.ready;
  const waiting = AdviceTone.waiting;
  switch (situation) {
    case PhotographicSituation.group:
      final group = signals.group;
      if (group == null) {
        if (signals.groupAvailable) {
          return const SituationGuidance(
            'Bring everyone into frame',
            'Step back until every person is visible.',
            warning,
          );
        }
        return const SituationGuidance(
          'Check everyone is in frame',
          'Group measurements are unavailable. Make every face visible before taking the photo.',
          waiting,
        );
      }
      if (group.faceVisibilityRatio < .8) {
        return const SituationGuidance(
          'Make every face visible',
          'Ask the group to adjust so no face is blocked.',
          warning,
        );
      }
      if (group.edgeCrowdingScore > .35) {
        return const SituationGuidance(
          'Leave space at the edges',
          'Step back slightly so nobody is cut off.',
          warning,
        );
      }
      if ((group.spacingScore ?? 0) > 1.8) {
        return const SituationGuidance(
          'Bring the group closer',
          'Reduce the gaps between people.',
          warning,
        );
      }
      return const SituationGuidance(
        'Group looks ready',
        'Keep every face visible and take the photo.',
        ready,
      );
    case PhotographicSituation.action:
      if (!signals.peopleAvailable) {
        return const SituationGuidance(
          'Frame the moving subject',
          'Subject detection is unavailable. Leave space for movement.',
          waiting,
        );
      }
      final person = signals.person;
      if (person == null) {
        return const SituationGuidance(
          'Find the moving subject',
          'Frame the subject before following the action.',
          warning,
        );
      }
      if (person.rect.minX < .06 || person.rect.maxX > .94) {
        return const SituationGuidance(
          'Give the subject more room',
          'Keep space around them so movement stays in frame.',
          warning,
        );
      }
      if ((signals.motion?.magnitude ?? 0) > .5) {
        return const SituationGuidance(
          'Track more smoothly',
          'Follow the subject steadily before pressing the shutter.',
          warning,
        );
      }
      if ((signals.subjectMotion ?? 0) >= .16) {
        return const SituationGuidance(
          'Keep following the action',
          'Track the subject and take the photo as the moment develops.',
          waiting,
        );
      }
      if (signals.subjectMotion == null) {
        return const SituationGuidance(
          'Leave room for movement',
          'Keep following the subject; motion measurements are not ready.',
          waiting,
        );
      }
      return const SituationGuidance(
        'Action frame looks ready',
        'Leave room for movement and take the photo at the peak moment.',
        ready,
      );
    case PhotographicSituation.closeUp:
      if ((signals.motion?.magnitude ?? 0) > .22) {
        return const SituationGuidance(
          'Steady the close-up',
          'Hold the phone still so the detail stays sharp.',
          warning,
        );
      }
      if (!signals.saliencyAvailable) {
        return const SituationGuidance(
          'Choose one clear detail',
          'Object detection is unavailable. Keep its edges in frame and the background simple.',
          waiting,
        );
      }
      final object = signals.salientObject;
      if (object == null) {
        return const SituationGuidance(
          'Choose one clear detail',
          'Center the object you want Dali to evaluate.',
          warning,
        );
      }
      if (object.rect.area < .18) {
        return const SituationGuidance(
          'Move closer to the detail',
          'Fill more of the frame while keeping the subject sharp.',
          warning,
        );
      }
      if (object.rect.area > .72 ||
          object.rect.minX < .025 ||
          object.rect.maxX > .975) {
        return const SituationGuidance(
          'Give the detail more space',
          'Step back slightly so its edges are not cut off.',
          warning,
        );
      }
      if ((signals.motion?.rollDegrees.abs() ?? 0) > 3) {
        return const SituationGuidance(
          'Align the subject',
          'Rotate the phone slightly to straighten the composition.',
          warning,
        );
      }
      return SituationGuidance(
        'Close-up looks ready',
        'Keep the background simple and take the photo.',
        signals.motion == null ? waiting : ready,
      );
    case PhotographicSituation.food:
      if ((signals.motion?.magnitude ?? 0) > .22) {
        return const SituationGuidance(
          'Steady the food photo',
          'Brace the phone before refining the composition.',
          warning,
        );
      }
      if (!signals.saliencyAvailable) {
        return const SituationGuidance(
          'Choose the hero dish',
          'Object detection is unavailable. Keep one plate or detail the clear center of attention.',
          waiting,
        );
      }
      if (signals.salientObject == null) {
        return const SituationGuidance(
          'Choose the hero dish',
          'Make one plate or detail the clear center of attention.',
          warning,
        );
      }
      return const SituationGuidance(
        'Food frame looks ready',
        'Keep the frame edges clean and take the photo.',
        ready,
      );
    case PhotographicSituation.landscape:
      final angle =
          signals.horizon?.angleDegrees ?? signals.motion?.rollDegrees;
      if (angle != null && angle.abs() > 2.5) {
        return SituationGuidance(
          signals.horizon == null ? 'Level the camera' : 'Level the horizon',
          angle > 0
              ? 'Rotate the phone slightly counterclockwise.'
              : 'Rotate the phone slightly clockwise.',
          warning,
        );
      }
      if (signals.horizonConfidence > .2) {
        return const SituationGuidance(
          'Horizon looks level',
          'Place the horizon away from the center, then include a foreground element for depth.',
          ready,
        );
      }
      return const SituationGuidance(
        'Build depth in the scene',
        'Include a nearby subject, a middle distance, and the background before taking the photo.',
        warning,
      );
    default:
      return const SituationGuidance(
        'Checking the scene',
        'Hold the camera steady while Dali chooses a situation.',
        waiting,
      );
  }
}
