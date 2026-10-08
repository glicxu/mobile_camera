param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [string]$Flutter = 'flutter',
    [string]$Adb = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe",
    [ValidateRange(0, 3600)][int]$SoakSeconds = 0,
    [ValidateSet('camera', 'bridge')][string[]]$Checks = @('camera', 'bridge')
)
$ErrorActionPreference = 'Stop'
$appDirectory = Join-Path $PSScriptRoot '../apps/dali_camera'
$priorTestProperty = $env:DALI_ANDROID_TEST_APP
$testPackage = 'com.dalicamera.dali_camera.test'
Push-Location -LiteralPath $appDirectory
try {
    # Flutter runner installs/uninstalls use a separate, disposable app ID.
    $env:DALI_ANDROID_TEST_APP = 'true'
    & $Flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Isolated test APK build failed' }
    $sdkRoot = Split-Path (Split-Path $Adb)
    $aapt = Join-Path $sdkRoot 'build-tools/36.0.0/aapt.exe'
    if (-not (Test-Path -LiteralPath $aapt)) { throw 'aapt 36.0.0 is required to verify test APK identity' }
    $apkIdentity = & $aapt dump badging build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0 -or -not (($apkIdentity -join "`n").Contains("name='$testPackage'"))) {
        throw 'Test APK is not isolated. Refusing to invoke the Flutter installer.'
    }
    & $Adb -s $DeviceId install -r build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0) { throw 'Isolated test app install failed' }
    foreach ($check in $Checks) {
        $testTarget = if ($check -eq 'camera') { 'integration_test/phone_test.dart' } else { 'integration_test/bridge_test.dart' }
        $permissionJob = Start-Job -ArgumentList $Adb, $DeviceId, $testPackage -ScriptBlock {
            param($adbPath, $serial, $packageId)
            for ($attempt = 0; $attempt -lt 600; $attempt++) {
                $appPid = & $adbPath -s $serial shell pidof $packageId 2>$null
                if ($appPid) {
                    & $adbPath -s $serial shell pm grant $packageId android.permission.CAMERA 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) { break }
                }
                Start-Sleep -Milliseconds 500
            }
        }
        try {
            & $Flutter test $testTarget -d $DeviceId "--dart-define=DALI_SOAK_SECONDS=$SoakSeconds"
            if ($LASTEXITCODE -ne 0) { throw "Integration test failed: $testTarget" }
        } finally {
            Stop-Job -Job $permissionJob
            Remove-Job -Job $permissionJob -Force
        }
    }
    [Environment]::SetEnvironmentVariable('DALI_ANDROID_TEST_APP', $null, 'Process')
    & $Flutter build apk --debug --split-per-abi
    if ($LASTEXITCODE -ne 0) { throw 'Normal APK rebuild failed' }
    $abi = (& $Adb -s $DeviceId shell getprop ro.product.cpu.abi).Trim()
    if ($LASTEXITCODE -ne 0 -or $abi -notin @('arm64-v8a', 'armeabi-v7a', 'x86_64')) { throw 'Unsupported device ABI' }
    # adb -r fails safely on a downgrade; never fall back to uninstall.
    & $Adb -s $DeviceId install -r "build/app/outputs/flutter-apk/app-$abi-debug.apk"
    if ($LASTEXITCODE -ne 0) { throw 'Normal app update failed; existing app was retained' }
    Write-Output 'Tests passed in the isolated test app; normal Dali Camera is installed for manual testing.'
} finally {
    [Environment]::SetEnvironmentVariable('DALI_ANDROID_TEST_APP', $priorTestProperty, 'Process')
    Pop-Location
}
