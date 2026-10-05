import 'dart:math' as math;

import 'models.dart';

class CoachingEngine {
  String? _stableIssueKey;
  DateTime? _stableSince;
  Advice? _lastAdvice;
  DateTime? _lastAdviceAt;

  List<PhotoIssue> issues(
    CoachingMeasurements measurements, {
    bool includePosture = true,
    PosePackageId posePackage = PosePackageId.neutral,
  }) {
    final box = measurements.personBox;
    if (box == null) {
      return [
        const PhotoIssue(
          type: 'subject_missing',
          severity: 100,
          confidence: 0.92,
          priority: 92,
          recipient: 'Photographer',
          instruction: 'Frame the person',
          successCondition: 'person_box confidence above 0.45',
          cooldownMilliseconds: 2800,
          reasonData: {},
          tone: AdviceTone.danger,
        ),
      ];
    }

    final rect = box.rect;
    final area = rect.area;
    final result = <PhotoIssue>[];

    if (measurements.faceBox == null && area > _Thresholds.tooFarArea) {
      result.add(
        _makeIssue(
          'face_missing',
          84,
          math.max(0.52, box.confidence * 0.82),
          'Subject',
          'Face the camera',
          AdviceTone.warning,
          reasonData: {'person_area': area},
        ),
      );
    }
    if (area > _Thresholds.tooCloseArea) {
      result.add(
        _makeIssue(
          'subject_too_close',
          82,
          box.confidence,
          'Photographer',
          'Step back',
          AdviceTone.warning,
          reasonData: {'person_area': area},
        ),
      );
    }
    if (area < _Thresholds.tooFarArea) {
      result.add(
        _makeIssue(
          'subject_too_far',
          76,
          box.confidence,
          'Photographer',
          'Step closer',
          AdviceTone.warning,
          reasonData: {'person_area': area},
        ),
      );
    }
    if (rect.minY > _Thresholds.tooMuchHeadroom &&
        area > _Thresholds.tooFarArea) {
      result.add(
        _makeIssue(
          'headroom_too_large',
          62,
          box.confidence,
          'Photographer',
          'Raise camera',
          AdviceTone.warning,
          reasonData: {'headroom': rect.minY},
        ),
      );
    }
    if (rect.minY < _Thresholds.tooLittleHeadroom) {
      result.add(
        _makeIssue(
          'headroom_too_small',
          70,
          box.confidence,
          'Photographer',
          'Lower camera',
          AdviceTone.warning,
          reasonData: {'headroom': rect.minY},
        ),
      );
    }
    if (rect.maxY > 1 - _Thresholds.edgePadding &&
        area < _Thresholds.tooCloseArea) {
      result.add(
        _makeIssue(
          'feet_cropped',
          88,
          box.confidence,
          'Photographer',
          'Keep feet in frame',
          AdviceTone.danger,
          reasonData: {'bottom_edge': 1 - rect.maxY},
        ),
      );
    }
    if (rect.minX < _Thresholds.edgePadding) {
      result.add(
        _makeIssue(
          'limb_cropped',
          72,
          box.confidence,
          'Photographer',
          'Move right',
          AdviceTone.warning,
          reasonData: {'left_edge': rect.minX},
        ),
      );
    }
    if (rect.maxX > 1 - _Thresholds.edgePadding) {
      result.add(
        _makeIssue(
          'limb_cropped',
          72,
          box.confidence,
          'Photographer',
          'Move left',
          AdviceTone.warning,
          reasonData: {'right_edge': 1 - rect.maxX},
        ),
      );
    }
    if (measurements.cameraRollDegrees.abs() > _Thresholds.rollDegrees) {
      result.add(
        _makeIssue(
          'camera_tilted',
          64,
          0.7,
          'Photographer',
          measurements.cameraRollDegrees > 0 ? 'Tilt left' : 'Tilt right',
          AdviceTone.warning,
          reasonData: {'roll_degrees': measurements.cameraRollDegrees},
        ),
      );
    }
    final horizonAngle = measurements.horizonAngleDegrees;
    if (horizonAngle != null &&
        measurements.horizonConfidence > 0.55 &&
        horizonAngle.abs() > _Thresholds.horizonDegrees) {
      result.add(
        _makeIssue(
          'horizon_tilted',
          68,
          measurements.horizonConfidence,
          'Photographer',
          horizonAngle > 0 ? 'Tilt left' : 'Tilt right',
          AdviceTone.warning,
          reasonData: {'horizon_angle_degrees': horizonAngle},
        ),
      );
    }
    final faceLuminance = measurements.faceLuminance;
    final backgroundLuminance = measurements.backgroundLuminance;
    if (faceLuminance != null &&
        backgroundLuminance != null &&
        faceLuminance < _Thresholds.darkFace &&
        backgroundLuminance - faceLuminance > _Thresholds.backlitDelta) {
      result.add(
        _makeIssue(
          'subject_backlit',
          58,
          0.7,
          'Subject',
          'Face the light',
          AdviceTone.warning,
          reasonData: {
            'face_luminance': faceLuminance,
            'background_luminance': backgroundLuminance,
          },
        ),
      );
    }
    if (faceLuminance != null &&
        faceLuminance < _Thresholds.darkFace &&
        (backgroundLuminance == null ||
            backgroundLuminance - faceLuminance <= _Thresholds.backlitDelta)) {
      result.add(
        _makeIssue(
          'face_underexposed',
          54,
          0.62,
          'Photographer',
          'Find brighter light',
          AdviceTone.warning,
          reasonData: {'face_luminance': faceLuminance},
        ),
      );
    }
    if (includePosture &&
        posePackage == PosePackageId.groupPortrait &&
        measurements.groupAnalysis != null) {
      result.addAll(
        _groupPortraitIssues(measurements.groupAnalysis!, posePackage),
      );
    }
    final pose = measurements.poseAnalysis;
    if (includePosture &&
        pose != null &&
        pose.confidence > _Thresholds.poseMinimumConfidence) {
      result.addAll(_postureIssues(pose, box, posePackage));
    }
    final face = measurements.faceAnalysis;
    if (includePosture &&
        face != null &&
        face.confidence > _Thresholds.faceMinimumConfidence) {
      result.addAll(_facePostureIssues(face, posePackage));
    }
    if (area > 0.33 &&
        rect.height > 0.72 &&
        measurements.skyOrOpenAreaRatio < 0.28) {
      result.add(
        _makeIssue(
          'scene_excluded',
          50,
          box.confidence,
          'Photographer',
          'Include more view',
          AdviceTone.warning,
          reasonData: {
            'person_area': area,
            'open_area_ratio': measurements.skyOrOpenAreaRatio,
          },
        ),
      );
    }
    if (!measurements.cameraStable) {
      result.add(
        _makeIssue(
          'camera_unstable',
          46,
          0.8,
          'Photographer',
          'Hold steady',
          AdviceTone.waiting,
          reasonData: {'camera_motion': measurements.cameraMotion},
        ),
      );
    }

    result.sort((left, right) {
      final byPriority = right.priority.compareTo(left.priority);
      return byPriority != 0
          ? byPriority
          : right.severity.compareTo(left.severity);
    });
    return result;
  }

