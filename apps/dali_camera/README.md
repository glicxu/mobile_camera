# Dali Camera Flutter application

Shared Android/iOS application. Uses `packages/dali_camera_core` for catalogs, geometry and coaching, and `packages/dali_camera_platform` for native camera services.

```sh
flutter pub get
flutter run -d YOUR_PHONE_ID
```

See [Android and Flutter iOS testing](../../docs/android_testing.md), [feature coverage](../../docs/cross_platform_parity.md), and the [implementation plan](../../docs/dali_camera_cross_platform_port_plan.md).

The existing root Xcode project remains the full native iOS reference during migration. This new application's first milestone covers capture/review/export and basic guidance; remaining parity is tracked explicitly in the coverage document.
