import 'dart:convert';
import 'package:dali_camera_core/dali_camera_core.dart' show PhotoStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhotoMetadataSheet extends StatelessWidget {
  const PhotoMetadataSheet({
    super.key,
    required this.title,
    required this.metadata,
    this.basic,
  });
  final String title;
  final Future<Map<String, dynamic>> metadata;
  final Map<String, dynamic>? basic;

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
}
