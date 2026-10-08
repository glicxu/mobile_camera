import 'package:flutter/material.dart';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'camera_controller.dart';

class ReferenceDetails extends StatefulWidget {
  const ReferenceDetails({
    super.key,
    required this.camera,
    required this.initial,
  });
  final CameraController camera;
  final CatalogEntry initial;
  @override
  State<ReferenceDetails> createState() => _ReferenceDetailsState();
}

class _ReferenceDetailsState extends State<ReferenceDetails> {
  late CatalogEntry item = widget.initial;
  void adjacent(int offset) {
    final entries = widget.camera.catalog.entries
        .where(
          (entry) => entry.kind == item.kind && entry.package == item.package,
        )
        .toList();
    final index = entries.indexWhere((entry) => entry.id == item.id);
    setState(
      () => item = entries[(index + offset + entries.length) % entries.length],
    );
    widget.camera.choose(item);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        title: Text(item.title),
        trailing: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onHorizontalDragEnd: item.kind == 'pose'
                    ? (details) {
                        final speed = details.primaryVelocity ?? 0;
                        if (speed.abs() > 100) adjacent(speed < 0 ? 1 : -1);
                      }
                    : null,
                child: Semantics(
                  label: 'Photo example of ${item.title}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(item.asset, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (item.kind == 'pose')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous posture',
                      onPressed: () => adjacent(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const Flexible(child: Text('Swipe for another posture')),
                    IconButton(
                      tooltip: 'Next posture',
                      onPressed: () => adjacent(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                '${item.recipient}: ${item.cues.join(' ')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Text(
                'Recommended camera angle: ${widget.camera.catalog.angleTitle(item)}',
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(widget.camera.catalog.angleInstruction(item)),
              const SizedBox(height: 14),
              Text(
                'Recommended lighting: ${widget.camera.catalog.lightTitle(item)}',
                style: const TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(widget.camera.catalog.lightDescription(item)),
              if (item.data['safetyNote'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(item.data['safetyNote'] as String),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
