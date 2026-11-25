# Watermark Lifetime Unlock

## Product

Dali Camera uses one non-consumable store product on Android and iOS:

- Product ID: `dali_camera_watermark_lifetime`
- Type: non-consumable / one-time product
- Unlocks: hidden watermark creation, watermark mode selection, and the offline photographer profile
- Remains free: detecting and viewing supported watermarks in Photo Info

The app listens for store purchase updates, completes successful transactions, caches the entitlement for offline use, and provides **Restore purchases**. Photos and watermark identities are not sent to a Dali server.

## Google Play Console

1. Open the Play Console app for release package `com.dalifin.camera`.
2. Create a one-time product with ID `dali_camera_watermark_lifetime`.
3. Configure its name, description, price, and active regions, then activate it.
4. Upload a signed build to an internal testing track.
5. Add license testers and install the app from the Play testing link. A sideloaded debug build uses `com.dalicamera.dali_camera` and cannot query the release app's Play product.
6. Test purchase, app restart while offline, reinstall, and **Restore purchases** with the same Google account.

## App Store Connect

1. Open the App Store Connect record for bundle ID `com.dalifin.camera`.
2. Create a non-consumable in-app purchase with ID `dali_camera_watermark_lifetime`.
3. Add localization, pricing, review information, and the required review screenshot.
4. Ensure the paid-app agreement, tax, and banking information are active.
5. Attach the purchase to the app version submitted for review.
6. Test with a StoreKit configuration during development and a Sandbox Apple Account or TestFlight before release.
7. Test purchase, app restart while offline, reinstall, and **Restore purchases** with the same Apple account.

## Offline Security Boundary

This implementation intentionally has no Dali server dependency. It trusts successful transactions delivered by StoreKit or Google Play Billing and stores the resulting entitlement locally for offline startup. This is appropriate for a privacy-first client gate, but it is less resistant to a rooted/jailbroken device or modified application than server-side receipt verification.

The lifetime product must never be configured as consumable. Changing the product ID requires updating `StoreWatermarkEntitlement.productId` and creating a matching product in both stores.
