# Dali Camera Watermark Product Roadmap

Date: November 24, 2026

Status: Presence-based pixel watermarking and offline DALI2 metadata identities are implemented in the Flutter camera for Android and iOS. Android has been compiled, tested, and deployed to a Samsung device. The iOS implementation is present but still requires compilation and physical-device acceptance on macOS.

## Purpose

Turn Dali Camera's hidden-watermark work into a credible product feature for photographers, creators, agencies, and teams that need to identify images, preserve attribution, and inspect provenance signals.

The product should eventually answer three different questions:

1. **Is a supported hidden watermark present?**
2. **Which Dali identity or photo record does it represent?**
3. **Can Dali verify that the identity and photo record are authentic and have not been substituted?**

The current implementation answers the first question and partially answers the second through metadata. It does not yet provide cryptographic ownership proof.

## Product opportunity

A watermark feature can differentiate Dali Camera from ordinary camera and editing apps when it is presented as an integrated capture-to-verification workflow rather than a decorative logo.

Potential customer value includes:

- persistent creator or studio attribution;
- a second identification channel when ordinary metadata is stripped;
- verification when receiving images from another Dali user;
- faster review of licensed, submitted, or commissioned photos;
- a visible verification result without displaying a visible watermark over the photograph;
- an upgrade path to signed provenance, team identities, and verification reports.

Strong positioning language:

> Dali Camera can embed and detect an invisible Dali identity signal while preserving the visible photograph.

Claims to avoid until later phases are complete:

- “proves legal ownership”;
- “cannot be removed”;
- “detects every hidden watermark”;
- “tamper-proof”;
- “survives every edit, screenshot, crop, or social network.”

The watermark should be sold as an attribution, provenance, and verification signal. Legal ownership still depends on contracts, copyright law, original files, local capture records, and other evidence.

## Offline-only privacy architecture

Dali watermarking and verification must not require a Dali server, user account, photo upload, or network connection.

Product requirements:

- photos remain on the device unless the user explicitly shares or exports them;
- watermark embedding and detection run locally;
- signing and verification run locally;
- private signing keys remain in Android Keystore or iOS Keychain-backed storage;
- public identity can be shared as a user-controlled QR code or `.dali-profile` file;
- verification reports are generated as local files and shared only by explicit user action;
- batch verification runs on-device or in a future local desktop/CLI tool;
- analytics do not upload photos, watermark IDs, public labels, or verification history;
- app functionality does not degrade when the device is offline.

The application may use operating-system app-store, backup, or crash-reporting infrastructure elsewhere, but the watermark feature itself must not depend on it. Private watermark keys should be excluded from automatic cloud backup unless a later design can prove that backup is end-to-end encrypted and explicitly controlled by the user.

## What is implemented

### Capture choices

Dali Camera currently offers four capture modes under **Settings → Photos → Hidden Dali watermark**:

| Mode | Pixel signal | Metadata identifier |
| --- | --- | --- |
| Both | Yes | Yes |
| Pixels | Yes | No |
| Metadata | No | Yes |
| Off | No | No |

**Both** is the default and provides two independent detection paths.

### Metadata watermark

- Each new identifier uses the `DALI2-` format and contains a generated canonical owner ID, a unique per-photo ID, and the user's optional public watermark ID.
- A photographer can explicitly create a new local identity. Dali warns that existing photos retain the previous owner ID and will no longer be labeled as the photographer's photos on that device.
- The offline watermark profile is editable under **Settings → Photos → Offline watermark profile** and persists on the device without an account or server.
- Existing `DALI1-` identifiers remain detectable and are displayed as legacy watermarks.
- The identifier is stored in the photo's EXIF `ImageUniqueID` field.
- Photo Info independently detects the identifier and displays the public watermark ID, canonical owner ID, photo ID, full identifier, and **Copy ID** action.
- Photo Info compares DALI2 owner IDs locally and labels a match as **Your offline watermark** or a mismatch as **Watermark from another Dali profile**.
- The metadata editor can add or remove the metadata identifier.
- Android and iOS preserve the supported identifier while copying or processing a photo.

Limitations:

- EXIF metadata can be edited, copied to another image, or removed by other applications and services.
- The current identifier is not signed and is not tied to a local Dali public key.
- Public labels are not globally reserved. Another person can copy a label or complete unsigned DALI2 value.
- The local owner match means only that the embedded owner ID equals the profile stored on this device. It is not cryptographic proof, and resetting or losing the local profile removes that association.
- Possession of a `DALI1-` or `DALI2-` value is not proof that the displayed person or organization created the image.

