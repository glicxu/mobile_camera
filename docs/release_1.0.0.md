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
