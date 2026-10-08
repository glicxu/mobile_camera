param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [string]$Flutter = 'flutter',
    [string]$Adb = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
)
$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $PSScriptRoot '../apps/dali_camera'
Push-Location -LiteralPath $appDirectory
try {
    & $Flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
    & $Adb -s $DeviceId install -r build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0) { throw 'Install failed' }
    & $Adb -s $DeviceId shell pm grant com.dalicamera.dali_camera android.permission.CAMERA
    if ($LASTEXITCODE -ne 0) { throw 'Camera test permission setup failed' }
    & $Flutter test integration_test/phone_test.dart -d $DeviceId
    if ($LASTEXITCODE -ne 0) { throw 'Phone integration test failed' }
    & $Flutter test integration_test/bridge_test.dart -d $DeviceId
    if ($LASTEXITCODE -ne 0) { throw 'Native bridge integration test failed' }
    & $Flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Normal APK rebuild failed' }
    & $Adb -s $DeviceId install -r build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0) { throw 'Normal app reinstall failed' }
    Write-Output 'Tests passed; the normal Dali Camera app is installed for manual testing.'
} finally { Pop-Location }
