import 'catalog.dart';

/// Shared color transform used for preview swatches and native review exports.
/// Spatial softness/detail are applied by each native renderer separately.
class PhotoStyle {
  const PhotoStyle(this.values);
  final Map<String, int> values;
  static const fields = [
    'exposure',
    'warmth',
    'color',
    'contrast',
    'softness',
    'detail',
    'blueSky',
  ];
  static const identity = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  factory PhotoStyle.preset(SharedCatalog catalog, String name, String kind) {
    if (name == 'off') return const PhotoStyle({});
    final resolved = name == 'auto'
        ? kind == 'food'
              ? 'fresh'
              : kind == 'landscape'
              ? 'blueSky'
              : kind == 'action'
              ? 'vivid'
              : kind == 'closeUp'
              ? 'bright'
              : 'natural'
        : name;
    final data = catalog.data['filters'][resolved]['settings'] as Map;
    return PhotoStyle(data.cast<String, int>());
  }
  int value(String key) => (values[key] ?? 0).clamp(
    ['exposure', 'warmth', 'contrast'].contains(key) ? -5 : 0,
    5,
  );
  bool get active => fields.any((key) => value(key) != 0);
  List<double> get matrix {
    final exposure = value('exposure') / 5;
    final warmth = value('warmth') / 5;
    final color = value('color') / 5;
    final softness = value('softness') / 5;
    final sky = value('blueSky') / 5;
    final contrast = 1 + .13 * value('contrast') / 5 - .04 * softness;
    final saturation = 1 + .30 * color;
    final bias = 255 * (.055 * exposure + .5 * (1 - contrast));
    const luminance = [.2126, .7152, .0722];
    final result = List<double>.from(identity);
    final gains = [
      1 + .06 * warmth - .05 * sky,
      1 + .02 * sky,
      1 - .06 * warmth + .18 * sky,
    ];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        result[row * 5 + col] =
            contrast *
            gains[row] *
            ((1 - saturation) * luminance[col] + (row == col ? saturation : 0));
      }
      result[row * 5 + 4] = bias + (row == 2 ? .018 * sky * 255 : 0);
    }
    return result;
  }
}