  void reset() {
    _stableIssueKey = null;
    _stableSince = null;
    _lastAdvice = null;
    _lastAdviceAt = null;
  }

  Advice selectAdvice(
    List<PhotoIssue> issues, {
    DateTime? now,
    Advice? fallback,
  }) {
    now ??= DateTime.now();
    final topIssue = issues.cast<PhotoIssue?>().firstWhere(
      (issue) => issue!.confidence > 0.45,
      orElse: () => null,
    );
    final key = topIssue?.type ?? fallback?.type ?? 'ready';
    if (_stableIssueKey != key) {
      _stableIssueKey = key;
      _stableSince = now;
    }

    final stableFor = now.difference(_stableSince!).inMicroseconds / 1000000;
    final sinceAdvice = _lastAdviceAt == null
        ? double.infinity
        : now.difference(_lastAdviceAt!).inMicroseconds / 1000000;
    final oldEnough = sinceAdvice > _Thresholds.minimumAdviceSeconds;
    final repeatedTooSoon =
        _lastAdvice?.type == key &&
        sinceAdvice < _Thresholds.repeatCooldownSeconds;
    final stableThreshold = topIssue == null
        ? _Thresholds.readyStableSeconds
        : _Thresholds.issueStableSeconds;
    if (stableFor < stableThreshold) {
      return _lastAdvice ??
          const Advice(
            type: 'waiting',
            recipient: 'Camera',
            instruction: 'Hold steady',
            tone: AdviceTone.waiting,
          );
    }
    if (topIssue == null) {
      final ready =
          fallback ??
          const Advice(
            type: 'ready',
            recipient: 'Camera',
            instruction: 'Great shot',
            tone: AdviceTone.ready,
          );
      if (oldEnough || _lastAdvice?.type != ready.type) _commit(ready, now);
      return ready;
    }
    if ((repeatedTooSoon || !oldEnough) && _lastAdvice != null) {
      return _lastAdvice!;
    }
    final advice = Advice(
      type: topIssue.type,
      recipient: topIssue.recipient,
      instruction: topIssue.instruction,
      tone: topIssue.tone,
    );
    _commit(advice, now);
    return advice;
  }

