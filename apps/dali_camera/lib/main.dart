import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_controller.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const DaliApp()); }

class DaliApp extends StatelessWidget {
  const DaliApp({super.key, this.controller});
  final CameraController? controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dali Camera', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2aafbc), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xff080b0f), useMaterial3: true),
    home: CameraScreen(controller: controller),
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.controller});
  final CameraController? controller;
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}
class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late final CameraController camera;
  String? variant;
  bool compare = false;
  Orientation? orientation;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    camera = widget.controller ?? CameraController(); camera.addListener(refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => camera.initialize());
  }
  void refresh() { if (mounted) setState(() {}); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { camera.foreground = true; camera.start(); }
    else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) { camera.foreground = false; camera.pause(); }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); camera.removeListener(refresh);
    if (widget.controller == null) { camera.pause(); camera.dispose(); }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final current = MediaQuery.orientationOf(context);
    if (orientation != null && current != orientation && !camera.reviewing) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) camera.start(); });
    }
    orientation = current;
    return Scaffold(body: SafeArea(child: camera.reviewing ? review() : live(current)));
  }
  Widget live(Orientation orientation) {
    final controls = Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (camera.cameraError != null) ...[
          Text(camera.cameraError!), Wrap(spacing: 8, children: [FilledButton(onPressed: camera.start, child: const Text('Retry camera')),
            TextButton(onPressed: camera.host.openSettings, child: const Text('Open Settings'))]),
        ],
        Semantics(liveRegion: true, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(camera.advice.recipient.toUpperCase(), style: Theme.of(context).textTheme.labelLarge), const SizedBox(height: 8),
          Text(camera.advice.instruction, style: Theme.of(context).textTheme.titleLarge),
        ])))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('People'), selected: !camera.landscape, onSelected: (_) { camera.landscape = false; camera.choose(null); }),
          ChoiceChip(label: const Text('Landscape'), selected: camera.landscape, onSelected: (_) { camera.landscape = true; camera.choose(null); }),
          FilledButton.tonal(onPressed: () => chooser(), child: Text(camera.landscape ? 'Landscape packages' : 'Posture packages')),
        ]),
        if (camera.guidance.isActive) ...[
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, leading: Image.asset(camera.guidance.entry!.asset, width: 52, height: 68, fit: BoxFit.cover),
            title: Text(camera.guidance.entry!.title), subtitle: Text(camera.catalog.angleTitle(camera.guidance.entry!)), onTap: () => details(camera.guidance.entry!)),
          Wrap(spacing: 8, children: [FilledButton.tonal(onPressed: camera.guidance.complete ? null : camera.next, child: const Text('Done / Next')),
            TextButton(onPressed: camera.guidance.complete ? null : camera.next, child: const Text('Skip')),
            TextButton(onPressed: () => camera.choose(null), child: const Text('Natural'))]),
        ],
        if (camera.message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Semantics(liveRegion: true, child: Text(camera.message!))),
      ]))),
      Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton.filledTonal(tooltip: camera.original == null ? 'Choose photo' : 'Review latest photo', icon: const Icon(Icons.photo_library_outlined),
          onPressed: camera.busy ? null : camera.original == null ? camera.pick : camera.openLatest),
        Semantics(label: 'Take photo', button: true, child: SizedBox(width: 76, height: 76, child: FilledButton(
          key: const Key('shutter'), onPressed: camera.canCapture ? camera.capturePhoto : null,
          style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
          child: camera.busy ? const CircularProgressIndicator() : const Icon(Icons.camera, size: 36)))),
        IconButton(tooltip: 'Choose photo', icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: camera.busy ? null : camera.pick),
      ])),
    ]);
    final preview = LayoutBuilder(builder: (context, bounds) => Center(child: AspectRatio(aspectRatio: camera.aspectRatio, child: Stack(fit: StackFit.expand, children: [
      if (widget.controller != null) const ColoredBox(color: Colors.black)
      else if (Platform.isAndroid) const AndroidView(viewType: 'dali/camera')
      else if (Platform.isIOS) const UiKitView(viewType: 'dali/camera')
      else const Center(child: Text('Use an Android or iOS phone.')),
      IgnorePointer(child: CustomPaint(painter: FramePainter(camera.debug ? camera.lastFrame : null))),
    ]))));
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: [
        Expanded(child: Text('Dali Camera', style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(tooltip: 'Camera settings', onPressed: settings, icon: const Icon(Icons.tune)),
        IconButton(tooltip: 'Help', onPressed: help, icon: const Icon(Icons.help_outline)),
        IconButton(tooltip: 'Switch camera', onPressed: camera.starting || camera.busy ? null : camera.switchLens, icon: const Icon(Icons.cameraswitch)),
      ])),
      Expanded(child: orientation == Orientation.landscape
        ? Row(children: [Expanded(flex: 3, child: preview), SizedBox(width: MediaQuery.sizeOf(context).width * .38, child: controls)])
        : Column(children: [Expanded(flex: 5, child: preview), Expanded(flex: 4, child: controls)])),
    ]);
  }
  Widget review() {
    final photo = compare ? camera.original : camera.selected;
    return Column(children: [
      Row(children: [IconButton(tooltip: 'Back to camera', onPressed: camera.busy ? null : camera.returnToCamera, icon: const Icon(Icons.arrow_back)),
        const Expanded(child: Text('Photo review')), TextButton(onPressed: camera.busy ? null : camera.pick, child: const Text('Photos'))]),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (photo != null) GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Photo')),
          body: Center(child: InteractiveViewer(maxScale: 5, child: Image.file(File(photo.path))))))),
          child: SizedBox(height: MediaQuery.sizeOf(context).height * .42, child: Image.file(File(photo.path), fit: BoxFit.contain, semanticLabel: compare ? 'Original photo' : 'Selected photo'))),
        const SizedBox(height: 16),
        Text('Choose a version', style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Original'), selected: variant == null, onSelected: camera.busy ? null : (_) { variant = null; camera.variant(); }),
          ChoiceChip(label: const Text('Tighter crop'), selected: variant == 'crop', onSelected: camera.busy ? null : (_) { variant = 'crop'; camera.variant(crop: true); }),
        ]),
        SwitchListTile(title: const Text('Compare with original'), value: compare, onChanged: (v) => setState(() => compare = v)),
        if (camera.message != null) Semantics(liveRegion: true, child: Text(camera.message!)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: camera.busy ? null : camera.saveSelected, child: Text(camera.selected?.id == camera.original?.id && camera.original?.unsaved == true ? 'Retry save original' : 'Save selected')),
          FilledButton.tonal(onPressed: camera.busy ? null : camera.shareSelected, child: const Text('Share selected')),
          if (camera.original?.unsaved == true) ...[
            TextButton(onPressed: camera.host.openSettings, child: const Text('Open Settings')),
            TextButton(onPressed: camera.busy ? null : () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Discard unsaved original?'),
                content: const Text('This removes the recovery copy. Share or save it first if you want to keep it.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep photo')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard'))]));
              if (confirm == true) camera.discard();
            }, child: const Text('Discard original')),
          ],
        ]),
        if (camera.busy) const LinearProgressIndicator(),
      ]))),
    ]);
  }
  Future<void> chooser() async {
    final kind = camera.landscape ? 'landscape' : 'pose';
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .85, child: Column(children: [
        ListTile(title: Text(kind == 'pose' ? 'Posture packages' : 'Landscape packages'), trailing: IconButton(tooltip: 'Close packages', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))),
        TextButton(onPressed: () { camera.choose(null); Navigator.pop(ctx); }, child: const Text('Natural')),
        Expanded(child: ListView(children: camera.catalog.packages(kind).entries.map((package) => ExpansionTile(title: Text(package.value), children: [
          ...camera.catalog.entries.where((item) => item.kind == kind && item.package == package.key).map((item) => ListTile(
            leading: Image.asset(item.asset, width: 64, height: 84, fit: BoxFit.cover), title: Text(item.title), subtitle: Text(camera.catalog.angleTitle(item)),
            onTap: () { Navigator.pop(ctx); details(item, select: true); })),
        ])).toList())),
      ])));
  }
  Future<void> details(CatalogEntry item, {bool select = false}) => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
    builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * .85, child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text(item.title, style: Theme.of(ctx).textTheme.titleLarge)), IconButton(tooltip: 'Close reference', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
      SizedBox(height: 260, child: Image.asset(item.asset, fit: BoxFit.contain)), const SizedBox(height: 16),
      Text('${item.recipient}: ${item.cues.join(' ')}'), const SizedBox(height: 12),
      Text('Camera: ${camera.catalog.angleInstruction(item)}'), const SizedBox(height: 12), Text(camera.catalog.lightDescription(item)),
      if (item.data['safetyNote'] != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(item.data['safetyNote'] as String)),
      if (select) FilledButton(onPressed: () { camera.choose(item); Navigator.pop(ctx); }, child: const Text('Use this reference')),
    ]))));
  Future<void> settings() => showModalBottomSheet<void>(context: context, useSafeArea: true, isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
      final snapshot = camera.snapshot;
      return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Camera settings', style: Theme.of(ctx).textTheme.titleLarge),
        if (snapshot != null && snapshot.minimumEV < snapshot.maximumEV) ...[
          Text('Exposure ${(snapshot.currentEV).toStringAsFixed(1)} EV'),
          Slider(value: snapshot.currentEV.clamp(snapshot.minimumEV, snapshot.maximumEV), min: snapshot.minimumEV, max: snapshot.maximumEV,
            onChanged: (v) async { await camera.controls(v, snapshot.locked); update(() {}); }),
          TextButton(onPressed: () async { await camera.controls(0, false); update(() {}); }, child: const Text('Return to Auto')),
        ],
        if (snapshot?.supportsLock == true) SwitchListTile(title: const Text('Focus / exposure lock'), value: snapshot!.locked,
          onChanged: (v) async { await camera.controls(snapshot.currentEV, v); update(() {}); }),
        SwitchListTile(title: const Text('Debug overlay'), value: camera.debug, onChanged: (v) { camera.debug = v; refresh(); update(() {}); }),
        SwitchListTile(title: const Text('Voice shutter'), subtitle: const Text('On-device speech availability depends on your phone.'), value: camera.voice,
          onChanged: (v) async { await camera.setVoice(v); update(() {}); }),
        TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: jsonEncode(camera.log))); Navigator.pop(ctx); }, child: const Text('Copy diagnostic log')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ]));
    }));
  Future<void> help() => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Take a photo with Dali'),
    content: const SingleChildScrollView(child: Text('Frame your subject and follow one short cue at a time. The shutter stays available while you try optional poses.\n\nChoose a posture or landscape reference for ideas about framing and light. Done / Next confirms a creative step; Dali does not verify the pose.\n\nTap your latest photo to review, save, or share it. Failed saves keep the original for retry.')),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))]));
}

class FramePainter extends CustomPainter {
  FramePainter(this.frame);
  final Map<String, dynamic>? frame;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: .15)..strokeWidth = 1;
    for (var i = 1; i < 3; i++) { canvas.drawLine(Offset(size.width*i/3, 0), Offset(size.width*i/3, size.height), grid); canvas.drawLine(Offset(0, size.height*i/3), Offset(size.width, size.height*i/3), grid); }
    if (frame == null) return;
    for (final key in ['people', 'faces']) {
      final paint = Paint()..color = key == 'faces' ? Colors.amber : Colors.tealAccent..style = PaintingStyle.stroke..strokeWidth = 2;
      for (final box in frame![key] as List? ?? []) { canvas.drawRect(Rect.fromLTWH((box['x'] as num)*size.width, (box['y'] as num)*size.height, (box['width'] as num)*size.width, (box['height'] as num)*size.height), paint); }
    }
  }
  @override
  bool shouldRepaint(FramePainter oldDelegate) => oldDelegate.frame != frame;
}
