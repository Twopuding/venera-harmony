# Fetch HarmonyOS flutter_inappwebview (skip broken LFS example assets).
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Dest = Join-Path $RepoRoot 'plugins\flutter_inappwebview_repo'
$env:GIT_LFS_SKIP_SMUDGE = '1'

if (Test-Path (Join-Path $Dest 'flutter_inappwebview\pubspec.yaml')) {
    Write-Host "Already present: $Dest"
    exit 0
}

if (Test-Path $Dest) {
    Remove-Item -Recurse -Force $Dest
}

git clone --depth 1 --branch br_v6.1.5_ohos `
    https://gitcode.com/openharmony-sig/flutter_inappwebview.git `
    $Dest

Write-Host "Cloned to $Dest"
