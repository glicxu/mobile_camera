# Dali Camera

For the current phone-testing build, setup steps, and acceptance checklist, see
[`docs/phone_testing.md`](docs/phone_testing.md).

Prototype iOS app for testing the V1 algorithmic camera coach.

## Run On iPhone

1. Open `DaliCamera.xcodeproj` in Xcode.
2. Select the `DaliCamera` scheme.
3. Connect your iPhone.
4. Select your iPhone as the run destination.
5. In the target Signing & Capabilities settings, choose your Apple development team.
6. Press Run.
7. Grant camera permission when the app opens.

The first phone-testable build includes:

- live camera preview,
- Vision person detection,
- Vision face detection,
- CoreMotion camera roll,
- simple face/background luminance measurement,
- deterministic coaching rules,
- one active instruction at a time,
- debug overlay with detected boxes and issue names.

## Cross-Platform Port

The Flutter application is now under `apps/dali_camera`. See
[`docs/android_testing.md`](docs/android_testing.md) for building and testing it,
and [`docs/cross_platform_parity.md`](docs/cross_platform_parity.md) for feature coverage.

The Flutter and native-adapter migration is tracked in
[`docs/dali_camera_cross_platform_port_plan.md`](docs/dali_camera_cross_platform_port_plan.md).

## Current Prototype Advice

- Frame the person
- Step back
- Step closer
- Raise camera
- Lower camera
- Keep feet in frame
- Move left
- Move right
- Tilt left
- Tilt right
- Face the light
- Include more view
- Great shot

## Notes

This is an iOS prototype. The browser files in the repository are a zero-build desktop fallback and are not the primary phone-testing path.