### Pixel watermark

- Android and iOS embed a low-strength, deterministic signal into image pixels.
- Android Dali Pixel v3 also embeds compact owner and photo references in a repeated, CRC-protected tiled channel.
- The signal is distributed across the image rather than stored as visible text.
- Photo Info reports whether the Dali pixel pattern is detected.
- Pixel and metadata detection are independent, allowing the app to report one even when the other is missing.

Limitations:

- iOS remains presence-only; Android can recover compact owner/photo references within the tested crop, quarter-turn rotation, and JPEG 90 crop cases.
- Android still uses a shared synchronization pattern, while the CRC-valid payload distinguishes compact photographer and photo references.
- Robustness remains incomplete for aggressive resizing, screenshots, denoising, perspective changes, generative edits, and real social-media pipelines.
- Detection currently supports Dali's pattern, not arbitrary proprietary watermark systems.

### Photo Info and metadata editing

Photo Info currently presents:

- metadata-watermark detection;
- full metadata watermark ID and copy action;
- pixel-watermark detection;
- descriptive and rights metadata;
- capture date, camera, lens, and exposure details;
- location when available;
- Dali capture diagnostics when recorded.

The editor supports descriptive, rights, software, capture/equipment, exposure, and location fields. Dimensions, orientation, the pixel watermark, and Dali capture diagnostics remain read-only.

### Current validation

- Flutter analysis passes.
- Focused metadata and watermark UI tests pass.
- The complete Flutter test suite passes, including offline-profile persistence, Settings editing, DALI1 compatibility, DALI2 parsing, and Photo Info display.
- Android native watermark and metadata code compiles.
- Android debug builds have been installed and launched on a Samsung Galaxy S10+.
- iOS source changes are present but require macOS compilation and physical-device testing.

## What the current result means

| Result | Current interpretation |
| --- | --- |
| Pixel detected + metadata detected | A Dali pixel signal and a supported `DALI1-` or `DALI2-` metadata value are present. They are not yet cryptographically linked. |
| Pixel detected only | A Dali presence signal is detected, but the current pixel format cannot identify its owner or photo record. |
| Metadata detected only | A supported Dali EXIF identity is present, but the Dali pixel signal was not detected. |
| Neither detected | No supported Dali watermark was found. This does not prove that no other watermark exists. |

The app should not label the current results **Verified owner**. The accurate terms are **Detected**, **Metadata ID present**, and **Pixel signal present**.

## Recommended target experience

### Photographer experience

The photographer creates a Watermark Profile with:

- a public display label, such as `GLICX-PHOTO`;
- an optional public business or portfolio link;
- a Dali-generated canonical owner ID;
- a signing key protected by device secure storage and user-controlled encrypted recovery;
- privacy controls defining what viewers may see.

For each photo, Dali creates:

- a unique photo ID;
- the canonical owner ID or key fingerprint;
- watermark-format version;
- capture timestamp or record timestamp;
- a signature or reference to a signed verification record.

The photographer sees the complete identity, full photo ID, verification status, profile controls, export/report actions, and any warnings about damaged or conflicting signals.

### Viewer experience

When a viewer imports or opens a photo, Dali reports one of these states:

| State | Meaning |
| --- | --- |
| Verified | The decoded pixel identity, metadata record, and signature agree. |
| Dali watermark identified | A valid Dali payload was recovered, but full signature verification is unavailable. |
| Pixel signal detected | A Dali signal was found, but no identity payload could be recovered. |
| Metadata only | A Dali metadata record exists without a matching pixel signal. |
| Conflict | Pixel and metadata identities disagree. |
| Damaged or uncertain | Some evidence exists, but confidence is below the verification threshold. |
| Not detected | No supported Dali signal was found. |

The viewer should see only public profile information. Email addresses, device identifiers, private recovery data, and signing secrets must never be embedded.

Without a server, a human-readable owner label can be resolved in three ways:

1. the photo retains its signed metadata profile;
2. the viewer previously imported the photographer's public QR/profile file;
3. a future pixel format carries a self-contained public profile and signature, if the payload and robustness budget permit it.

If metadata is removed and the viewer does not have the matching public profile, Dali may recover only an opaque key fingerprint or photo ID. The app must report that limitation instead of inventing or trusting an unsigned owner name.

