import 'models.dart';

enum GuidedAction { subjectPose, cameraHeight, cameraPitch, photographerMove }

enum GuidedCompletion { userConfirmed }

class GuidedStep {
  const GuidedStep(this.instruction, this.action);
  final String instruction;
  final GuidedAction action;
  String get recipient =>
      action == GuidedAction.subjectPose ? 'Subject' : 'Photographer';
  GuidedCompletion get completion => GuidedCompletion.userConfirmed;
}

enum GuidedPose {
  relaxedStanding("M1", "Relaxed standing", PosePackageId.masculine, [
    "Stand with your feet comfortably apart.",
    "Relax your shoulders.",
  ]),
  threeQuarter("M2", "Three-quarter stance", PosePackageId.masculine, [
    "Turn your body slightly to your right.",
    "Bring your face back toward the camera.",
  ]),
  handInPocket("M3", "One hand in pocket", PosePackageId.masculine, [
    "Rest one hand in your pocket.",
    "Let your other arm hang loosely.",
  ]),
  seatedLean("M4", "Seated forward lean", PosePackageId.masculine, [
    "Sit and lean slightly forward.",
    "Rest your forearms on your thighs.",
  ]),
  walking("M5", "Casual walking", PosePackageId.masculine, [
    "Walk slowly across the frame.",
    "Look toward the camera for the next shot.",
  ]),
  weightShift("F1", "Weight-shift stance", PosePackageId.feminine, [
    "Rest your weight on one leg.",
    "Soften the other knee.",
  ]),
  footForward("F2", "One foot forward", PosePackageId.feminine, [
    "Place one foot slightly in front.",
    "Turn your shoulders a little toward the camera.",
  ]),
  handAtWaist("F3", "Hand at waist", PosePackageId.feminine, [
    "Rest one hand lightly at your waist.",
    "Relax your other arm.",
  ]),
  seatedAngle("F4", "Seated angled pose", PosePackageId.feminine, [
    "Sit with your knees angled slightly to one side.",
    "Turn your face toward the camera.",
  ]),
  overShoulder("F5", "Over-shoulder glance", PosePackageId.feminine, [
    "Turn your body partly away from the camera.",
    "Look back over your shoulder comfortably.",
  ]);

  const GuidedPose(this.id, this.title, this.package, this.cues);
  final String id;
  final String title;
  final PosePackageId package;
  final List<String> cues;
  List<GuidedStep> get steps => cues
      .map((cue) => GuidedStep(cue, GuidedAction.subjectPose))
      .toList(growable: false);
  Set<String> get conflicts => {
    'body_too_square',
    'body_too_profile',
    'arms_flat_against_body',
    'arm_hidden',
    if (this == overShoulder) ...{
      'face_missing',
      'face_too_profile',
      'face_turned_away',
    },
    if (this == walking) 'camera_unstable',
    if (this == seatedLean || this == seatedAngle) 'feet_cropped',
  };
}

enum GuidedCameraPosition {
  eyeLevel('C1', 'Eye level'),
  chestLevel('C2', 'Chest level'),
  waistLevel('C3', 'Waist level, farther back'),
  elevated('C4', 'Slightly above eye level'),
  side('C5', 'To the side, at eye level');

  const GuidedCameraPosition(this.id, this.title);
  final String id;
  final String title;
  List<GuidedStep> steps({bool moveRight = false}) => switch (this) {
    eyeLevel => [
      const GuidedStep(
        'Hold the camera at their eye level.',
        GuidedAction.cameraHeight,
      ),
    ],
    chestLevel => [
      const GuidedStep(
        'Lower the camera to their chest level.',
        GuidedAction.cameraHeight,
      ),
    ],
    waistLevel => [
      const GuidedStep(
        'Lower the camera to their waist level.',
        GuidedAction.cameraHeight,
      ),
      const GuidedStep(
        'Step back until their feet fit.',
        GuidedAction.photographerMove,
      ),
    ],
    elevated => [
      const GuidedStep(
        'Raise the camera just above their eye level.',
        GuidedAction.cameraHeight,
      ),
      const GuidedStep(
        'Angle the camera down slightly.',
        GuidedAction.cameraPitch,
      ),
    ],
    side => [
      const GuidedStep(
        'Hold the camera at their eye level.',
        GuidedAction.cameraHeight,
      ),
      GuidedStep(
        moveRight
            ? 'Move a little to your right around the subject.'
            : 'Move a little to your left around the subject.',
        GuidedAction.photographerMove,
      ),
    ],
  };
}

class GuidedSession {
  GuidedSession({this.pose, this.position, this.moveRight = false});
  final GuidedPose? pose;
  final GuidedCameraPosition? position;
  final bool moveRight;
  int _stepIndex = 0;
  int get stepIndex => _stepIndex;
  bool get isActive => pose != null || position != null;
  List<GuidedStep> get steps => [
    ...?position?.steps(moveRight: moveRight),
    ...?pose?.steps,
  ];
  GuidedStep? get currentStep =>
      _stepIndex < steps.length ? steps[_stepIndex] : null;
  bool get isComplete => isActive && currentStep == null;
  Advice? get advice => !isActive
      ? null
      : Advice(
          type:
              'guided_${pose?.id ?? "none"}_${position?.id ?? "none"}_$_stepIndex',
          recipient: currentStep?.recipient ?? 'Camera',
          instruction:
              currentStep?.instruction ??
              "Sequence finished. Take a photo when you're ready.",
          tone: AdviceTone.waiting,
        );
  void advance() {
    if (_stepIndex < steps.length) _stepIndex++;
  }

  List<PhotoIssue> prioritizedIssues(List<PhotoIssue> issues) {
    if (!isActive) return issues;
    const urgent = {
      'subject_missing',
      'face_missing',
      'subject_too_close',
      'subject_too_far',
      'feet_cropped',
      'limb_cropped',
    };
    return issues
        .where(
          (issue) =>
              urgent.contains(issue.type) &&
              !(pose?.conflicts.contains(issue.type) ?? false),
        )
        .toList(growable: false);
  }
}
