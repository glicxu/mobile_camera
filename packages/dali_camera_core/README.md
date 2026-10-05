# Dali Camera Core

Platform-independent Dart package containing the versioned native camera
contract and coaching rules. It deliberately has no Flutter or platform SDK
dependencies.

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
