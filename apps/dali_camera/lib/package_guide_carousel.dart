import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';

import 'camera_controller.dart';

/// Compact package browser shown directly in the live coaching area.
class PackageGuideCarousel extends StatefulWidget {
  const PackageGuideCarousel({super.key, required this.camera});

  final CameraController camera;

  @override
  State<PackageGuideCarousel> createState() => _PackageGuideCarouselState();
}

class _PackageGuideCarouselState extends State<PackageGuideCarousel> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final kind = widget.camera.activeSituation.catalogKind;
    if (kind == null) {
      return _UnavailableGuideCard(
        situation: widget.camera.activeSituation.title,
      );
    }
    final packages = widget.camera.catalog.packages(kind).entries.toList();
    if (packages.isEmpty) {
      return _UnavailableGuideCard(
        situation: widget.camera.activeSituation.title,
      );
    }
    page = page.clamp(0, packages.length - 1);
    return Container(
      key: const Key('packageGuideCarousel'),
      height: 184,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withValues(alpha: .75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'GUIDES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              Text(
                '${page + 1} / ${packages.length}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PageView.builder(
              key: const Key('packageGuidePages'),
              itemCount: packages.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) {
                final package = packages[index];
                final entries = widget.camera.catalog.entries
                    .where(
                      (entry) =>
                          entry.kind == kind && entry.package == package.key,
                    )
                    .take(3)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Row(
                        children: [
                          for (var item = 0; item < entries.length; item++) ...[
                            if (item > 0) const SizedBox(width: 6),
                            Expanded(
                              child: _GuideThumbnail(
                                camera: widget.camera,
                                entry: entries[item],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (packages.length > 1)
            const Center(
              child: Text(
                '‹  Swipe for another package  ›',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideThumbnail extends StatelessWidget {
  const _GuideThumbnail({required this.camera, required this.entry});

  final CameraController camera;
  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final selected = camera.guidance.entry?.id == entry.id;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Use ${entry.title} guidance',
      child: InkWell(
        key: Key('guideThumbnail_${entry.id}'),
        borderRadius: BorderRadius.circular(7),
        onTap: () => camera.choose(entry),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? Colors.tealAccent : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                entry.asset,
                cacheWidth: 220,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  color: Colors.black.withValues(alpha: .72),
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableGuideCard extends StatelessWidget {
  const _UnavailableGuideCard({required this.situation});

  final String situation;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('packageGuideUnavailable'),
    margin: const EdgeInsets.only(top: 8, bottom: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white24),
    ),
    child: Text('No $situation guide package is available yet.'),
  );
}
