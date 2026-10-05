# Dali Camera Core

Platform-independent Dart package containing the versioned native camera
contract and coaching rules. It deliberately has no Flutter or platform SDK
dependencies.

The core now includes the 10-pose/five-camera-position catalog, manually advanced
guidance sessions, scheduler fallback/reset behavior, full-frame preview geometry,
and a capture/review recovery state machine. `PhotoWorkflow` accepts native
`PendingPhotoStore` and `PhotoLibraryWriter` adapters so permissions, disk errors,
save retry, and selected-variant export can be tested without platform SDKs.
Sharing reads a copy of the original bytes; cancelling a share does not discard it.
This package is not a Flutter camera UI or an Android camera adapter. The native
iOS app remains the phone-testable application.

## Contract rules

- Coordinates use the visible preview: `(0, 0)` is top-left and `(1, 1)` is
  bottom-right.
- Native adapters apply crop, rotation, and mirroring before publishing boxes
  and points.
- `displayRotationDegrees` is clockwise and limited to `0`, `90`, `180`, or
  `270`.
- `mirrored` describes the displayed preview, not the camera sensor buffer.
- Optional detector output uses `Measured<T>` so unsupported, unavailable,
  low-confidence, and valid values cannot be confused with numeric zero.
- Schema version 1 JSON is intended for fixture replay. The live transport can
  use a generated typed codec while preserving the same semantics.

Run checks from this directory with `dart pub get`, `dart analyze`, and
`dart test`.
