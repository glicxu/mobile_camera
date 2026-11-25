# Android Watermark Phase 0 Baseline

Date: November 24, 2026

Status: Android detector hardening, device-run synthetic transformation baseline, metadata lifecycle checks, detector diagnostics, and user-facing detection language are implemented. Results below are from a Samsung SM-G975U running Android 12. iOS is intentionally outside this phase.

Companion roadmap: [Dali Camera Watermark Product Roadmap](watermark_product_roadmap.md)

Machine-readable result: [`fixtures/watermark/android_phase0_baseline_v1.json`](../fixtures/watermark/android_phase0_baseline_v1.json)

## Phase 0 outcome

The current `DALI_PIXEL_V1` detector is a useful capture-time presence signal, but it is not robust to geometry changes. It performs well on the unchanged image, JPEG quality 90, an aligned center crop, the tested blur and sharpen operations, and grayscale conversion. It partially survives stronger JPEG recompression. It does not currently survive resizing, rotation, an unaligned crop, screenshot simulation, or a downscaled social-export simulation.

This phase establishes measured limits; it does not change the watermark into an identity-bearing or cryptographically verified format.

## Implemented hardening

- Added a versioned Android detector result with:
  - detected/not detected;
  - format version `DALI_PIXEL_V1`;
  - normalized detection score;
  - sample count;
  - minimum supported dimension.
- Photo Info now states that pixel detection and metadata-ID presence are **not identity verification**.
- Photo Info displays the pixel format, presence-only limitation, detection score, sample count, and minimum dimensions.
- Added deterministic Android instrumentation tests that generate image classes without using customer photos.
- Added transformations for JPEG recompression, resize, aligned and unaligned crop, 90° and 180° rotation, blur, sharpen, grayscale, screenshot simulation, and social-export simulation.
- Added native metadata lifecycle coverage confirming that `DALI1-` is added, preserved through metadata copy, and removed on request.
- Added a below-minimum-size test.
- Added a versioned, machine-readable baseline fixture.

## Detector definition

| Property | Current value |
| --- | --- |
| Format | `DALI_PIXEL_V1` |
| Payload | Presence only; no owner or photo ID |
| Minimum dimensions | 64 × 64 pixels |
| Detection threshold | Normalized score greater than 0.75 |
| Production capture format | JPEG |
| Identity verification | Not supported |
| Cryptographic verification | Not supported |

Android `BitmapFactory` may decode additional formats, but Phase 0 makes no compatibility or robustness claim for PNG, WebP, HEIF, AVIF, RAW, video, or animated images. Dali's current watermark capture path writes JPEG.

## Device baseline

The corpus uses 32 deterministic 320 × 240 synthetic scenes representing gradients, high-frequency noise, checker patterns, dark scenes, bright scenes, low-contrast scenes, color bands, and radial detail. Each transformation evaluates 32 marked and 32 clean images.

| Transformation | Marked detected | Clean false positives | Phase 0 interpretation |
| --- | ---: | ---: | --- |
| Unchanged | 32/32 (100%) | 0/32 | Pass |
| JPEG quality 90 | 32/32 (100%) | 0/32 | Pass |
| JPEG quality 75 | 24/32 (75%) | 0/32 | Partial |
| JPEG quality 60 | 24/32 (75%) | 0/32 | Partial |
| Resize to 75% | 0/32 | 0/32 | Not supported |
| Resize to 50% | 0/32 | 0/32 | Not supported |
| Center crop to 80%, aligned | 32/32 (100%) | 0/32 | Pass for this alignment only |
| Center crop to 79%, unaligned | 0/32 | 0/32 | Not supported generally |
| Rotate 90° | 0/32 | 0/32 | Not supported |
| Rotate 180° | 0/32 | 0/32 | Not supported |
| 3 × 3 blur/denoise approximation | 32/32 (100%) | 0/32 | Pass for tested operation |
| 3 × 3 sharpen | 32/32 (100%) | 0/32 | Pass for tested operation |
| Grayscale filter | 32/32 (100%) | 0/32 | Pass |
| Screenshot simulation | 0/32 | 0/32 | Not supported |
| Social-export resize/JPEG simulation | 0/32 | 0/32 | Not supported |

