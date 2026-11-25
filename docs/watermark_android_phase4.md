# Android Watermark Phase 4 Robustness Vertical Slice

Date: November 24, 2026

Status: Initial Android implementation. Claims are limited to the automated matrix described below.

## Implemented

- `DALI_PIXEL_V3` adds a repeated, locally synchronized presence channel alongside the existing V1 presence and V2 compact identity payload channels.
- Detection searches pixel-grid offsets, pattern phases, horizontal and vertical pixel pairs, and quarter-turn orientations.
- An unaligned crop can retain the compact Owner/Photo references without relying on metadata.
- A 90, 180, or 270 degree rotation can retain the compact Owner/Photo references.
- Existing V1 presence-only and V2 identity-payload photos remain detectable.
- Photo Info reports the robust score, detected pair axis, whether rotation normalization was used, and local detection duration.
- Detection and diagnostics remain entirely offline.

## Important limits

V3 adds a repeated 16×16 tiled identity channel. Recovery searches pixel-grid offsets, tile phases, pair axes, rotation, and polarity, then requires the embedded magic bytes and CRC to validate before reporting Owner/Photo references. Metadata and signed manifests may still be removed or invalidated by external editing.

This slice does not claim resilience to scaling, screenshots, severe recompression, perspective changes, generative edits, or social-media processing. These transformations remain in the test matrix so failed cases stay visible rather than becoming marketing claims.

## Acceptance matrix

Android instrumentation uses 32 deterministic synthetic scenes and checks marked and clean images across JPEG recompression, resizing, aligned and unaligned crops, quarter-turn rotation, blur, sharpen, grayscale, screenshot simulation, and social-export simulation.

Required gates for this slice:

- all directly embedded scenes are detected;
- no clean baseline scene is detected;
- an explicitly unaligned crop retains the V3 owner/photo references;
- quarter-turn rotations retain the V3 owner/photo references;
- JPEG 90 recompression followed by unaligned crop retains CRC-valid V3 identity across the focused corpus;
- a legacy V1-only image is still reported as V1;
- the V2 owner/photo payload still round-trips before unsupported transformations.

The generated device report uses schema `dali.watermark.android-phase4.v1`. Results are evidence for engineering decisions, not a blanket robustness guarantee.

## Next work

- add error correction for smaller or damaged crops;
- add scale synchronization and screenshot experiments;
- tune embedding strength by image texture and luminance;
- benchmark full-resolution decode, detection, memory, battery, and heat across representative Android devices;
- store a reviewed, versioned robustness matrix for each release;
- add user-initiated diagnostic export without network transmission.