## Recommended identity design

Separate the user-facing label from the trusted identity.

| Element | Example | Purpose |
| --- | --- | --- |
| Display label | `GLICX-PHOTO` | Memorable public branding chosen by the user. |
| Canonical owner ID | Random identifier or public-key fingerprint | Stable identity not dependent on label uniqueness. |
| Photo ID | Random per-photo identifier | Distinguishes individual captures and records. |
| Format version | `DALI2` | Allows detector and payload upgrades. |
| Signature | Ed25519 or equivalent | Detects forged or substituted records. |

A display label alone is not trustworthy because another user can choose or copy the same text. A canonical ID and signature provide the technical basis for future verification.

Do not place raw personal information in the pixel payload. A compact payload should contain only versioning, a key fingerprint or owner reference, a photo reference, and error-detection/error-correction data.

## Technical roadmap

Effort ranges assume one experienced mobile engineer, part-time product/design and QA support, and cryptography/security assistance where identified. They are planning ranges, not commitments.

### Phase 0: Harden the current feature

Android status: **Automated baseline implemented and measured.** See [Android Watermark Phase 0 Baseline](watermark_android_phase0.md). Android third-party app export checks and broader natural-photo/device coverage remain manual acceptance work. iOS remains outside the Android-only Phase 0 requested on November 24, 2026.

Estimated effort: **2–4 engineer-weeks**

Work:

- compile and test the iOS implementation on supported iPhones;
- create a repeatable image-transformation test corpus;
- measure false-positive and false-negative rates;
- test JPEG recompression, resize, crop, rotation, screenshot, filters, denoise, blur, sharpen, and common messaging/social exports;
- improve Photo Info language and separate detection from verification;
- add format/version details to diagnostic output;
- confirm metadata preservation and removal behavior across Android and iOS libraries;
- document supported image formats and minimum dimensions.

Exit criteria:

- measured baseline accuracy rather than anecdotal detection;
- no ownership or robustness claims beyond measured evidence;
- Android and iOS device acceptance complete;
- repeatable tests protect future algorithm changes.

### Phase 1: Watermark Profiles and user-defined labels

Current status: **Core local profile vertical slice implemented.** Public labels, canonical owner IDs, per-photo IDs, local owner/viewer labeling, persistence, and explicit profile rotation are available. Encrypted export/recovery, profile privacy fields, and portable verification reports remain future work.

Estimated effort: **3–6 engineer-weeks**

Work:

- add profile creation and public display-label controls;
- generate a canonical owner ID independently of the display label;
- define local profile storage, migration, backup, and reset behavior;
- add encrypted user-controlled profile/key export and recovery without a Dali account;
- associate new metadata IDs with the selected profile;
- show photographer and viewer versions of Photo Info;
- support profile privacy settings;
- add exportable verification details without claiming cryptographic proof.

Exit criteria:

- photographers can choose a public label;
- duplicate labels do not imply identical owners;
- every new watermarked photo has an owner reference and photo reference in metadata;
- viewer UI never exposes private profile data.

This phase creates immediate product value but remains metadata-led. It does not make the existing pixel signal identify an owner.

### Phase 2: Payload-bearing pixel watermark

Android status: **Initial vertical slice implemented.** Dali Pixel v2 carries compact owner and photo references with a CRC, supports local metadata agreement/conflict reporting, and retains Dali Pixel v1 presence detection. See [Android Pixel Watermark Phase 2 Vertical Slice](watermark_android_phase2.md). Full transformation measurement, error correction, synchronization, stable format review, and iOS support remain future work.

Estimated effort: **6–12 engineer-weeks**, followed by ongoing tuning

Work:

- design a compact binary payload with magic bytes, version, owner/key fingerprint, photo ID or record reference, and checksum;
- add forward-error correction and interleaving;
- replace or extend the fixed presence pattern with payload modulation;
- recover payload confidence and correction statistics during detection;
- add crop/scale synchronization or repeated payload blocks;
- maintain acceptable visual quality and capture latency;
- version the format so old Dali photos remain detectable;
- build a large transformed-image validation corpus.

Exit criteria:

- another Dali installation can recover the same compact identity from pixels alone within defined transformation limits;
- false-positive, false-negative, payload-error, latency, and quality targets are measured;
- detector results include confidence and format version;
- the application distinguishes a recovered identity from a presence-only legacy signal.

