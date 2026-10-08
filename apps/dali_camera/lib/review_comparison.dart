import 'dart:io';
import 'package:flutter/material.dart';

class ReviewComparison extends StatelessWidget {
  const ReviewComparison({
    super.key,
    required this.before,
    required this.after,
    required this.mode,
    this.split = .5,
  });
  final String before;
  final String after;
  final String mode;
  final double split;
  Widget image(String path, String label) => SizedBox.expand(
    child: Image.file(
      File(path),
      cacheWidth: 2400,
      fit: BoxFit.contain,
      semanticLabel: label,
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Stack(
      fit: StackFit.expand,
      children: [
        image(
          mode == 'before' || mode == 'split' ? before : after,
          mode == 'after' ? 'Selected photo' : 'Original photo',
        ),
        if (mode == 'split') ...[
          ClipRect(
            clipper: _SplitClip(split),
            child: image(after, 'Selected photo on the right'),
          ),
          Positioned(
            left: bounds.maxWidth * split,
            top: 0,
            bottom: 0,
            child: const SizedBox(
              width: 2,
              child: ColoredBox(color: Colors.white),
            ),
          ),
          const Positioned(left: 8, top: 8, child: _ImageLabel('BEFORE')),
          const Positioned(right: 8, top: 8, child: _ImageLabel('AFTER')),
        ],
      ],
    ),
  );
}

class _SplitClip extends CustomClipper<Rect> {
  const _SplitClip(this.fraction);
  final double fraction;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * fraction, 0, size.width, size.height);
  @override
  bool shouldReclip(_SplitClip oldClipper) => oldClipper.fraction != fraction;
}

class _ImageLabel extends StatelessWidget {
  const _ImageLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black54,
    padding: const EdgeInsets.all(4),
    child: Text(text, style: const TextStyle(color: Colors.white)),
  );
}

class FullScreenReview extends StatefulWidget {
  const FullScreenReview({
    super.key,
    required this.before,
    required this.after,
    required this.initialMode,
  });
  final String before;
  final String after;
  final String initialMode;
  @override
  State<FullScreenReview> createState() => _FullScreenReviewState();
}

class _FullScreenReviewState extends State<FullScreenReview> {
  late String mode = widget.initialMode;
  double split = .5;
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Photo'),
      actions: [
        IconButton(
          tooltip: 'Reset zoom',
          onPressed: () => transform.value = Matrix4.identity(),
          icon: const Icon(Icons.restart_alt),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            transformationController: transform,
            maxScale: 5,
            child: ReviewComparison(
              before: widget.before,
              after: widget.after,
              mode: mode,
              split: split,
            ),
          ),
        ),
        SegmentedButton<String>(
          segments: [
            for (final value in ['before', 'after', 'split'])
              ButtonSegment(
                value: value,
                label: Text(
                  value == 'before'
                      ? 'Before'
                      : value == 'after'
                      ? 'After'
                      : 'Split',
                ),
              ),
          ],
          selected: {mode},
          onSelectionChanged: (values) => setState(() {
            mode = values.single;
            transform.value = Matrix4.identity();
          }),
        ),
        if (mode == 'split')
          Slider(
            min: .04,
            max: .96,
            value: split,
            label: 'Comparison split',
            onChanged: (value) => setState(() => split = value),
          ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
