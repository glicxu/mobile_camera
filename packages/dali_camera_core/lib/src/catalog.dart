import 'dart:convert';
import 'catalog_data.dart';
import 'models.dart';
import 'guidance.dart';

class CatalogEntry {
  CatalogEntry(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get kind => data['kind'] as String;
  String get key => '$kind:$id';
  String get title => data['title'] as String;
  String get package => data['package'] as String;
  String get asset => data['asset'] as String;
  String get angle => data['recommendedCameraAngle'] as String;
  String get light =>
      (data['recommendedLighting'] ?? data['recommendedLight']) as String;
  String get recipient => data['recipient'] as String;
  List<String> get cues => (data['cues'] as List).cast<String>();
  Set<String> get conflicts =>
      (data['conflicts'] as List).cast<String>().toSet();
}

class SharedCatalog {
  SharedCatalog()
    : data = jsonDecode(sharedCatalogJson) as Map<String, dynamic>;
  final Map<String, dynamic> data;
  late final List<CatalogEntry> entries = (data['items'] as List)
      .map((value) => CatalogEntry(value as Map<String, dynamic>))
      .toList();
  Map<String, String> packages(String kind) =>
      (data['${kind == 'pose' ? 'pose' : kind}Packages'] as Map)
          .cast<String, String>();
  String angleTitle(CatalogEntry entry) =>
      data['angles'][entry.angle]['title'] as String;
  String packageDescription(String kind, String package) =>
      (data['${kind}PackageDescriptions'] as Map?)?[package] as String? ?? '';
  String lightTitle(CatalogEntry entry) =>
      data['${entry.kind == 'pose' ? 'pose' : entry.kind}Lighting'][entry
              .light]['title']
          as String;
  String angleInstruction(CatalogEntry entry) =>
      data['angles'][entry.angle]['instruction'] as String;
  String lightDescription(CatalogEntry entry) {
    final value =
        data['${entry.kind == 'pose' ? 'pose' : entry.kind}Lighting'][entry
            .light];
    return '${value['title']}. ${value['instruction']}';
  }
}

/// Optional creative guidance. Progress is user-confirmed, never inferred.
class CatalogSession {
  CatalogSession(this.entry, this.catalog);
  final CatalogEntry? entry;
  final SharedCatalog catalog;
  int index = 0;
  bool get isActive => entry != null;
  GuidedCameraPosition? get position => entry?.kind != 'pose'
      ? null
      : switch (entry!.angle) {
          'eyeLevel' => GuidedCameraPosition.eyeLevel,
          'slightlyHigh' => GuidedCameraPosition.elevated,
          'low' => GuidedCameraPosition.waistLevel,
          'side' || 'fortyFive' => GuidedCameraPosition.side,
          _ => null,
        };
  List<GuidedStep> get cameraSteps => position?.steps() ?? [];
  List<String> get cues => entry == null
      ? []
      : [
          if (entry!.kind == 'pose')
            ...cameraSteps.map((step) => step.instruction)
          else
            catalog.angleInstruction(entry!),
          ...entry!.cues,
        ];
  GuidedAction? get currentAction =>
      !isActive || complete || entry!.kind != 'pose'
      ? null
      : index < cameraSteps.length
      ? cameraSteps[index].action
      : GuidedAction.subjectPose;
  bool get complete => isActive && index >= cues.length;
  void advance() {
    if (index < cues.length) index++;
  }

  Advice? get advice => entry == null
      ? null
      : Advice(
          type: 'catalog_${entry!.key}_$index',
          recipient: complete
              ? 'Camera'
              : (entry!.kind == 'pose' ? index < cameraSteps.length : true)
              ? 'Photographer'
              : entry!.recipient,
          instruction: complete
              ? "Sequence finished. Take a photo when you're ready."
              : cues[index],
          tone: AdviceTone.waiting,
        );
  List<PhotoIssue> prioritize(List<PhotoIssue> issues) {
    if (entry == null) return issues;
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
              !entry!.conflicts.contains(issue.type),
        )
        .toList();
  }
}
