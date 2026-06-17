# Build a slim release HAP for HarmonyOS.
# Requires Flutter ohos SDK (3.22.4-ohos-1.1.4-beta or compatible).
$ErrorActionPreference = 'Stop'
$AppDir = (Join-Path (Join-Path (Join-Path $PSScriptRoot '..') 'apps') 'app_ohos') | Resolve-Path
$FvmLink = 'C:\Users\Twopudding\fvm\versions\0.0.0-unknown'
$FvmTarget = if (Test-Path $FvmLink) { (Get-Item $FvmLink).Target } else { $null }
$FlutterBat = @(
    $env:FLUTTER_ROOT,
    'D:\Project\flutter_ohos_sdk\flutter',
    $FvmTarget
) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\flutter.bat')) } | Select-Object -First 1

if (-not $FlutterBat) {
    throw 'Flutter ohos SDK not found. Set FLUTTER_ROOT or install to D:\Project\flutter_ohos_sdk\flutter.'
}

$FlutterExe = Join-Path $FlutterBat 'bin\flutter.bat'
Push-Location $AppDir
try {
    & $FlutterExe build hap --release `
        --tree-shake-icons `
        --obfuscate `
        --split-debug-info=build/symbols

    $HapPath = Join-Path $AppDir 'build\ohos\hap\entry-default-signed.hap'
    if (Test-Path $HapPath) {
        $SizeMb = [math]::Round((Get-Item $HapPath).Length / 1MB, 2)
        Write-Host "Release HAP: $HapPath ($SizeMb MB)"
    }
}
finally {
    Pop-Location
}
