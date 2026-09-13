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

# ---- Externalized signing support -----------------------------------------
# flutter_tools refuses to build when the tracked build-profile.json5 has an
# empty signingConfigs (the raw file is checked before hvigor's .local inject).
# So for the duration of the build we merge the gitignored
# build-profile.json5.local signing into the tracked file, then restore it.
$BuildProfile = Join-Path $AppDir 'ohos\build-profile.json5'
$LocalProfile = "$BuildProfile.local"
$PreBuildProfile = "$BuildProfile.pre-build"

function Merge-LocalSigning {
    if (-not (Test-Path $LocalProfile)) {
        Write-Host '[build] No build-profile.json5.local; assuming signing is inline'
        return
    }
    $content = Get-Content -Raw $BuildProfile
    $obj = $content | ConvertFrom-Json
    $signing = @($obj.app.signingConfigs)
    if ($signing.Count -gt 0) {
        Write-Host '[build] build-profile.json5 already has signing configs'
        return
    }
    $localObj = Get-Content -Raw $LocalProfile | ConvertFrom-Json
    $localSigning = @($localObj.signingConfigs)
    if ($localSigning.Count -eq 0) {
        Write-Host '[build] .local has no signingConfigs; skipping inject'
        return
    }
    Set-Content -Path $PreBuildProfile -Value $content -NoNewline
    $obj.app.signingConfigs = $localSigning
    ($obj | ConvertTo-Json -Depth 12) | Set-Content -Path $BuildProfile -Encoding UTF8
    Write-Host '[build] Merged .local signing into build-profile.json5 for this build'
}

function Restore-TrackedProfile {
    if (Test-Path $PreBuildProfile) {
        Copy-Item -Path $PreBuildProfile -Destination $BuildProfile -Force
        Remove-Item -Path $PreBuildProfile -Force
        Write-Host '[build] Restored tracked build-profile.json5 (signing externalized)'
    }
}

$FlutterExe = Join-Path $FlutterBat 'bin\flutter.bat'
Push-Location $AppDir
Merge-LocalSigning
try {
    & $FlutterExe build hap --release --tree-shake-icons --obfuscate --split-debug-info=build/symbols

    $HapPath = Join-Path $AppDir 'build\ohos\hap\entry-default-signed.hap'
    if (Test-Path $HapPath) {
        $SizeMb = [math]::Round((Get-Item $HapPath).Length / 1MB, 2)
        Write-Host "Release HAP: $HapPath ($SizeMb MB)"
    }
}
finally {
    Restore-TrackedProfile
    Pop-Location
}
