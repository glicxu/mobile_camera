import 'dart:convert';
import 'package:dali_camera_core/dali_camera_core.dart' show PhotoStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'watermark_identity.dart';

class PhotoMetadataSheet extends StatelessWidget {
  const PhotoMetadataSheet({
    super.key,
    required this.title,
    required this.metadata,
    this.basic,
    this.onEdit,
    this.localWatermarkOwnerId,
    this.watermarkCreationUnlocked = true,
  });
  final String title;
  final Future<Map<String, dynamic>> metadata;
  final Map<String, dynamic>? basic;
  final Future<bool> Function(Map<String, String> metadata)? onEdit;
  final String? localWatermarkOwnerId;
  final bool watermarkCreationUnlocked;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Column(
      children: [
        ListTile(
          title: const Text('Photo Info'),
          subtitle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: FutureBuilder<Map<String, dynamic>>(
              future: metadata,
              builder: (context, snapshot) {
                final info = snapshot.data ?? <String, dynamic>{};
                Map<String, dynamic>? debug;
                try {
                  final value = jsonDecode(info['debug'] as String? ?? 'null');
                  if (value is Map &&
                      value['schema'] == 'dali.capture-debug.v1') {
                    debug = Map<String, dynamic>.from(value);
                  }
                } catch (_) {}
                final rawRecipe = debug?['captureRecipe'];
                final recipe = rawRecipe is Map ? rawRecipe : null;
                final rawFilter = recipe?['filter'];
                final filter = rawFilter is List ? rawFilter : null;
                final width = info['width'] ?? basic?['width'];
                final height = info['height'] ?? basic?['height'];
                final exposure = num.tryParse('${info['exposureSeconds']}');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.hasData && onEdit != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          key: const Key('editPhotoMetadata'),
                          onPressed: () => _openEditor(context, info),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit metadata'),
                        ),
                      ),
                    if (width != null && height != null)
                      _item('Dimensions', '$width × $height pixels'),
                    if (basic?['bytes'] is num)
                      _item(
                        'File size',
                        '${((basic!['bytes'] as num) / 1048576).toStringAsFixed(1)} MB',
                      ),
                    if (snapshot.connectionState != ConnectionState.done) ...[
                      const LinearProgressIndicator(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Reading photo metadata… Cloud photos may need to download.',
                        ),
                      ),
                    ] else if (snapshot.hasError)
                      const Text(
                        'Could not read full metadata. Check access or connectivity, then reopen Info.',
                      ),
                    if (snapshot.hasData) ...[
                      _signedWatermarkItem(context, info),
                      _metadataWatermarkItem(
                        context,
                        info['hiddenWatermark'],
                        localWatermarkOwnerId,
                      ),
                      _pixelWatermarkItem(context, info),
                      if (info['description'] != null)
                        _item('Description', '${info['description']}'),
                      if (info['artist'] != null)
                        _item('Creator', '${info['artist']}'),
                      if (info['copyright'] != null)
                        _item('Copyright', '${info['copyright']}'),
                      _item(
                        'Capture time',
                        info['dateOriginal'] == null
                            ? 'Not recorded'
                            : '${info['dateOriginal']}${info['subsecond'] == null ? '' : '.${info['subsecond']}'} ${info['timeZone'] ?? '(time zone not recorded)'}',
                      ),
                      if (basic?['date'] is num && basic!['date'] > 0)
                        _item(
                          'Library date',
                          DateTime.fromMillisecondsSinceEpoch(
                            (basic!['date'] as num).toInt(),
                          ).toLocal().toString().split('.').first,
                        ),
                      for (final pair in [
                        ('make', 'Manufacturer'),
                        ('model', 'Camera'),
                        ('lensMake', 'Lens manufacturer'),
                        ('lensModel', 'Lens'),
                        ('iso', 'ISO'),
                      ])
                        if (info[pair.$1] != null)
                          _item(pair.$2, '${info[pair.$1]}'),
                      if (exposure != null && exposure > 0)
                        _item(
                          'Shutter speed',
                          exposure < 1
                              ? '1/${(1 / exposure).round()} s'
                              : '$exposure s',
                        ),
                      if (info['aperture'] != null)
                        _item('Aperture', 'f/${info['aperture']}'),
                      if (info['focalLength'] != null)
                        _item('Focal length', '${info['focalLength']} mm'),
                      if (info['focalLength35mm'] != null)
                        _item(
                          '35 mm equivalent',
                          '${info['focalLength35mm']} mm',
                        ),
                      if (info['digitalZoom'] != null)
                        _item('Digital zoom', '${info['digitalZoom']}×'),
                      if (info['exposureBias'] != null)
                        _item(
                          'Exposure compensation',
                          '${info['exposureBias']} EV',
                        ),
                      if (info['whiteBalance'] != null)
                        _item(
                          'White balance',
                          '${info['whiteBalance']}' == '0'
                              ? 'Auto'
                              : '${info['whiteBalance']}' == '1'
                              ? 'Manual'
                              : '${info['whiteBalance']}',
                        ),
                      if (info['flash'] != null)
                        _item(
                          'Flash',
                          ((num.tryParse('${info['flash']}')?.toInt() ?? 0) &
                                      1) ==
                                  1
                              ? 'Fired'
                              : 'Did not fire',
                        ),
                      if (info['meteringMode'] != null)
                        _item(
                          'Metering',
                          _enum(info['meteringMode'], {
                            0: 'Unknown',
                            1: 'Average',
                            2: 'Center weighted',
                            3: 'Spot',
                            4: 'Multi-spot',
                            5: 'Pattern',
                            6: 'Partial',
                            255: 'Other',
                          }),
                        ),
                      if (info['exposureMode'] != null)
                        _item(
                          'Exposure mode',
                          _enum(info['exposureMode'], {
                            0: 'Auto',
                            1: 'Manual',
                            2: 'Auto bracket',
                          }),
                        ),
                      if (info['exposureProgram'] != null)
                        _item(
                          'Exposure program',
                          _enum(info['exposureProgram'], {
                            0: 'Not defined',
                            1: 'Manual',
                            2: 'Normal program',
                            3: 'Aperture priority',
                            4: 'Shutter priority',
                            5: 'Creative program',
                            6: 'Action program',
                            7: 'Portrait mode',
                            8: 'Landscape mode',
                          }),
                        ),
                      if (info['colorSpace'] != null)
                        _item(
                          'Color space',
                          _enum(info['colorSpace'], {
                            1: 'sRGB',
                            65535: 'Uncalibrated',
                          }),
                        ),
                      if (info['orientation'] != null)
                        _item(
                          'Orientation',
                          '${info['orientation']}' == '1'
                              ? 'Upright pixels'
                              : 'EXIF ${info['orientation']}',
                        ),
                      _item(
                        'Location',
                        info['latitude'] is num && info['longitude'] is num
                            ? '${(info['latitude'] as num).toStringAsFixed(6)}, ${(info['longitude'] as num).toStringAsFixed(6)}'
                            : 'Not recorded or not accessible',
                      ),
                      if (info['altitude'] != null)
                        _item('Altitude', '${info['altitude']} m'),
                      if (info['software'] != null)
                        _item('Processing software', '${info['software']}'),
                      const Divider(),
                      Text(
                        'Capture debug',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (debug == null)
                        const Text('No capture debug information recorded.'),
                      if (debug != null) ...[
                        _item(
                          'Instruction shown',
                          debug['instructionShown']?.toString() ??
                              'Guidance was not displayed',
                        ),
                        if (debug['guidanceVisible'] != true &&
                            debug['computedInstruction'] != null)
                          _item(
                            'Computed guidance (not shown)',
                            '${debug['computedInstruction']}',
                          ),
                        _item(
                          'Situation',
                          '${debug['shootingMode']} → ${debug['resolvedSituation']}',
                        ),
                        if (debug['guide'] is Map)
                          _item(
                            'Guide',
                            '${debug['guide']['title']} · step ${debug['guide']['step']}${debug['guide']['complete'] == true ? ' · complete' : ''}',
                          ),
                        _item(
                          'Capture processing',
                          debug['captureEffectsApplied'] == true
                              ? 'Applied to saved capture'
                              : 'Capture processing not applied to this version',
                        ),
                        if (filter != null) ...[
                          _item(
                            'Capture filter',
                            '${debug['filterSelection']} (${debug['filterMode']})',
                          ),
                          _item(
                            'Filter adjustments',
                            [
                              for (
                                var i = 0;
                                i < filter.length &&
                                    i < PhotoStyle.fields.length;
                                i++
                              )
                                '${PhotoStyle.fields[i]}: ${filter[i]}',
                            ].join(', '),
                          ),
                        ],
                        if (recipe != null) ...[
                          _item(
                            'Capture Beautifier',
                            '${recipe['treatment']} · ${debug['beautifierPreset'] ?? 'no preset'} · strength ${recipe['strength'] ?? 0}/5',
                          ),
                          if (recipe['flags'] is Map &&
                              (recipe['flags'] as Map).isNotEmpty)
                            _item(
                              'Beautifier adjustments',
                              (recipe['flags'] as Map).entries
                                  .map(
                                    (e) =>
                                        '${e.key}: ${e.value == true ? 'on' : 'off'}',
                                  )
                                  .join(', '),
                            ),
                          _item(
                            'Depth / watermark',
                            '${recipe['depth'] ?? 0} / ${recipe['watermark'] == true ? 'on' : 'off'}',
                          ),
                        ],
                        const Text(
                          'These settings describe the original capture. Later edits may change its appearance.',
                        ),
                        ExpansionTile(
                          title: const Text('Full capture debug data'),
                          children: [
                            SelectableText(
                              const JsonEncoder.withIndent('  ').convert(debug),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(debug),
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Capture debug copied'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy capture debug'),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );

  static String _enum(dynamic value, Map<int, String> names) =>
      names[num.tryParse('$value')?.toInt()] ?? '$value';

  Future<void> _openEditor(
    BuildContext context,
    Map<String, dynamic> info,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PhotoMetadataEditorDialog(
        initial: info,
        onSave: onEdit!,
        watermarkCreationUnlocked: watermarkCreationUnlocked,
      ),
    );
    if (saved == true && context.mounted) Navigator.pop(context, true);
  }

  static Widget _item(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        SelectableText(value),
      ],
    ),
  );

  static Widget _pixelWatermarkItem(
    BuildContext context,
    Map<String, dynamic> info,
  ) {
    final detected = info['hiddenPixelWatermark'] == true;
    final rawVersion = info['hiddenPixelWatermarkVersion']?.toString();
    final version = switch (rawVersion) {
      'DALI_PIXEL_V1' => 'Dali Pixel v1',
      'DALI_PIXEL_V2' => 'Dali Pixel v2 identity payload',
      'DALI_PIXEL_V3' => 'Dali Pixel v3 robust signal',
      _ => rawVersion ?? 'Unknown format',
    };
    final score = info['hiddenPixelWatermarkScore'];
    final samples = info['hiddenPixelWatermarkSamples'];
    final minimumDimension = info['hiddenPixelWatermarkMinimumDimension'];
    final ownerReference = info['hiddenPixelWatermarkOwnerReference']
        ?.toString();
    final photoReference = info['hiddenPixelWatermarkPhotoReference']
        ?.toString();
    final payloadConfidence = info['hiddenPixelWatermarkPayloadConfidence'];
    final payloadRecovery = info['hiddenPixelWatermarkPayloadRecovery'];
    final robustScore = info['hiddenPixelWatermarkRobustScore'];
    final robustAxis = info['hiddenPixelWatermarkRobustAxis']?.toString();
    final robustQuarterTurns = info['hiddenPixelWatermarkRobustQuarterTurns'];
    final detectionMillis = info['hiddenPixelWatermarkDetectionMillis'];
    final metadataIdentity = parseDaliWatermarkIdentity(
      info['hiddenWatermark'],
    );
    final metadataOwnerReference = metadataIdentity?.ownerId == null
        ? null
        : daliPixelReference(metadataIdentity!.ownerId!);
    final metadataPhotoReference = metadataIdentity?.photoId == null
        ? null
        : daliPixelReference(metadataIdentity!.photoId!);
    final hasPayload = ownerReference != null && photoReference != null;
    final hasMetadataIdentity =
        metadataOwnerReference != null && metadataPhotoReference != null;
    final identitiesAgree =
        hasPayload &&
        hasMetadataIdentity &&
        ownerReference == metadataOwnerReference &&
        photoReference == metadataPhotoReference;
    final identitiesConflict =
        hasPayload && hasMetadataIdentity && !identitiesAgree;
    return Card(
      child: ListTile(
        leading: Icon(
          detected ? Icons.verified_outlined : Icons.search_off_outlined,
          color: detected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: const Text('Pixel watermark'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detected
                  ? hasPayload
                        ? 'Identity payload recovered from image pixels.'
                        : 'Signal detected · This is not identity verification.'
                  : 'Signal not detected. Editing or resizing may remove it.',
            ),
            Text(
              hasPayload
                  ? '$version · Compact references, not personal information.'
                  : '$version · Presence-only signal; no owner ID is encoded.',
            ),
            if (hasPayload) ...[
              _compactMetadataValue('Pixel owner reference', ownerReference),
              _compactMetadataValue('Pixel photo reference', photoReference),
              if (payloadConfidence is num)
                Text(
                  'Payload confidence ${(payloadConfidence * 100).toStringAsFixed(1)}%.',
                ),
              if (payloadRecovery == 'tiled')
                const Text(
                  'Identity recovered from the tiled crop/rotation-resilient channel.',
                ),
              if (identitiesAgree)
                const Text(
                  'Pixel and metadata identities agree. This is not cryptographic verification.',
                ),
              if (identitiesConflict)
                Text(
                  'Warning: Pixel and metadata identities conflict.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!hasMetadataIdentity)
                const Text(
                  'Identity recovered from pixels; matching metadata is unavailable.',
                ),
            ],
            if (score is num)
              Text(
                'Detection score ${score.toStringAsFixed(3)}${samples is num ? ' from ${samples.toInt()} samples' : ''}.',
              ),
            if (robustScore is num)
              Text(
                'Robust score ${robustScore.toStringAsFixed(2)}'
                '${robustAxis == null ? '' : ' | $robustAxis pairs'}'
                '${robustQuarterTurns is num && robustQuarterTurns != 0 ? ' | rotation normalized' : ''}.',
              ),
            if (detectionMillis is num)
              Text('Local detection took ${detectionMillis.toInt()} ms.'),
            if (minimumDimension is num)
              Text(
                'Requires at least ${minimumDimension.toInt()} × ${minimumDimension.toInt()} pixels.',
              ),
          ],
        ),
      ),
    );
  }

  static Widget _signedWatermarkItem(
    BuildContext context,
    Map<String, dynamic> info,
  ) {
    final status = info['signedWatermarkStatus']?.toString();
    if (status == null) return const SizedBox.shrink();
    final valid = status == 'verified';
    final warning = status != 'verified' && status != 'metadata_missing';
    final title = switch (status) {
      'verified' => 'Offline signature verified',
      'image_modified' => 'Signed image does not match',
      'metadata_conflict' => 'Signed identity conflict',
      'metadata_missing' => 'Signature valid; identity metadata missing',
      'invalid_signature' => 'Invalid watermark signature',
      _ => 'Signed watermark unavailable',
    };
    final detail = switch (status) {
      'verified' =>
        'The image pixels and DALI2 identity match the signed manifest.',
      'image_modified' =>
        'The image pixels changed after this manifest was signed.',
      'metadata_conflict' =>
        'The DALI2 metadata does not match the identity in the signed manifest.',
      'metadata_missing' =>
        'The signature matches the image, but the full DALI2 identity is unavailable.',
      'invalid_signature' =>
        'The manifest or signature was damaged, altered, or forged.',
      _ => 'The signed watermark could not be validated.',
    };
    final signedOwner = info['signedWatermarkOwnerReference']?.toString();
    final signedPhoto = info['signedWatermarkPhotoReference']?.toString();
    final pixelOwner = info['hiddenPixelWatermarkOwnerReference']?.toString();
    final pixelPhoto = info['hiddenPixelWatermarkPhotoReference']?.toString();
    final pixelsAgree =
        signedOwner != null &&
        signedPhoto != null &&
        pixelOwner != null &&
        pixelPhoto != null &&
        signedOwner == pixelOwner &&
        signedPhoto == pixelPhoto;
    final pixelsConflict =
        signedOwner != null &&
        signedPhoto != null &&
        pixelOwner != null &&
        pixelPhoto != null &&
        !pixelsAgree;
    return Card(
      child: ListTile(
        leading: Icon(
          valid ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
          color: valid
              ? Theme.of(context).colorScheme.primary
              : warning
              ? Theme.of(context).colorScheme.error
              : null,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail),
            const Text(
              'Verified locally without a server. This proves signature consistency, not a person’s legal identity or ownership.',
            ),
            if (signedOwner != null)
              _compactMetadataValue('Signed owner reference', signedOwner),
            if (signedPhoto != null)
              _compactMetadataValue('Signed photo reference', signedPhoto),
            if (info['signedWatermarkKeyFingerprint'] != null)
              _compactMetadataValue(
                'Signing key fingerprint',
                info['signedWatermarkKeyFingerprint'].toString(),
              ),
            if (pixelsAgree)
              const Text('Signed manifest and pixel identity agree.'),
            if (pixelsConflict)
              Text(
                'Warning: Signed manifest and pixel identity conflict.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _metadataWatermarkItem(
    BuildContext context,
    dynamic rawValue,
    String? localOwnerId,
  ) {
    final value = rawValue?.toString() ?? '';
    final identity = parseDaliWatermarkIdentity(value);
    final detected = identity != null;
    final isLocalProfile =
        identity?.ownerId != null && identity!.ownerId == localOwnerId;
    return Card(
      child: ListTile(
        leading: Icon(
          detected ? Icons.verified_outlined : Icons.search_off_outlined,
          color: detected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: const Text('Metadata watermark'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detected
                  ? 'Identifier present · This is not identity verification.'
                  : 'Identifier not detected.',
            ),
            const Text('Stored in EXIF; other apps may remove or copy it.'),
            if (identity != null) ...[
              const SizedBox(height: 8),
              Text(
                identity.legacy
                    ? 'Legacy Dali watermark'
                    : isLocalProfile
                    ? 'Your offline watermark'
                    : 'Watermark from another Dali profile',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (!identity.legacy)
                Text(
                  isLocalProfile
                      ? 'The owner ID matches this device profile.'
                      : 'The owner ID does not match this device profile.',
                ),
              Text(
                identity.legacy
                    ? 'Format: Dali metadata v1 (legacy)'
                    : 'Format: Dali metadata v2 (offline profile)',
              ),
              if (identity.publicId != null)
                _compactMetadataValue(
                  'Public watermark ID',
                  identity.publicId!,
                ),
              if (identity.ownerId != null)
                _compactMetadataValue('Canonical owner ID', identity.ownerId!),
              if (identity.photoId != null)
                _compactMetadataValue('Photo ID', identity.photoId!),
              if (!identity.legacy)
                const Text(
                  'This local profile is not cryptographically verified yet.',
                ),
              const SizedBox(height: 8),
              const Text('Full watermark ID'),
              SelectableText(value, key: const Key('fullMetadataWatermarkId')),
              TextButton.icon(
                key: const Key('copyMetadataWatermarkId'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Watermark ID copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy ID'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _compactMetadataValue(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label), SelectableText(value)],
    ),
  );
}

class _PhotoMetadataEditorDialog extends StatefulWidget {
  const _PhotoMetadataEditorDialog({
    required this.initial,
    required this.onSave,
    required this.watermarkCreationUnlocked,
  });

  final Map<String, dynamic> initial;
  final Future<bool> Function(Map<String, String> metadata) onSave;
  final bool watermarkCreationUnlocked;

  @override
  State<_PhotoMetadataEditorDialog> createState() =>
      _PhotoMetadataEditorDialogState();
}

class _MetadataEditField {
  const _MetadataEditField(
    this.name,
    this.label, {
    this.hint,
    this.integer = false,
    this.decimal = false,
    this.maxLength = 200,
    this.maxLines = 1,
    this.widgetKey,
  });

  final String name;
  final String label;
  final String? hint;
  final bool integer;
  final bool decimal;
  final int maxLength;
  final int maxLines;
  final String? widgetKey;
}

const _descriptiveMetadataFields = [
  _MetadataEditField(
    'description',
    'Description',
    hint: 'Add a caption or note',
    maxLength: 2000,
    maxLines: 4,
    widgetKey: 'photoMetadataDescription',
  ),
  _MetadataEditField('artist', 'Creator', widgetKey: 'photoMetadataCreator'),
  _MetadataEditField(
    'copyright',
    'Copyright',
    maxLength: 300,
    widgetKey: 'photoMetadataCopyright',
  ),
  _MetadataEditField('software', 'Processing software'),
];

const _captureMetadataFields = [
  _MetadataEditField(
    'dateOriginal',
    'Capture date and time',
    hint: 'YYYY:MM:DD HH:MM:SS',
  ),
  _MetadataEditField('timeZone', 'UTC offset', hint: '+HH:MM or -HH:MM'),
  _MetadataEditField('subsecond', 'Subsecond', integer: true),
  _MetadataEditField('make', 'Manufacturer'),
  _MetadataEditField('model', 'Camera model'),
  _MetadataEditField('lensMake', 'Lens manufacturer'),
  _MetadataEditField('lensModel', 'Lens model'),
];

const _exposureMetadataFields = [
  _MetadataEditField(
    'exposureSeconds',
    'Exposure time (seconds)',
    decimal: true,
  ),
  _MetadataEditField('aperture', 'Aperture (f-number)', decimal: true),
  _MetadataEditField('iso', 'ISO', integer: true),
  _MetadataEditField(
    'exposureBias',
    'Exposure compensation (EV)',
    decimal: true,
  ),
  _MetadataEditField('exposureProgram', 'Exposure program code', integer: true),
  _MetadataEditField('exposureMode', 'Exposure mode code', integer: true),
  _MetadataEditField('meteringMode', 'Metering mode code', integer: true),
  _MetadataEditField('flash', 'Flash code', integer: true),
  _MetadataEditField('focalLength', 'Focal length (mm)', decimal: true),
  _MetadataEditField('focalLength35mm', '35 mm equivalent (mm)', integer: true),
  _MetadataEditField('digitalZoom', 'Digital zoom ratio', decimal: true),
  _MetadataEditField('whiteBalance', 'White balance code', integer: true),
  _MetadataEditField('colorSpace', 'Color space code', integer: true),
];

const _locationMetadataFields = [
  _MetadataEditField('latitude', 'Latitude', decimal: true),
  _MetadataEditField('longitude', 'Longitude', decimal: true),
  _MetadataEditField('altitude', 'Altitude (meters)', decimal: true),
];

const _allEditableMetadataFields = [
  ..._descriptiveMetadataFields,
  ..._captureMetadataFields,
  ..._exposureMetadataFields,
  ..._locationMetadataFields,
];

class _PhotoMetadataEditorDialogState
    extends State<_PhotoMetadataEditorDialog> {
  late final Map<String, TextEditingController> controllers;
  bool saving = false;
  late bool metadataWatermarkEnabled;
  String? error;

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in _allEditableMetadataFields)
        field.name: TextEditingController(
          text: widget.initial[field.name]?.toString() ?? '',
        ),
    };
    metadataWatermarkEnabled = isDaliMetadataWatermark(
      widget.initial['hiddenWatermark'],
    );
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validate() {
    for (final field in _allEditableMetadataFields) {
      final value = controllers[field.name]!.text.trim();
      if (value.isEmpty) continue;
      if (field.integer && int.tryParse(value) == null) {
        return '${field.label} must be a whole number.';
      }
      if (field.decimal && double.tryParse(value) == null) {
        return '${field.label} must be a number.';
      }
    }
    final date = controllers['dateOriginal']!.text.trim();
    if (date.isNotEmpty &&
        !RegExp(r'^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(date)) {
      return 'Capture date must use YYYY:MM:DD HH:MM:SS.';
    }
    final timeZone = controllers['timeZone']!.text.trim();
    if (timeZone.isNotEmpty &&
        !RegExp(r'^[+-](?:0\d|1[0-4]):[0-5]\d$').hasMatch(timeZone)) {
      return 'UTC offset must use +HH:MM or -HH:MM.';
    }
    final latitudeText = controllers['latitude']!.text.trim();
    final longitudeText = controllers['longitude']!.text.trim();
    if (latitudeText.isEmpty != longitudeText.isEmpty) {
      return 'Latitude and longitude must be entered together.';
    }
    final latitude = double.tryParse(latitudeText);
    final longitude = double.tryParse(longitudeText);
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      return 'Latitude must be between -90 and 90.';
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      return 'Longitude must be between -180 and 180.';
    }
    return null;
  }

  Future<void> save() async {
    final validationError = validate();
    if (validationError != null) {
      setState(() => error = validationError);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final saved = await widget.onSave({
      for (final field in _allEditableMetadataFields)
        field.name: controllers[field.name]!.text.trim(),
      'hiddenWatermark': metadataWatermarkEnabled
          ? (isDaliMetadataWatermark(widget.initial['hiddenWatermark'])
                ? widget.initial['hiddenWatermark'].toString()
                : 'add')
          : '',
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        saving = false;
        error = 'Could not update metadata. The original photo is unchanged.';
      });
    }
  }

  Widget metadataField(_MetadataEditField field) => TextField(
    key: Key(field.widgetKey ?? 'photoMetadata_${field.name}'),
    controller: controllers[field.name],
    enabled: !saving,
    maxLength: field.maxLength,
    maxLines: field.maxLines,
    keyboardType: field.integer
        ? TextInputType.number
        : field.decimal
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: field.label, hintText: field.hint),
  );

  Widget metadataSection(
    String title,
    String subtitle,
    List<_MetadataEditField> fields, {
    bool initiallyExpanded = false,
  }) => ExpansionTile(
    key: Key('photoMetadataSection_${fields.first.name}'),
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    initiallyExpanded: initiallyExpanded,
    title: Text(title),
    subtitle: Text(subtitle),
    children: fields.map(metadataField).toList(),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit photo metadata'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        metadataSection(
          'Description and rights',
          'Caption, creator, copyright, and software',
          _descriptiveMetadataFields,
          initiallyExpanded: true,
        ),
        metadataSection(
          'Capture and equipment',
          'Date, time zone, camera, and lens',
          _captureMetadataFields,
        ),
        metadataSection(
          'Exposure details',
          'Shutter, aperture, ISO, flash, and related EXIF codes',
          _exposureMetadataFields,
        ),
        metadataSection(
          'Location',
          'Latitude, longitude, and altitude',
          _locationMetadataFields,
        ),
        SwitchListTile(
          key: const Key('photoMetadataHiddenWatermark'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Metadata watermark'),
          subtitle: Text(
            widget.watermarkCreationUnlocked || metadataWatermarkEnabled
                ? 'Add or remove the invisible EXIF identifier. The pixel watermark is controlled when taking a photo.'
                : 'Lifetime unlock required to add a watermark. Existing watermarks can still be viewed.',
          ),
          value: metadataWatermarkEnabled,
          onChanged:
              saving ||
                  (!widget.watermarkCreationUnlocked &&
                      !metadataWatermarkEnabled)
              ? null
              : (value) => setState(() => metadataWatermarkEnabled = value),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        const Text(
          'Changing metadata does not change the photo pixels. Dimensions, orientation, pixel watermark, and Dali capture diagnostics stay read-only.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('savePhotoMetadata'),
        onPressed: saving ? null : save,
        child: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Apply'),
      ),
    ],
  );
}
