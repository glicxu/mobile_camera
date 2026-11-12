# Dali Cam 1.0.0 release

Date: October 13, 2026

Build: 5

Release source: `main`

## Release decision

The Flutter implementation is the production Dali Cam application beginning
with version 1.0.0. The native Swift implementation remains in the repository
as the rollback reference; this release does not delete it.

The iOS Release configuration uses the production name, icon, and bundle ID
`com.dalifin.camera`. Debug and Profile retain the separate `Dali Cam Test`
identity and icon so development builds can coexist with production installs.

## Highlights

- Guided Posture, Landscape, and Food packages with swipeable visual recipes.
- Stable visual coaching instruments for horizon, framing, depth, light, and
  camera steadiness.
- One-tap Filters and Beautifier controls, named presets, Auto/Custom/Off
  modes, and separate portrait and landscape treatment settings.
- Timer, voice shutter, configurable long-press burst, shutter-sound control,
  tap focus, exposure compensation, manual exposure, and zoom.
- Photo review, comparison, editing, gallery import/navigation, processed-copy
  export, and Dali Cam signature watermark.
- Immediate portrait/landscape preview rotation and capability-aware camera
  controls.

## Release validation

- Shared catalog and native-processing export checks pass.
- Dart analysis passes; all 37 shared-core tests pass.
- Flutter analysis passes; all 45 app tests pass.
- All 51 native iOS tests pass.
- The App Store archive reports `Dali Cam`, `com.dalifin.camera`, version
  `1.0.0`, build `5`.
- The Release target is also development-signed with the production bundle ID,
  installed on the attached iPhone 13 Pro, and launched successfully. The
  separate `Dali Cam Test` Profile app remains installed.
- The current App Store archive was exported and uploaded to App Store Connect
  on October 13, 2026. Apple finished ingesting build `5` with processing state
  `VALID` for App Store Connect app `6822162016`.
- The preceding Profile candidate passed the physical iPhone camera and native
  bridge suites recorded in
  [Flutter iPhone Port — Remaining Work Checklist](cross_platform_iphone_remaining_work.md).

## Packaging follow-ups

- Complete App Store listing metadata, select build `5`, and submit the release
  for App Review when the product listing is ready. Uploading the valid build
  does not submit or publish the app.
- Android Play bundles require the Dali Camera upload keystore. Set
  `DALI_ANDROID_UPLOAD_KEYSTORE`, `DALI_ANDROID_UPLOAD_STORE_PASSWORD`,
  `DALI_ANDROID_UPLOAD_KEY_ALIAS`, and `DALI_ANDROID_UPLOAD_KEY_PASSWORD` in the
  build environment, then run `flutter build appbundle --release` from
  `apps/dali_camera`. Release builds fail when these values are absent; the
  debug keystore must not be used for Play uploads. Keep the keystore and
  passwords outside Git. Release bundles use `com.dalifin.camera`; Android
  debug builds retain `com.dalicamera.dali_camera`. Confirm that the Play
  listing exists under the production package and choose an unused version
  code before uploading the bundle to the intended track.
- Keep the native source and rollback instructions until the production rollout
  and data-migration behavior are accepted.

## Build 6 follow-up — October 15, 2026

- Uploaded Dali Cam `1.0.0 (6)`, bundle `com.dalifin.camera`, to App Store
  Connect app `6822162016`. Xcode reported `Upload succeeded` and
  `EXPORT SUCCEEDED`; Apple finished processing with state `VALID`.
  Build ID: `02359242-8584-4720-910e-f80ab83f5d72`.
- Keeps the native camera preview mounted behind photo review, avoiding its
  recreation when returning to the camera. Three physical iPhone Profile test
  cycles completed in 5, 10, and 14 ms with the native preview displaying,
  unchanged preview attachment count, and capture enabled.
- Leaving review invalidates pending edits and releases derived photo copies.
- Replaces the tutorial's stray question marks with arrows and a timer icon.
- Release checks: clean Flutter analysis, 47 app tests, 37 shared-core tests,
  shared catalog checks, native-processing export checks, and signed iOS archive.
- Archive: `/private/tmp/dali-camera-build6.9DcAxo/DaliCam.xcarchive`.
- Upload does not submit the app for review or publish a release.

## Build 10 follow-up — October 22, 2026

- Uploaded Dali Cam `1.0.0 (10)`, bundle `com.dalifin.camera`, to App Store
  Connect from commit `13ecfa6`. Xcode reported `Upload succeeded` and
  `EXPORT SUCCEEDED`; Apple finished processing with state `VALID` and marked
  the build App Store eligible.
- Build ID and delivery UUID: `b28bcf64-fdb3-46d1-8a24-c58fb879934a`.
- Export compliance is set to no non-exempt encryption. TestFlight reports
  `READY_FOR_BETA_TESTING` for the internal `cam testing` group, which has
  access to all builds. External testing remains ready for beta submission.
- Includes the approved portrait beautifier recipes, landscape preset
  guidance, and long-press quick selectors for Beautifier and Filters.