This is the key technical step required for “identify the photographer after metadata removal.”

### Phase 3: Cryptographic verification

Android status: **Initial offline signature vertical slice implemented.** Owner-specific P-256 keys are generated in Android Keystore, signed manifests bind full owner/photo hashes and decoded image pixels, and Photo Info distinguishes verified, modified-image, identity-conflict, missing-metadata, and invalid-signature states. See [Android Offline Signature Phase 3 Vertical Slice](watermark_android_phase3.md). Export/recovery, revocation, security review, iOS, and production hardening remain future work.

Estimated effort: **6–12 engineer-weeks** across mobile and security work

Work:

- generate and protect signing keys using Keychain/Keystore-backed storage;
- define signed photo manifests and canonical serialization;
- bind owner ID, photo ID, selected image digest, and relevant metadata;
- embed the public key or signed public profile in metadata where size permits;
- define a portable public identity QR code and `.dali-profile` file;
- build local key rotation, revoked-key lists, lost-device behavior, and encrypted user-controlled recovery;
- verify that pixel, metadata, manifest, and public key agree;
- add clear conflict and unverifiable states;
- commission a focused security review before strong verification claims.

Exit criteria:

- copied metadata does not produce a verified result on an unrelated image;
- forged labels or IDs do not verify without the signing key;
- all verification works in airplane mode;
- key loss, local revocation, and recovery have documented user-controlled paths;
- no watermark operation sends a photo, identity, key, or verification result to Dali infrastructure.

### Phase 4: Robustness and production scale

Android status: **Initial robustness vertical slice implemented.** Dali Pixel v3 adds repeated local presence and tiled identity channels that synchronize after arbitrary crop offsets and quarter-turn rotations. Photo Info exposes payload recovery mode, robust-score, pair-axis, rotation-normalization, and detection-time diagnostics. V1/V2 detection remains supported. Recovery after resizing, screenshots, perspective changes, and social-media pipelines remains future work; see [Android Watermark Phase 4 Robustness](watermark_android_phase4.md).

Estimated effort: **6–12 engineer-weeks initially**, then continuous algorithm work

Work:

- tune embedding strength by image content;
- support multiple resolutions and encoding pipelines;
- improve resilience to crop, scale, recompression, screenshot, and moderate edits;
- benchmark battery, memory, capture latency, and heat;
- add batch verification and a local desktop/CLI detector where commercially useful;
- keep detector metrics local and provide explicit diagnostic export when the user chooses;
- establish version rollout and backward-compatibility policy.

Exit criteria:

- published robustness claims match a versioned test matrix;
- capture performance remains within product targets;
- detector upgrades preserve support for older Dali watermark versions;
- privacy review confirms that watermarking and verification have no network dependency.

### Phase 5: Third-party watermark detection

This should use a detector-plugin architecture rather than a promise to detect every watermark.

| Integration type | Typical effort | Expected result |
| --- | --- | --- |
| Offline vendor SDK | 2–10 engineer-days per vendor, plus licensing | Reliable local vendor-supported detection within the SDK's limits. |
| Published/open format | 2–6 engineer-weeks per format | Independent detector with testable behavior. |
| Known proprietary system without SDK | 1–3+ engineer-months per system | Fragile research result with legal, maintenance, and accuracy risk. |
| Generic “watermark may exist” classifier | 3–6+ months plus a large labeled dataset | Suspicion score, usually without owner or payload recovery. |
| Decode any unknown proprietary watermark | Not a reasonable product commitment | Good systems deliberately hide keyed signals and payload formats. |

Recommended scope:

- fully support Dali formats;
- integrate selected vendors only when an offline SDK, commercial agreement, and customer demand exist;
- identify Content Credentials and ordinary metadata as separate provenance channels;
- never report an unknown watermark as verified;
- expose detector name, version, confidence, and limitations.

Remote vendor APIs are excluded because they would require sending photo data or derived image content to another service.

## Suggested product packaging

Pricing and entitlements remain product decisions. A practical structure is:

### Free

- detect supported Dali watermarks;
- view public watermark identity and verification state;
- use the default Dali watermark profile;
- capture with the default **Both** mode.

### Creator or Pro

- custom public display label;
- selectable watermark modes;
- full photo IDs and verification history;
- local verification report export;
- encrypted user-controlled profile backup/recovery;
- batch checks or higher verification limits;
- configurable public profile details.

