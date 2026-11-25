# Android Pixel Watermark Phase 2 Vertical Slice

Date: November 24, 2026

Status: Initial Android implementation. This is a development milestone, not a production robustness or ownership-verification claim.

## What changed

`DALI_PIXEL_V2` adds a compact identity payload to the image pixels while retaining the existing `DALI_PIXEL_V1` presence carrier for backward detection.

The pixel payload contains:

- format magic and version;
- a 32-bit reference derived from the canonical owner ID;
- a 32-bit reference derived from the unique photo ID;
- a CRC-16 integrity check.

The payload does not contain the public label, photographer name, email address, URL, device identifier, or full metadata watermark. It is generated and detected entirely on-device.

## App behavior

Photo Info reports `DALI_PIXEL_V2` when a valid checked payload is recovered. It displays the compact owner and photo references and compares them with references derived from DALI2 EXIF metadata.

Possible results include:

- **Pixel and metadata identities agree:** both channels carry matching references;
- **Pixel and metadata identities conflict:** the two channels carry different references;
- **Identity recovered from pixels; matching metadata is unavailable:** the payload survived but DALI2 metadata is absent;
- the legacy presence-only result when only `DALI_PIXEL_V1` is detected.

Agreement is not cryptographic verification. The current payload is unsigned and is not bound to an image digest.

## Current encoding

The V2 payload is repeated across a carrier separate from the V1 presence samples. A location-dependent scrambling sign reduces systematic bias from ordinary neighboring pixels. Detection combines repeated samples, validates the magic/version fields, and rejects payloads whose CRC does not match.

This first implementation does not yet include forward-error correction, crop/scale synchronization, rotation recovery, or payload block alignment recovery.

## Automated validation

Android instrumentation on a Samsung Galaxy S10+ verifies:

- exact owner-reference recovery;
- exact photo-reference recovery;
- payload version detection;
- CRC-checked round-trip from image pixels;
- recovery after JPEG quality-90 recompression;
- continued execution of the Phase 0 V1 transformation and false-positive baseline.

Flutter tests verify deterministic compact references, shared capture identity, Photo Info agreement/conflict states, and DALI1/DALI2 metadata compatibility.

## Known limitations and next work

- Measure V2 payload recovery across the full transformation corpus rather than assuming V1 presence results apply.
- Add forward-error correction and interleaving.
- Add synchronization for resizing, crop offsets, and rotation.
- Measure false payload recovery separately from presence false positives.
- Measure visual quality and capture latency on natural photos and multiple Android devices.
- Define a stable payload specification before treating the format as externally portable.
- Add iOS embedding and recovery only after the Android format and measurements stabilize.
- Add cryptographic signing in Phase 3 before using the word **Verified**.