Across all transformations, the run evaluated 480 marked and 480 clean cases. It produced 0 false positives among the 480 clean synthetic cases. This is not a population-level false-positive guarantee; the corpus is deterministic, synthetic, and intentionally small enough to run in Android CI or on a development phone.

## Metadata lifecycle result

The Android device test confirms:

1. capture writes a valid `DALI1-` value to EXIF `ImageUniqueID`;
2. the metadata-copy path preserves it;
3. metadata editing removes it when requested.

This confirms application behavior, not authenticity. EXIF remains user-editable and copyable.

## User-facing interpretation

Photo Info should be interpreted as follows:

| Display | Meaning |
| --- | --- |
| Metadata identifier present | A valid `DALI1-` EXIF value exists. It is not identity verification. |
| Pixel signal detected | The `DALI_PIXEL_V1` presence pattern exceeded its detection threshold. No owner ID is encoded. |
| Pixel signal not detected | The score did not exceed the threshold. Editing may have removed the signal, or the photo may never have contained it. |
| Both present | Both independent signals exist; they are not cryptographically linked in V1. |

Do not use **Verified owner**, **tamper-proof**, **cannot be removed**, or **survives social media** for the current Android implementation.

## Supported claims

Reasonable current claim:

> Dali Camera can embed and detect its invisible presence signal in unchanged Android JPEG captures and can independently store and inspect a Dali metadata identifier.

Measured qualification:

> In a 32-scene synthetic Galaxy S10+ baseline, detection was 100% for unchanged images and JPEG quality 90, 75% at JPEG qualities 75 and 60, and 0% after the tested resize, rotation, screenshot, and social-export simulations. No false positives occurred in 480 clean synthetic cases.

These results should not be generalized beyond the recorded device, corpus, operations, and detector version.

## Repeat the baseline

With an authorized Android device attached:

```powershell
cd apps\dali_camera\android
.\gradlew.bat :dali_camera_platform:connectedDebugAndroidTest --no-daemon --console=plain --max-workers=2
adb logcat -d -s DaliWatermarkPhase0:I '*:S'
```

The test source is:

`packages/dali_camera_platform/android/src/androidTest/kotlin/com/dalicamera/dali_camera_platform/HiddenWatermarkPhase0Test.kt`

The test also writes `watermark-phase0-report.json` to the instrumentation test app's external-files directory while that test package is installed. The checked-in fixture preserves the accepted device result after Gradle removes the test package.

## Remaining Android acceptance work

The following require manual workflows or external accounts and are not claimed by the automated baseline:

- export through specific versions of Instagram, Facebook, WhatsApp, Messenger, Signal, Google Photos, Samsung Gallery, and other third-party apps;
- screenshots taken through the physical Android UI rather than the deterministic screenshot simulation;
- a large natural-photo negative corpus for a statistically meaningful false-positive rate;
- multiple Android manufacturers, OS versions, camera resolutions, and image pipelines;
- visual-quality review on portraits, low light, smooth skies, gradients, text, and high-detail scenes;
- capture-latency, battery, heat, and memory benchmarks.

These checks should be recorded by app version because third-party export behavior can change independently of Dali Camera.

## Engineering conclusion

Phase 0 confirms that the current detector is suitable as an honest, presence-only prototype. Its coordinate-locked pattern explains the strong unchanged-image result and the immediate failures after resize, rotation, or unaligned crop. Marketing should use the measured limits above.

Identity recovery and broader transformation resilience require the payload, synchronization, repetition, and error-correction work described in Phases 2 and 4 of the product roadmap. Lowering the current threshold alone would not solve geometry changes and would increase false-positive risk.