### Studio or Business

- organization identities and managed team profiles;
- multiple photographers under one organization;
- role-based key and profile management;
- bulk verification and licensing exports;
- local desktop/CLI detector access;
- audit records and key revocation controls.

Do not gate basic viewing or safety explanations. A recipient should be able to understand a Dali verification result without paying.

## Demo narrative

A strong sales demonstration can use one photo and four versions:

1. **Original:** Both metadata and pixel signal are detected.
2. **Metadata stripped:** Android can recover compact owner/photo references from the V3 pixel payload within tested limits.
3. **Recompressed or resized:** Detector reports whether the signal remains recoverable and displays confidence.
4. **Metadata copied to another photo:** Android's offline signed manifest and pixel identity can report a conflict instead of a verified owner.

The current Android product can demonstrate all four within the documented transformation limits. iOS remains at the earlier presence-only stage.

## Sales and product metrics

Measure whether the feature creates customer value rather than only technical novelty:

- percentage of captures using Both, Pixels, Metadata, or Off;
- percentage of inspected photos with each detection result;
- successful payload recovery rate by transformation type;
- false-positive and false-negative rates on the maintained test corpus;
- verification completion time and on-device latency;
- conversion from default profile to custom profile;
- number of locally generated verification reports;
- team adoption and active managed profiles;
- support requests related to missing or conflicting watermarks.

Photo content, watermark IDs, identity labels, and verification history should not be collected for analytics. Keep aggregate counters local and allow users to export diagnostics explicitly when requesting support.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Customers interpret detection as ownership proof | Use precise states and reserve **Verified** for cryptographically checked records. |
| Metadata is copied or removed | Treat metadata as one channel and cryptographically bind it in Phase 3. |
| Pixel signal is removed by transformations | Publish measured limits, repeat payloads, use synchronization/error correction, and report confidence. |
| Pixel embedding affects visible quality | Maintain perceptual-quality tests, configurable strength, and representative image review. |
| Custom labels impersonate brands or people | Keep canonical IDs separate, add reporting/policy controls, and never verify labels alone. |
| Key loss locks out creators | Provide encrypted user-controlled backup, rotation, local revocation, and recovery before strong identity claims. |
| Proprietary detector integrations create legal or licensing issues | Prefer official SDKs, written agreements, and published formats. |
| A new device cannot resolve an opaque owner fingerprint | Preserve signed metadata and support user-shared public QR/profile files; report unresolved fingerprints honestly. |
| Watermarking creates privacy concerns | Embed opaque identifiers, not emails, names, device IDs, or location by default. |

## Recommended next milestone

Complete **Phase 0** and design **Phase 1** before starting payload encoding.

Immediate tasks:

1. Compile and validate the current implementation on iPhone.
2. Build a versioned transformation corpus and baseline detector report.
3. Finalize Photo Info terms: Detected, Identified, Verified, Conflict, and Uncertain.
4. Define Watermark Profile data, privacy defaults, canonical owner IDs, and photo IDs.
5. Prototype the payload bit budget and error-correction strategy before committing to UI or marketing claims.
6. Define the offline public-profile QR/file format and encrypted key-recovery flow.

At the end of that milestone, Dali should have a defensible current feature, measured limitations, a sellable profile concept, and enough payload research to estimate the identity-bearing watermark accurately.

## Implementation references

- Flutter capture settings and metadata flow: `apps/dali_camera/lib/camera_controller.dart`
- Flutter Photo Info and metadata editor: `apps/dali_camera/lib/photo_metadata_sheet.dart`
- Flutter settings UI: `apps/dali_camera/lib/main.dart`
- Android metadata handling: `packages/dali_camera_platform/android/src/main/kotlin/com/dalicamera/dali_camera_platform/PhotoMetadata.kt`
- Android pixel watermark: `packages/dali_camera_platform/android/src/main/kotlin/com/dalicamera/dali_camera_platform/HiddenWatermark.kt`
- iOS metadata handling: `packages/dali_camera_platform/ios/dali_camera_platform/Sources/dali_camera_platform/PhotoMetadata.swift`
- iOS pixel watermark: `packages/dali_camera_platform/ios/dali_camera_platform/Sources/dali_camera_platform/HiddenWatermark.swift`
- Cross-platform host API: `packages/dali_camera_platform/pigeons/camera_api.dart`
