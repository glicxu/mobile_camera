import 'package:flutter/material.dart';

const tutorialSteps = [
  (
    'Choose your shot',
    'Leave Situation on Auto for everyday photos, or choose Portrait, Landscape, Food, Group, Action, or Close-up when you want specific guidance.',
    Icons.crop_free,
    [
      'Auto recognizes the scene',
      'Choose a situation for specialized guidance',
    ],
  ),
  (
    'Choose a posture package',
    'For Portrait, People, or Group photos, tap Posture. Choose a package, then select a reference pose. Dali shows its recommended camera angle, lighting, and live coaching cues.',
    Icons.accessibility_new,
    ['11 posture packages', 'Tap a photo to select the pose'],
  ),
  (
    'Choose a landscape package',
    'Choose the Landscape situation, then tap Landscape. Pick a scene package and a composition. Dali guides the angle, light, horizon, and placement while you frame the photo.',
    Icons.landscape,
    ['4 landscape packages', 'Choose among 24 compositions'],
  ),
  (
    'Follow the coaching light',
    'Dali gives one visual instruction at a time. Green means the framing looks good; amber means a small adjustment needs your attention.',
    Icons.open_with,
    ['Green: ready', 'Amber: adjust framing'],
  ),
  (
    'Style before capture',
    'Open Controls to choose a named Filter or Beautifier. Auto chooses for the scene, Custom exposes fine-tuning, and Off keeps the natural camera image.',
    Icons.auto_awesome,
    ['Filters control color', 'Beautifier controls people or scenery'],
  ),
  (
    'Take the photo',
    'Tap the shutter for one photo. Shutter Controls also provides a timer and your voice phrase. Hold the shutter for a burst by default.',
    Icons.camera_alt,
    ['Tap: one photo', 'Hold: burst'],
  ),
  (
    'Review and return',
    'Tap the lower-left thumbnail to review. Swipe through photos, compare Before and After, then tap Back to Camera when you are ready to shoot again.',
    Icons.photo_library,
    ['Swipe for previous photos', 'Back to Camera resumes shooting'],
  ),
];

class CameraTutorial extends StatefulWidget {
  const CameraTutorial({super.key});
  @override
  State<CameraTutorial> createState() => _CameraTutorialState();
}

class _CameraTutorialState extends State<CameraTutorial> {
  final pages = PageController();
  int index = 0;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void move(int next) => pages.animateToPage(
    next,
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeInOut,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quick Camera Tutorial'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pages,
              itemCount: tutorialSteps.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (ctx, stepIndex) {
                final step = tutorialSteps[stepIndex];
                final accent = stepIndex == 2
                    ? Colors.blue
                    : stepIndex == 3
                    ? Colors.orange
                    : stepIndex == 5
                    ? Colors.yellow
                    : Colors.teal;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: .32),
                                Colors.black,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: accent.withValues(alpha: .7),
                            ),
                          ),
                          child: TutorialIllustration(step: stepIndex),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        step.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(step.$2, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      for (final tip in step.$4)
                        Card(
                          color: accent.withValues(alpha: .12),
                          child: ListTile(
                            leading: const Icon(Icons.check_circle),
                            title: Text(tip),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Semantics(
            label: 'Tutorial step ${index + 1} of ${tutorialSteps.length}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < tutorialSteps.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == index ? Colors.teal : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(
              children: [
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () => move(index - 1),
                      child: const Text('Back'),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => index == tutorialSteps.length - 1
                        ? Navigator.pop(context)
                        : move(index + 1),
                    child: Text(
                      index == tutorialSteps.length - 1
                          ? 'Start taking photos'
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TutorialIllustration extends StatelessWidget {
  const TutorialIllustration({super.key, required this.step});
  final int step;
  Widget feature(IconData icon, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 58, color: color),
      Text(
        label,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Center(
    child: switch (step) {
      0 => const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.crop_free, size: 122),
          Icon(Icons.person, size: 44, color: Colors.yellow),
        ],
      ),
      1 || 2 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              feature(
                step == 1 ? Icons.portrait : Icons.landscape,
                step == 1 ? 'Portrait' : 'Landscape',
                step == 1 ? Colors.teal : Colors.blue,
              ),
              const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.chevron_right),
              ),
              feature(
                step == 1 ? Icons.accessibility_new : Icons.view_agenda,
                step == 1 ? 'Posture' : 'Composition',
                step == 1 ? Colors.yellow : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            step == 1
                ? 'Choose package  ?  Choose pose'
                : 'Choose scene  ?  Frame photo',
            textScaler: TextScaler.noScaling,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              feature(Icons.circle, 'Ready', Colors.green),
              const SizedBox(width: 24),
              feature(Icons.circle, 'Adjust', Colors.orange),
            ],
          ),
          const SizedBox(height: 18),
          const Icon(Icons.open_with, size: 56),
        ],
      ),
      4 => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          feature(Icons.filter, 'Filters', Colors.teal),
          feature(Icons.auto_awesome, 'Beautifier', Colors.yellow),
        ],
      ),
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '? Timer     Voice     Burst',
            textScaler: TextScaler.noScaling,
          ),
        ],
      ),
      _ => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_left),
          Icon(Icons.photo_library_outlined, size: 72),
          Icon(Icons.chevron_right),
        ],
      ),
    },
  );
}
