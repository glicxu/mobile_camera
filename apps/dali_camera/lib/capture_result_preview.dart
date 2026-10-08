import 'dart:io';
import 'package:flutter/material.dart';

/// Shows the captured frame while native processing runs, then its final result.
class CaptureResultPreview extends StatelessWidget {
  const CaptureResultPreview({
    super.key,
    required this.path,
    required this.status,
    required this.complete,
    required this.onDismiss,
  });

  final String path;
  final String status;
  final bool complete;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.contain,
          cacheWidth: 1080,
          gaplessPlayback: true,
          semanticLabel: complete ? 'Finished photo' : 'Captured photo',
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.photo_outlined, size: 48)),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: Colors.black.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status, textAlign: TextAlign.center),
                    if (!complete) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ] else
                      TextButton.icon(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Back to camera'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
