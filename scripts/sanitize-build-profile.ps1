# sanitize-build-profile.ps1 - Local signing export + sanitize/restore for GitHub push
# Usage:
#   pwsh scripts/sanitize-build-profile.ps1 status
#   pwsh scripts/sanitize-build-profile.ps1 save-local
#   pwsh scripts/sanitize-build-profile.ps1 sanitize
#   pwsh scripts/sanitize-build-profile.ps1 restore
#   pwsh scripts/sanitize-build-profile.ps1 verify
#   pwsh scripts/sanitize-build-profile.ps1 cleanup

param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'save-local', 'sanitize', 'restore', 'verify', 'cleanup')]
    [string]$Action = 'status',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildProfile = Join-Path $ProjectRoot 'apps/app_ohos/ohos/build-profile.json5'
$LocalFile = "$BuildProfile.local"
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

function Test-LooksEmptySigning([string]$Content) {
    return $Content -match '"signingConfigs"\s*:\s*\[\s*\]'
}

function Show-Status {
    Write-Host "build-profile: $BuildProfile"
    if (Test-Path $BuildProfile) {
        $content = Get-Content -Raw $BuildProfile
        if (Test-LooksEmptySigning $content) {
            Write-Host '  state: EXTERNAL (signingConfigs empty; expect .local inject)'
        }
        elseif (Test-LooksSanitized $content) {
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

    if (Test-Path $LocalFile) {
        $localContent = Get-Content -Raw $LocalFile
        if (Test-LooksRealSigning $localContent) {
            Write-Host "  local: present REAL ($LocalFile)"
        }
        else {
            Write-Host "  local: present but signing looks unusual ($LocalFile)"
        }
    }
    else {
        Write-Host '  local: none (run save-local after configuring DevEco signing)'
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

function Invoke-SaveLocal {
    if ((Test-Path $LocalFile) -and -not $Force) {
        throw "[save-local] ERROR: $LocalFile already exists. Use -Force to overwrite."
    }

    $forceArg = if ($Force) { '--force' } else { '' }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $python) {
        throw '[save-local] ERROR: python/python3 required to write pretty JSON (same as .sh script)'
    }

    $pyFile = Join-Path $env:TEMP "venera-save-local-signing.py"
    $pyCode = @'
import json, re, sys
profile_path, local_path, force = sys.argv[1], sys.argv[2], sys.argv[3]
with open(profile_path, encoding="utf-8") as f:
    profile = json.load(f)
configs = profile.get("app", {}).get("signingConfigs") or []
if not configs:
    print("[save-local] ERROR: signingConfigs is empty; configure signing in DevEco first", file=sys.stderr)
    sys.exit(1)
blob = json.dumps(configs)
looks_real = bool(
    re.search(r"\\.ohos\\", blob)
    or re.search(r"/\.ohos/", blob)
    or re.search(r'"keyPassword"\s*:\s*"[0-9A-F]{32,}"', blob)
)
if not looks_real and force != "--force":
    print("[save-local] ERROR: signingConfigs do not look like real local credentials. Use -Force.", file=sys.stderr)
    sys.exit(1)
with open(local_path, "w", encoding="utf-8", newline="\n") as f:
    json.dump({"signingConfigs": configs}, f, indent=2, ensure_ascii=False)
    f.write("\n")
profile["app"]["signingConfigs"] = []
with open(profile_path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"[save-local] Wrote {local_path}")
print("[save-local] Cleared signingConfigs in tracked build-profile.json5")
print("[save-local] Build injects signing from .local via hvigorfile.ts")
'@
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($pyFile, $pyCode, $utf8NoBom)

    try {
        & $python.Source $pyFile $BuildProfile $LocalFile $forceArg
        if ($LASTEXITCODE -ne 0) {
            throw "[save-local] ERROR: python exited with code $LASTEXITCODE"
        }
    }
    finally {
        Remove-Item -Path $pyFile -Force -ErrorAction SilentlyContinue
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

    if ((Test-LooksEmptySigning $content) -and -not $Force) {
        Write-Host '[sanitize] Tracked file already has empty signingConfigs; nothing to sanitize'
        return
    }

    if ((Test-LooksSanitized $content) -and -not $Force) {
        throw "[sanitize] ERROR: file already looks sanitized. Run restore first."
    }

    # Prefer persisting REAL signing to .local before stripping tracked file
    if ((Test-LooksRealSigning $content) -and (-not (Test-Path $LocalFile) -or $Force)) {
        Write-Host '[sanitize] Ensuring .local exists before sanitize...'
        Invoke-SaveLocal
        return
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
    if (Test-Path $BackupFile) {
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
        return
    }

    if (Test-Path $LocalFile) {
        Write-Host '[restore] No .local.bak; tracked file stays EXTERNAL — signing comes from .local at build time'
        Write-Host "[restore] local present: $LocalFile"
        return
    }

    throw "[restore] ERROR: no backup at $BackupFile and no $LocalFile"
}

function Invoke-Verify {
    if (-not (Test-Path $BuildProfile)) {
        throw "[verify] ERROR: $BuildProfile not found"
    }

    $content = Get-Content -Raw $BuildProfile

    # Preferred setup: empty tracked signing + REAL .local
    if ((Test-LooksEmptySigning $content) -and (Test-Path $LocalFile)) {
        $localContent = Get-Content -Raw $LocalFile
        if (-not (Test-LooksRealSigning $localContent)) {
            throw '[verify] FAIL: .local exists but signing fields look unusual'
        }
        Write-Host '[verify] OK: EXTERNAL tracked profile + REAL .local'
        return
    }

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
        # Only checksum-compare when tracked file was restored from bak (REAL in tracked file)
        if (-not (Test-LooksEmptySigning $content)) {
            Test-Checksum $BuildProfile
        }
    }

    Remove-Item -Path $BackupFile, $ChecksumFile -Force -ErrorAction SilentlyContinue
    Write-Host '[cleanup] Backup removed (.local kept if present)'
}

switch ($Action) {
    'status' { Show-Status }
    'save-local' { Invoke-SaveLocal }
    'sanitize' { Invoke-Sanitize }
    'restore' { Invoke-Restore }
    'verify' { Invoke-Verify }
    'cleanup' { Invoke-Cleanup }
}
