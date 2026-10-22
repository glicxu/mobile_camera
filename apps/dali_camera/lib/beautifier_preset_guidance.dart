const beautifierPresetGuidance = <String, Map<String, String>>{
  'landscape': {
    'Natural': 'Gentle color polish for a realistic landscape.',
    'Vivid': 'Natural color boost for most landscapes.',
    'Dramatic':
        'Best for flat, hazy, or overcast scenes. Adds strong color, sky depth, and contrast.',
  },
};

String? guidanceForBeautifierPreset(String treatment, String? preset) =>
    preset == null ? null : beautifierPresetGuidance[treatment]?[preset];
