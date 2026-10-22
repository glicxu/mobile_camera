import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'camera_controller.dart';

/// Only visible cells request small previews; disposed cells release their copy.
class ReviewFilmstrip extends StatefulWidget {
  const ReviewFilmstrip({
    super.key,
    required this.camera,
    required this.onSelect,
  });
  final CameraController camera;
  final ValueChanged<int> onSelect;
  @override
  State<ReviewFilmstrip> createState() => _ReviewFilmstripState();
}

class _ReviewFilmstripState extends State<ReviewFilmstrip> {
  late final ScrollController scroll = ScrollController(
    initialScrollOffset:
        (widget.camera.reviewIndex - 2).clamp(0, 100000) * 60.0,
  );
  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.extentAfter < 120) {
        widget.camera.loadMoreReviewPhotos();
      }
    });
  }

  @override
  void didUpdateWidget(ReviewFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final index = widget.camera.reviewIndex;
      final left = index * 60.0;
      if (left < scroll.offset ||
          left + 60 > scroll.offset + scroll.position.viewportDimension) {
        scroll.animateTo(
          (left - 120).clamp(0, scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: ListView.builder(
      scrollCacheExtent: ScrollCacheExtent.pixels(0),
      controller: scroll,
      scrollDirection: Axis.horizontal,
      itemExtent: 60,
      itemCount: widget.camera.reviewCount,
      itemBuilder: (context, index) {
        final camera = widget.camera;
        final asset = camera.reviewingLibrary
            ? camera.libraryPhotos[index]
            : null;
        return Semantics(
          label: 'Photo ${index + 1}',
          selected: index == camera.reviewIndex,
          button: true,
          child: InkWell(
            onTap: camera.busy || camera.reviewLoading
                ? null
                : () => widget.onSelect(index),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(
                  color: index == camera.reviewIndex
                      ? Colors.white
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: asset == null
                  ? Image.file(
                      File(camera.reviewThumbnailPath(index)),
                      cacheWidth: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    )
                  : _LibraryThumbnail(
                      key: ValueKey(asset.id),
                      host: camera.host,
                      id: asset.id,
                    ),
            ),
          ),
        );
      },
    ),
  );
}

class _LibraryThumbnail extends StatefulWidget {
  const _LibraryThumbnail({super.key, required this.host, required this.id});
  final CameraHostApi host;
  final String id;
  @override
  State<_LibraryThumbnail> createState() => _LibraryThumbnailState();
}

class _LibraryThumbnailState extends State<_LibraryThumbnail> {
  PhotoHandle? photo;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.host.loadPhotoPreview(widget.id, 160);
      if (!mounted) {
        await widget.host.releasePhoto(result);
        return;
      }
      setState(() => photo = result);
    } catch (_) {
      /* Keep a placeholder for unavailable thumbnails. */
    }
  }

  @override
  void dispose() {
    final value = photo;
    if (value != null) {
      widget.host.releasePhoto(value).catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => photo == null
      ? const Icon(Icons.image_outlined)
      : Image.file(
          File(photo!.path),
          cacheWidth: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
        );
}
