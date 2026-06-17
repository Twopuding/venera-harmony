# sanitize-build-profile.ps1 - Sanitize/restore build-profile.json5 for safe GitHub push
# Usage:
#   pwsh scripts/sanitize-build-profile.ps1 status
#   pwsh scripts/sanitize-build-profile.ps1 sanitize
#   pwsh scripts/sanitize-build-profile.ps1 restore
#   pwsh scripts/sanitize-build-profile.ps1 verify
#   pwsh scripts/sanitize-build-profile.ps1 cleanup

param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'sanitize', 'restore', 'verify', 'cleanup')]
    [string]$Action = 'status',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildProfile = Join-Path $ProjectRoot 'apps/app_ohos/ohos/build-profile.json5'
$BackupFile = "$BuildProfile.local.bak"
$ChecksumFile = "$BackupFile.sha256"

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Write-Checksum([string]$Path) {
    Get-FileSha256 $Path | Set-Content -Path $ChecksumFile -NoNewline
}

function Test-Checksum([string]$Path) {
    $expected = (Get-Content -Raw $ChecksumFile).Trim()
    $actual = Get-FileSha256 $Path
    if ($expected -ne $actual) {
        throw "checksum mismatch for $Path`n  expected: $expected`n  actual:   $actual"
    }
}

function Test-LooksSanitized([string]$Content) {
    return $Content -match '~/.ohos/config/your_'
}

function Test-LooksRealSigning([string]$Content) {
    return ($Content -match '\\\.ohos\\') -or
           ($Content -match '/\.ohos/') -or
           ($Content -match '"keyPassword"\s*:\s*"[0-9A-F]{32,}"')
}

function Show-Status {
    Write-Host "build-profile: $BuildProfile"
    if (Test-Path $BuildProfile) {
        $content = Get-Content -Raw $BuildProfile
        if (Test-LooksSanitized $content) {
            Write-Host '  state: SANITIZED (placeholders present)'
        }
        elseif (Test-LooksRealSigning $content) {
            Write-Host '  state: REAL (local signing paths/passwords present)'
        }
        else {
            Write-Host '  state: UNKNOWN (review file manually)'
        }
    }
    else {
        Write-Host '  state: MISSING'
    }

    if (Test-Path $BackupFile) {
        Write-Host "  backup: present ($BackupFile)"
        if (Test-Path $ChecksumFile) {
            Write-Host "  backup checksum: $((Get-Content -Raw $ChecksumFile).Trim())"
        }
        else {
            Write-Host '  backup checksum: missing (run verify or re-sanitize with -Force)'
        }
    }
    else {
        Write-Host '  backup: none'
    }
}

function Invoke-Sanitize {
    if (-not (Test-Path $BuildProfile)) {
        throw "[sanitize] ERROR: $BuildProfile not found"
    }

    $content = Get-Content -Raw $BuildProfile

    if ((Test-Path $BackupFile) -and -not $Force) {
        throw "[sanitize] ERROR: backup already exists. Run restore first, or sanitize -Force."
    }

    if ((Test-LooksSanitized $content) -and -not $Force) {
        throw "[sanitize] ERROR: file already looks sanitized. Run restore first."
    }

    $tmpBackup = "$BackupFile.tmp"
    Copy-Item -Path $BuildProfile -Destination $tmpBackup -Force
    Write-Checksum $tmpBackup
    Move-Item -Path $tmpBackup -Destination $BackupFile -Force
    Write-Host "[sanitize] Backup created: $BackupFile"

    $content = $content -replace '"certpath"\s*:\s*"[^"]*"', '"certpath": "~/.ohos/config/your_cert.cer"'
    $content = $content -replace '"keyAlias"\s*:\s*"[^"]*"', '"keyAlias": "your_key_alias"'
    $content = $content -replace '"keyPassword"\s*:\s*"[^"]*"', '"keyPassword": ""'
    $content = $content -replace '"profile"\s*:\s*"[^"]*"', '"profile": "~/.ohos/config/your_profile.p7b"'
    $content = $content -replace '"storeFile"\s*:\s*"[^"]*"', '"storeFile": "~/.ohos/config/your_store.p12"'
    $content = $content -replace '"storePassword"\s*:\s*"[^"]*"', '"storePassword": ""'

    if (-not (Test-LooksSanitized $content)) {
        Copy-Item -Path $BackupFile -Destination $BuildProfile -Force
        throw '[sanitize] ERROR: sanitization failed; restored from backup'
    }

    Set-Content -Path $BuildProfile -Value $content -NoNewline
    Write-Host '[sanitize] Done - sensitive fields replaced with placeholders'
}

function Invoke-Restore {
    if (-not (Test-Path $BackupFile)) {
        throw "[restore] ERROR: no backup at $BackupFile"
    }

    if (Test-Path $ChecksumFile) {
        Test-Checksum $BackupFile
    }
    else {
        Write-Warning '[restore] checksum file missing; proceeding without verification'
    }

    $backupContent = Get-Content -Raw $BackupFile
    if (Test-LooksSanitized $backupContent) {
        throw '[restore] ERROR: backup contains sanitized placeholders. Refusing to restore — would overwrite local credentials.'
    }

    $tmpRestore = "$BuildProfile.restore.tmp"
    Copy-Item -Path $BackupFile -Destination $tmpRestore -Force

    if ($backupContent -notmatch '"certpath"|"storeFile"|"profile"') {
        Remove-Item -Path $tmpRestore -Force -ErrorAction SilentlyContinue
        throw '[restore] ERROR: backup does not look like a valid build-profile'
    }

    Move-Item -Path $tmpRestore -Destination $BuildProfile -Force

    if (Test-Path $ChecksumFile) {
        Test-Checksum $BuildProfile
    }

    Write-Host "[restore] Restored from backup (backup kept at $BackupFile)"
    Write-Host "[restore] Run verify, then cleanup to remove backup files"
}

function Invoke-Verify {
    if (-not (Test-Path $BuildProfile)) {
        throw "[verify] ERROR: $BuildProfile not found"
    }

    $content = Get-Content -Raw $BuildProfile
    if (Test-LooksSanitized $content) {
        throw '[verify] FAIL: file is still sanitized'
    }

    if (-not (Test-LooksRealSigning $content)) {
        throw '[verify] WARN: signing fields look unusual; review manually'
    }

    if ((Test-Path $BackupFile) -and (Test-Path $ChecksumFile)) {
        Test-Checksum $BuildProfile
        Test-Checksum $BackupFile
        Write-Host '[verify] OK: restored file matches backup checksum'
    }
    else {
        Write-Host '[verify] OK: file contains real signing config (no checksum to compare)'
    }
}

function Invoke-Cleanup {
    if (-not (Test-Path $BackupFile)) {
        Write-Host '[cleanup] No backup to remove'
        return
    }

    $content = Get-Content -Raw $BuildProfile
    if (Test-LooksSanitized $content) {
        throw '[cleanup] ERROR: file is still sanitized; run restore first'
    }

    if (Test-Path $ChecksumFile) {
        Test-Checksum $BuildProfile
    }

    Remove-Item -Path $BackupFile, $ChecksumFile -Force -ErrorAction SilentlyContinue
    Write-Host '[cleanup] Backup removed'
}

switch ($Action) {
    'status' { Show-Status }
    'sanitize' { Invoke-Sanitize }
    'restore' { Invoke-Restore }
    'verify' { Invoke-Verify }
    'cleanup' { Invoke-Cleanup }
}
