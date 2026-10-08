# Dali Camera agent notes

## Installing on Alayna's iPhone

Do not rely on automatic signing for this phone. Automatic signing may select the generic `iOS Team Provisioning Profile: com.dalifin.camera`, which currently excludes Alayna's device and causes installation error `0xe8008012` (the provisioning profile cannot be installed on this device).

Known device and signing values:

- Device: `Alayna's iPhone` (iPhone 13 Pro)
- Device UDID: `00008110-000909522246801E`
- Bundle identifier: `com.dalifin.camera`
- Development team: `33W2562W9S`
- Signing identity: `Apple Development: GANG LI (S3SPY2JQ5R)`
- Provisioning profile name: `Dali Camera Alayna Dev 20261004`
- Provisioning profile UUID: `93e00eb1-b0c0-4a9f-a455-b77c83cec3a5`
- Cached profile: `~/Library/Developer/Xcode/UserData/Provisioning Profiles/93e00eb1-b0c0-4a9f-a455-b77c83cec3a5.mobileprovision`
- Profile expiration: October 4, 2027

First confirm that the intended phone is available:

```sh
xcrun devicectl list devices
```

Build with manual signing and explicitly pin the Alayna profile:

```sh
xcodebuild \
  -project DaliCamera.xcodeproj \
  -scheme DaliCamera \
  -configuration Debug \
  -destination 'id=00008110-000909522246801E' \
  -derivedDataPath /tmp/dali-camera-alayna-profile-build \
  DEVELOPMENT_TEAM=33W2562W9S \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Development' \
  PROVISIONING_PROFILE_SPECIFIER='Dali Camera Alayna Dev 20261004' \
  PROVISIONING_PROFILE=93e00eb1-b0c0-4a9f-a455-b77c83cec3a5 \
  build
```

Install and verify:

```sh
xcrun devicectl device install app \
  --device 00008110-000909522246801E \
  /tmp/dali-camera-alayna-profile-build/Build/Products/Debug-iphoneos/DaliCamera.app

xcrun devicectl device info apps \
  --device 00008110-000909522246801E \
  --bundle-id com.dalifin.camera
```

If the profile is missing or expired, do not switch silently to another device or profile. Report that the dedicated Alayna profile must be restored or regenerated.