  void _commit(Advice advice, DateTime now) {
    _lastAdvice = advice;
    _lastAdviceAt = now;
  }

  List<PhotoIssue> _postureIssues(
    PoseAnalysis pose,
    DetectionBox person,
    PosePackageId package,
  ) {
    final result = <PhotoIssue>[];
    void add(
      bool condition,
      String type,
      double severity,
      double confidence,
      String recipient,
      String instruction,
      AdviceTone tone,
      Map<String, double> reasonData,
    ) {
      if (condition) {
        result.add(
          _makePoseIssue(
            type,
            severity,
            confidence,
            recipient,
            instruction,
            tone,
            package,
            reasonData: reasonData,
          ),
        );
      }
    }

    final wristFace = pose.wristToFaceDistance;
    add(
      wristFace != null && wristFace < _Thresholds.handNearFaceDistance,
      'hand_near_face',
      80,
      math.min(0.92, pose.confidence + 0.12),
      'Subject',
      'Move hand from face',
      AdviceTone.warning,
      wristFace != null ? {'wrist_to_face_distance': wristFace} : {},
    );
    add(
      pose.visibleKeypointCount >= 4 &&
          pose.armVisibilityScore < _Thresholds.armVisibility,
      'arm_hidden',
      66,
      math.max(0.48, pose.confidence),
      'Subject',
      'Show both arms',
      AdviceTone.warning,
      {'arm_visibility_score': pose.armVisibilityScore},
    );
    final square = pose.bodySquarenessScore;
    add(
      square != null &&
          square > _Thresholds.bodySquareness &&
          person.rect.width > 0.16,
      'body_too_square',
      44,
      pose.confidence,
      'Subject',
      'Turn slightly left',
      AdviceTone.waiting,
      square != null ? {'body_squareness_score': square} : {},
    );
    final profile = pose.bodyProfileScore;
    add(
      profile != null &&
          profile > _Thresholds.bodyProfile &&
          person.rect.width > 0.08,
      'body_too_profile',
      42,
      pose.confidence,
      'Subject',
      'Angle body toward camera',
      AdviceTone.waiting,
      profile != null ? {'body_profile_score': profile} : {},
    );
    final armsFlat = pose.armsFlatAgainstBodyScore;
    add(
      armsFlat != null &&
          armsFlat > _Thresholds.armsFlatAgainstBody &&
          pose.armVisibilityScore > 0.65,
      'arms_flat_against_body',
      48,
      pose.confidence,
      'Subject',
      'Separate arm from body',
      AdviceTone.waiting,
      armsFlat != null ? {'arms_flat_against_body_score': armsFlat} : {},
    );
    final wristEdge = pose.minWristEdgeDistance;
    add(
      wristEdge != null && wristEdge < _Thresholds.handCutOffEdgeDistance,
      'hand_cut_off',
      60,
      pose.confidence,
      'Photographer',
      'Keep hands in frame',
      AdviceTone.warning,
      wristEdge != null ? {'wrist_edge_distance': wristEdge} : {},
    );
    final shoulders = pose.shouldersHighScore;
    add(
      shoulders != null && shoulders > _Thresholds.shouldersHigh,
      'shoulders_high',
      52,
      pose.confidence,
      'Subject',
      'Relax shoulders',
      AdviceTone.waiting,
      shoulders != null ? {'shoulders_high_score': shoulders} : {},
    );
    return result;
  }