- Archive: `/private/tmp/dali-camera-build10-20261022/DaliCam.xcarchive`.
- Upload does not submit the app for App Review or publish a release.

## Android Internal testing — October 24, 2026

- Pulled `main` to `78ae514` before building. The release includes a local
  Android compile fix: require a non-null foreground confidence mask before
  reading it, preserving the existing fallback when segmentation is unavailable.
- Built the normal `lib/main.dart` entry point as `com.dalifin.camera`, version
  `1.0.0`, Android version code `2026102401`, min SDK 26, target SDK 36.
  The explicit Android code exceeds the previously uploaded `2026101301`;
  the shared pubspec/iOS build number remains unchanged.
- Verified release signing against the existing Camera upload certificate.
  Signing configuration location is documented in `AGENTS.md`; no credentials
  were copied into the repository.
- Validation: Flutter analysis passed, all 60 app tests and 37 core tests passed,
  the signed Android App Bundle built successfully, and `jarsigner` verified it.
  No physical Android device test was performed for this release.
- Bundle: `apps/dali_camera/build/app/outputs/bundle/release/app-release.aab`.
  SHA-256: `2544fafd94364b5dddaae47658970505fb0379a86f6e2bd500600729e8796fab`.
- Uploaded and committed Play edit `02146904159971418034` to `internal`.
  A fresh API read verified release `1.0.0 (2026102401)` with status `completed`
  and a matching bundle SHA-256. The production track remains empty.


## Android production preparation - November 11, 2026

- Prepared production release `1.0.0 (2026111102)` in Google Play Console.
  All setup blockers are resolved. Publishing overview reports that the 11
  pending changes can be sent for review. The release has not been submitted
  or published; managed publishing is currently off, so approval after a future
  submission can lead to automatic publication.
- Launch configuration: free, United States only; Photography category;
  ESRB Everyone content rating; target audience ages 13 and older.
- Referenced the published Apple listing for app `6822162016` and reused its
  description with Android device-compatibility notes. Uploaded the existing
  icon, a resized feature graphic, and two genuine Android screenshot layouts.
  The owner confirmed only the feature graphic contains AI-generated imagery;
  its Play asset label is set accordingly.
- Completed privacy policy, app access, ads, advertising ID, content rating,
  target audience, Data safety, government, financial, health, trader, and
  photo-permission declarations. READ_MEDIA_IMAGES is explained by the
  persistent in-app gallery, thumbnail, navigation, and editing workflow.
- Added a privacy-policy link in Settings > About and corrected the Android
  privacy wording. Google ML Kit diagnostics, app interactions, and device or
  installation identifiers are disclosed; photo, voice-command, and capture
  location processing stay on-device. Supporting SDK disclosure:
  https://developers.google.com/ml-kit/android-data-disclosure
- Published the corresponding policy correction at
  https://dalifin.com/privacy/dali-cam from website commit `1434d7e`, branch
  `codex/camera-android-privacy-20261111`. The website checkout is isolated at
  `B:/src/workspaces/dalifin_company_camera_android_20261111`; the us3 source
  checkout is on that branch. Existing changes in the original website checkout
  were preserved. All 40 website tests passed; the normal packaging driver was
  scoped to the website and followed by website/API smoke and public-policy
  checks. Public policy returns HTTP 200 with the Android disclosure.
- Validation: Flutter analysis passed; all 60 app tests passed; release bundle
  built and jarsigner verified it against Camera's upload certificate.
- Uploaded the replacement build to internal testing and updated the connected
  Galaxy S10+ through Google Play. Verified installed code `2026111102`, Play
  installer `com.android.vending`, and physically opened the updated policy
  from Settings > About. The phone retains the normal production app.
- Bundle: `apps/dali_camera/build/app/outputs/bundle/release/app-release.aab`.
  SHA-256: `c72515c9e9ccd5be6b9f790b12bcee7fcca264051777a82426d47af5b653d8ab`.
- Assets: `docs/play_store_assets/`; screenshots show an imported bundled
  landscape reference, rather than claiming it was captured with the phone.
- The high Android version-code acknowledgement is saved for this release.
  Future Android releases should use the next available integer instead of
  introducing another large jump. Existing Play history already requires the
  current high code.

### Google Play promo with fresh AudioLab narration

- Generated new English narration in Dali Audio Lab using Dali Female Narrator
  with Energetic delivery, job `6e7ef662-607b-4100-8ca4-dbdb004afb21`.
- Final video: `docs/play_store_assets/video/dali-cam-google-play-promo-audiolab-30s.mp4`.
  Verified 30-second H.264 video with AAC stereo audio and a successful full decode.
  Standalone narration is available as `dali-cam-audiolab-voiceover.mp3` beside it.
- Uploaded unlisted to the authorized Gang Li (@18miles) channel:
  https://www.youtube.com/watch?v=ziwLmYTzTAI. Embedding is enabled, AI use is
  disclosed, and YouTube checks completed with no issues found.
- Saved the URL in the default Play listing. Feature graphic and video carry
  AI asset labels; icon and actual app screenshots remain unlabeled.
- The production release remains ready to send for review, without submission.
