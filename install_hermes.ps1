#requires -Version 5
<#
  Hardened Hermes Agent installer for Windows.

  WHY THIS EXISTS:
  The official one-line installer reliably aborts on Windows at the final
  "pin to tag" step with:
      error: Your local changes to the following files would be overwritten by checkout
  ...because a CRLF/LF line-ending smudge marks hundreds of upstream docs as
  "modified", so `git checkout <tag>` refuses to run. This script runs the
  official installer, then auto-recovers from that exact failure (force-checkout
  the clean tag + finish the venv/dependency/PATH stages with the bundled uv
  against the committed lockfile).

  RUN THIS FROM YOUR OWN PowerShell (NOT inside Claude Code), so it installs
  into your real %LOCALAPPDATA%\hermes and onto your real user PATH.

  Pinned release: v2026.6.19 (= Hermes Agent v0.17.0). No WSL. No hand-clone.
#>
[CmdletBinding()]
param(
    [string]$Tag = 'v2026.6.19'
)
$ErrorActionPreference = 'Continue'
$ProgressPreference   = 'SilentlyContinue'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Hermes Agent hardened installer  -  pinning tag $Tag" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# --- 1) Official installer, pinned to the tag, wizard skipped -------------
Write-Host "`n[1/3] Running official installer (-Tag $Tag -SkipSetup)..." -ForegroundColor White
try {
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1))) -Tag $Tag -SkipSetup
} catch {
    Write-Host "  Official installer reported: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

$InstallDir = "$env:LOCALAPPDATA\hermes\hermes-agent"
$Uv         = "$env:LOCALAPPDATA\hermes\bin\uv.exe"
$Hexe       = "$InstallDir\venv\Scripts\hermes.exe"

# --- 2) Recover if the tag checkout / dependency stages didn't finish -----
if (-not (Test-Path $Hexe)) {
    Write-Host "`n[2/3] Completing install (recovering from the CRLF checkout bug)..." -ForegroundColor Yellow

    if (Test-Path "$InstallDir\.git") {
        # Discard the line-ending smudge and land cleanly on the pinned tag.
        & git -C $InstallDir checkout -f $Tag
        if ($LASTEXITCODE -ne 0) {
            & git -C $InstallDir fetch --tags origin
            & git -C $InstallDir checkout -f $Tag
        }
        $head = (& git -C $InstallDir describe --tags --exact-match 2>$null)
        Write-Host "  Pinned at: $head" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: repo not found at $InstallDir. The clone stage failed; re-run this script." -ForegroundColor Red
        return
    }

    Push-Location $InstallDir
    if (-not (Test-Path "$InstallDir\venv\Scripts\python.exe")) {
        & $Uv venv venv --python 3.11
    }
    $env:UV_PROJECT_ENVIRONMENT = "$InstallDir\venv"
    $env:VIRTUAL_ENV            = "$InstallDir\venv"
    $env:UV_PYTHON              = "$InstallDir\venv\Scripts\python.exe"

    & $Uv sync --extra all --locked
    if ($LASTEXITCODE -ne 0) { Write-Host "  '--extra all' failed; falling back to base deps." -ForegroundColor DarkYellow; & $Uv sync --locked }
    Pop-Location

    # Ensure the venv Scripts dir (where hermes.exe lives) is on the USER PATH.
    $bin = "$InstallDir\venv\Scripts"
    $up  = [Environment]::GetEnvironmentVariable('Path','User')
    if (($up -split ';') -notcontains $bin) {
        $new = if ([string]::IsNullOrEmpty($up)) { $bin } else { $up.TrimEnd(';') + ';' + $bin }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Write-Host "  Added to user PATH: $bin" -ForegroundColor Gray
    }
} else {
    Write-Host "`n[2/3] Official installer completed cleanly (no recovery needed)." -ForegroundColor Green
}

# --- 3) Verify ------------------------------------------------------------
Write-Host "`n[3/3] Verifying..." -ForegroundColor White
if (Test-Path $Hexe) {
    & $Hexe --version
    Write-Host "`nSUCCESS. Hermes installed at: $InstallDir" -ForegroundColor Green
    Write-Host "Open a NEW PowerShell window and confirm:  hermes --version" -ForegroundColor Green
    Write-Host "Then run the first-time setup:             hermes setup" -ForegroundColor Green
} else {
    Write-Host "Install did not complete - hermes.exe missing at $Hexe" -ForegroundColor Red
    Write-Host "Copy the output above and send it back for diagnosis." -ForegroundColor Red
}