  List<PhotoIssue> _facePostureIssues(
    FaceAnalysis face,
    PosePackageId package,
  ) {
    final result = <PhotoIssue>[];
    void add(
      bool condition,
      String type,
      double severity,
      String instruction,
      AdviceTone tone,
      Map<String, double> reasonData,
    ) {
      if (condition) {
        result.add(
          _makePoseIssue(
            type,
            severity,
            face.confidence,
            'Subject',
            instruction,
            tone,
            package,
            reasonData: reasonData,
          ),
        );
      }
    }

    add(
      face.occlusionScore > _Thresholds.faceOcclusion,
      'face_occluded',
      78,
      'Clear the face',
      AdviceTone.warning,
      {'face_occlusion_score': face.occlusionScore},
    );
    add(
      face.eyeVisibilityScore < _Thresholds.eyeVisibility,
      'eyes_occluded',
      74,
      'Show your eyes',
      AdviceTone.warning,
      {'eye_visibility_score': face.eyeVisibilityScore},
    );
    final yaw = face.yawEstimate;
    if (yaw != null && yaw.abs() > _Thresholds.faceProfileYaw) {
      add(
        true,
        'face_too_profile',
        70,
        yaw > 0 ? 'Turn face slightly left' : 'Turn face slightly right',
        AdviceTone.warning,
        {'face_yaw_estimate': yaw},
      );
    } else if (yaw != null && yaw.abs() > _Thresholds.faceTurnedYaw) {
      add(
        true,
        'face_turned_away',
        58,
        yaw > 0 ? 'Turn face slightly left' : 'Turn face slightly right',
        AdviceTone.warning,
        {'face_yaw_estimate': yaw},
      );
    }
    final pitch = face.pitchEstimate;
    add(
      pitch != null && pitch < _Thresholds.chinHighPitch,
      'chin_too_high',
      42,
      'Lower chin slightly',
      AdviceTone.waiting,
      pitch != null ? {'face_pitch_estimate': pitch} : {},
    );
    add(
      pitch != null && pitch > _Thresholds.chinLowPitch,
      'chin_too_low',
      42,
      'Lift chin slightly',
      AdviceTone.waiting,
      pitch != null ? {'face_pitch_estimate': pitch} : {},
    );
    return result;
  }

  List<PhotoIssue> _groupPortraitIssues(
    GroupAnalysis group,
    PosePackageId package,
  ) {
    final result = <PhotoIssue>[];
    if (group.faceVisibilityRatio < 0.8) {
      result.add(
        _makePoseIssue(
          'group_faces_missing',
          86,
          0.74,
          'Photographer',
          'Make every face visible',
          AdviceTone.warning,
          package,
          reasonData: {
            'people_count': group.peopleCount.toDouble(),
            'face_count': group.faceCount.toDouble(),
            'face_visibility_ratio': group.faceVisibilityRatio,
          },
        ),
      );
    }
    if (group.edgeCrowdingScore > 0.45) {
      result.add(
        _makePoseIssue(
          'group_edge_crowded',
          72,
          0.68,
          'Photographer',
          'Leave space at the edges',
          AdviceTone.warning,
          package,
          reasonData: {'edge_crowding_score': group.edgeCrowdingScore},
        ),
      );
    }
    final spacing = group.spacingScore;
    if (spacing != null && spacing > 1.75) {
      result.add(
        _makePoseIssue(
          'group_spacing_wide',
          64,
          0.62,
          'Photographer',
          'Bring everyone closer together',
          AdviceTone.waiting,
          package,
          reasonData: {'spacing_score': spacing},
        ),
      );
    }
    return result;
  }

