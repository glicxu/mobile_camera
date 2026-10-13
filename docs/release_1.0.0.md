# Dali Cam 1.0.0 release

Date: October 12, 2026

Build: 2

Release source: `codex/cross-platform-20261007`

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
- Flutter analysis passes; all 44 app tests pass.
- All 51 native iOS tests pass.
- Unsigned iOS Release device build passes and reports `Dali Cam`,
  `com.dalifin.camera`, version `1.0.0`, build `2`.
- The preceding Profile candidate passed the physical iPhone camera and native
  bridge suites recorded in
  [Flutter iPhone Port — Remaining Work Checklist](cross_platform_iphone_remaining_work.md).

## Packaging follow-ups

- Create and export the distribution-signed iOS archive in App Store Connect.
  The local release verification intentionally did not replace the production
  app installed on the attached iPhone.
- Configure the protected Android release keystore in CI. The current Gradle
  release target uses debug signing for development, and this Mac does not have
  an Android SDK, so no Android store artifact was produced at this checkpoint.
- Keep the native source and rollback instructions until the production rollout
  and data-migration behavior are accepted.