  PhotoIssue _makeIssue(
    String type,
    double severity,
    double confidence,
    String recipient,
    String instruction,
    AdviceTone tone, {
    Map<String, double> reasonData = const {},
  }) => PhotoIssue(
    type: type,
    severity: severity,
    confidence: confidence,
    priority: severity * confidence,
    recipient: recipient,
    instruction: instruction,
    successCondition: '$type clears for ${_Thresholds.issueStableSeconds}s',
    cooldownMilliseconds: 2800,
    reasonData: reasonData,
    tone: tone,
  );

  PhotoIssue _makePoseIssue(
    String type,
    double severity,
    double confidence,
    String recipient,
    String instruction,
    AdviceTone tone,
    PosePackageId package, {
    Map<String, double> reasonData = const {},
  }) {
    final tip = _poseTips[package]?[type];
    final adjustedSeverity = math.max(0.0, severity);
    return PhotoIssue(
      type: type,
      severity: adjustedSeverity,
      confidence: confidence,
      priority: adjustedSeverity * confidence,
      recipient: tip?.recipient ?? recipient,
      instruction: tip?.instruction ?? instruction,
      successCondition: tip == null
          ? '$type clears for ${_Thresholds.issueStableSeconds}s'
          : '$type clears for pose package',
      cooldownMilliseconds: 2800,
      reasonData: {
        ...reasonData,
        if (tip != null) 'pose_package': package.index.toDouble(),
      },
      tone: tone,
    );
  }
}

class _PoseTip {
  const _PoseTip(this.recipient, this.instruction);
  final String recipient;
  final String instruction;
}

Map<String, _PoseTip> _tips(List<(String, String, String)> values) => {
  for (final (type, recipient, instruction) in values)
    type: _PoseTip(recipient, instruction),
};

final _poseTips = <PosePackageId, Map<String, _PoseTip>>{
  PosePackageId.neutral: _tips(_commonTips),
  PosePackageId.feminine: _tips([
    ('hand_near_face', 'Subject', 'Move hand lightly away from face'),
    ('arm_hidden', 'Subject', 'Show both arms softly'),
    ('body_too_square', 'Subject', 'Angle one shoulder away'),
    ('body_too_profile', 'Subject', 'Turn torso slightly toward camera'),
    ('arms_flat_against_body', 'Subject', 'Create space at the waist'),
    ('hand_cut_off', 'Photographer', 'Keep hands in frame'),
    ('shoulders_high', 'Subject', 'Drop shoulders softly'),
    ('face_occluded', 'Subject', 'Clear the face'),
    ('eyes_occluded', 'Subject', 'Show your eyes'),
    ('face_too_profile', 'Subject', 'Turn face softly toward camera'),
    ('face_turned_away', 'Subject', 'Bring face back toward camera'),
    ('chin_too_high', 'Subject', 'Lower chin slightly'),
    ('chin_too_low', 'Subject', 'Lift chin slightly'),
  ]),
  PosePackageId.masculine: _tips([
    ('hand_near_face', 'Subject', 'Move hand away from face'),
    ('arm_hidden', 'Subject', 'Bring both arms into view'),
    ('body_too_square', 'Subject', 'Turn chin slightly, keep shoulders strong'),
    ('body_too_profile', 'Subject', 'Open shoulders toward camera'),
    ('arms_flat_against_body', 'Subject', 'Relax arms away from torso'),
    ('hand_cut_off', 'Photographer', 'Keep hands in frame'),
    ('shoulders_high', 'Subject', 'Set shoulders down'),
    ('face_occluded', 'Subject', 'Clear the face'),
    ('eyes_occluded', 'Subject', 'Show your eyes'),
    ('face_too_profile', 'Subject', 'Turn face toward camera'),
    ('face_turned_away', 'Subject', 'Look toward camera'),
    ('chin_too_high', 'Subject', 'Lower chin slightly'),
    ('chin_too_low', 'Subject', 'Lift chin slightly'),
  ]),
  PosePackageId.professional: _tips([
    ('hand_near_face', 'Subject', 'Move hand away from face'),
    ('arm_hidden', 'Subject', 'Keep both arms visible'),
    ('body_too_square', 'Subject', 'Angle shoulders slightly'),
    ('body_too_profile', 'Subject', 'Turn shoulders toward camera'),
    ('arms_flat_against_body', 'Subject', 'Leave space beside the torso'),
    ('hand_cut_off', 'Photographer', 'Keep hands in frame'),
    ('shoulders_high', 'Subject', 'Relax shoulders'),
    ('face_occluded', 'Subject', 'Clear the face'),
    ('eyes_occluded', 'Subject', 'Show your eyes'),
    ('face_too_profile', 'Subject', 'Turn face toward camera'),
    ('face_turned_away', 'Subject', 'Look toward camera'),
    ('chin_too_high', 'Subject', 'Lower chin slightly'),
    ('chin_too_low', 'Subject', 'Lift chin slightly'),
  ]),
  PosePackageId.groupPortrait: _tips([
    ('group_faces_missing', 'Photographer', 'Make every face visible'),
    ('group_edge_crowded', 'Photographer', 'Leave space at the edges'),
    ('group_spacing_wide', 'Photographer', 'Bring everyone closer together'),
    ('hand_near_face', 'Subject', 'Move hands away from faces'),
    ('arm_hidden', 'Photographer', 'Make sure everyone is visible'),
    ('body_too_square', 'Photographer', 'Angle the group slightly'),
    ('body_too_profile', 'Subject', 'Face the camera'),
    ('arms_flat_against_body', 'Subject', 'Relax arms naturally'),
    ('hand_cut_off', 'Photographer', 'Keep all hands in frame'),
    ('shoulders_high', 'Subject', 'Relax shoulders'),
    ('face_occluded', 'Photographer', 'Clear blocked faces'),
    ('eyes_occluded', 'Photographer', 'Make sure eyes are visible'),
    ('face_too_profile', 'Subject', 'Turn faces toward camera'),
    ('face_turned_away', 'Subject', 'Look toward camera'),
    ('chin_too_high', 'Subject', 'Lower chin slightly'),
    ('chin_too_low', 'Subject', 'Lift chin slightly'),
  ]),
};

const _commonTips = <(String, String, String)>[
  ('hand_near_face', 'Subject', 'Move hand from face'),
  ('arm_hidden', 'Subject', 'Show both arms'),
  ('body_too_square', 'Subject', 'Turn slightly'),
  ('body_too_profile', 'Subject', 'Angle body toward camera'),
  ('arms_flat_against_body', 'Subject', 'Separate arm from body'),
  ('hand_cut_off', 'Photographer', 'Keep hands in frame'),
  ('shoulders_high', 'Subject', 'Relax shoulders'),
  ('face_occluded', 'Subject', 'Clear the face'),
  ('eyes_occluded', 'Subject', 'Show your eyes'),
  ('chin_too_high', 'Subject', 'Lower chin slightly'),
  ('chin_too_low', 'Subject', 'Lift chin slightly'),
];

abstract final class _Thresholds {
  static const issueStableSeconds = 0.65;
  static const readyStableSeconds = 0.45;
  static const minimumAdviceSeconds = 1.5;
  static const repeatCooldownSeconds = 2.8;
  static const tooCloseArea = 0.48;
  static const tooFarArea = 0.055;
  static const tooMuchHeadroom = 0.16;
  static const tooLittleHeadroom = 0.025;
  static const edgePadding = 0.025;
  static const rollDegrees = 4.0;
  static const horizonDegrees = 3.0;
  static const darkFace = 70.0;
  static const backlitDelta = 55.0;
  static const poseMinimumConfidence = 0.24;
  static const faceMinimumConfidence = 0.45;
  static const handNearFaceDistance = 0.04;
  static const handCutOffEdgeDistance = 0.025;
  static const armVisibility = 0.55;
  static const bodySquareness = 0.82;
  static const bodyProfile = 0.58;
  static const armsFlatAgainstBody = 0.62;
  static const shouldersHigh = 0.62;
  static const faceTurnedYaw = 0.28;
  static const faceProfileYaw = 0.48;
  static const chinHighPitch = 0.16;
  static const chinLowPitch = 0.46;
  static const eyeVisibility = 0.75;
  static const faceOcclusion = 0.38;
}
