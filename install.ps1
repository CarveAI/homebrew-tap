# carveai-bridge installer — Windows (PowerShell 5.1+).
#
# The Windows counterpart to install.sh (which is POSIX sh, Linux + macOS
# only). Same contract: detect arch, download the matching binary from the
# CarveAI/homebrew-tap release, verify it against the published SHA256SUMS,
# drop it somewhere on PATH, and print the pair + install-service next steps.
#
# NOTE: This is the in-repo reference copy. The published copy users
# actually run lives at https://raw.githubusercontent.com/CarveAI/
# homebrew-tap/main/install.ps1. Keep them in sync — when this file
# changes, also push the same change to CarveAI/homebrew-tap.
#
# Usage (users):
#   irm https://raw.githubusercontent.com/CarveAI/homebrew-tap/main/install.ps1 | iex
#   # pinned version (set the env var first because `| iex` can't take args):
#   $env:VERSION="v0.1.1"; irm https://raw.githubusercontent.com/CarveAI/homebrew-tap/main/install.ps1 | iex
#
# Or download and run directly, which DOES accept parameters:
#   .\install.ps1 -Version v0.1.1 -BinDir "C:\tools\carveai"
#
# What this script does:
#   1. Detect arch (x64; ARM64 hosts use the x64 build under emulation)
#   2. Download the matching binary from CarveAI/homebrew-tap releases
#   3. Verify SHA256 against the published SHA256SUMS
#   4. Install to BinDir (default: %LOCALAPPDATA%\Programs\carveai-bridge) and
#      add it to the user PATH
#   5. Print next steps (pair + install-service)

#Requires -Version 5.1
[CmdletBinding()]
param(
    # Parameters double as env vars so the `irm ... | iex` pipe path (which
    # can't pass args) still configures the same knobs.
    [string]$Version = $(if ($env:VERSION) { $env:VERSION } else { "latest" }),
    [string]$BinDir  = $(if ($env:CARVEAI_BIN_DIR) { $env:CARVEAI_BIN_DIR } else { "" }),
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host "Usage: install.ps1 [-Version vX.Y.Z] [-BinDir PATH]"
    return
}

# TLS 1.2 — Windows PowerShell 5.1 defaults to SSL3/TLS1.0, which GitHub
# rejects. Newer pwsh already negotiates 1.2+, so this is a no-op there.
try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

# --- Detect arch ----------------------------------------------------------

# PROCESSOR_ARCHITEW6432 is set (to the real arch) when a 32-bit shell runs
# on 64-bit Windows; prefer it so WOW64 doesn't fool us into "x86".
$archRaw = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$emulated = $false
switch ($archRaw) {
    "AMD64" { $arch = "amd64" }
    "ARM64" {
        # No native windows-arm64 binary is published yet; the x64 build
        # runs fine under Windows-on-ARM's x64 emulation layer.
        $arch = "amd64"
        $emulated = $true
    }
    default {
        Write-Error "Unsupported architecture: $archRaw (only 64-bit x64 is published)."
        exit 1
    }
}
$asset = "carveai-bridge-windows-$arch.exe"

# --- Pick install dir -----------------------------------------------------

if (-not $BinDir) {
    $BinDir = Join-Path $env:LOCALAPPDATA "Programs\carveai-bridge"
}
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$target = Join-Path $BinDir "carveai-bridge.exe"

# --- Resolve URL ----------------------------------------------------------

# Pointer to the *releases page* (not /download). Path under it differs
# between "latest" (uses /latest/download/<asset>) and a specific tag
# (uses /download/<tag>/<asset>) per GitHub's URL conventions.
$releasesBase = if ($env:CARVEAI_RELEASES_BASE) { $env:CARVEAI_RELEASES_BASE } else { "https://github.com/CarveAI/homebrew-tap/releases" }
if ($Version -eq "latest") {
    $url = "$releasesBase/latest/download/$asset"
} else {
    $url = "$releasesBase/download/$Version/$asset"
}

Write-Host "Installing carveai-bridge"
Write-Host "  os:      windows"
Write-Host "  arch:    $arch$(if ($emulated) { ' (x64 emulation on ARM64 host)' })"
Write-Host "  version: $Version"
Write-Host "  url:     $url"
Write-Host "  target:  $target"
Write-Host ""

# --- Download -------------------------------------------------------------

$tmp = Join-Path $env:TEMP ("carveai-bridge-" + [guid]::NewGuid().ToString("N") + ".exe")
try {
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
} catch {
    Write-Error "Download failed (HTTP). URL: $url`n$($_.Exception.Message)"
    exit 1
}

# Sanity-check the download: an HTML error page (404/503 disguised as 200)
# is the most common failure shape. A real Windows PE starts with "MZ"
# (0x4D 0x5A); an HTML page starts with '<'. Read just the first two bytes.
$fs = [System.IO.File]::OpenRead($tmp)
try {
    $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte()
} finally {
    $fs.Close()
}
if ($b0 -ne 0x4D -or $b1 -ne 0x5A) {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Error "Downloaded file is not a Windows executable (likely an HTML error page). URL: $url"
    exit 1
}

# --- Verify SHA256 against SHA256SUMS -------------------------------------
#
# The release artifact is paired with a SHA256SUMS file generated by
# `make checksums`. We download it, find the line matching our asset,
# compute the local hash, and refuse to install on mismatch. This is the
# integrity check that closes the unsigned-binary MITM concern at $0 cost.
#
# Opt out with CARVEAI_SKIP_VERIFY=1 for local-dev installs where the
# SHA256SUMS file is absent. Don't ship this in user-facing docs.
if ($env:CARVEAI_SKIP_VERIFY -ne "1") {
    $sumsUrl = ($url -replace '/[^/]+$', '/SHA256SUMS')
    $sumsTmp = Join-Path $env:TEMP ("carveai-bridge-sums-" + [guid]::NewGuid().ToString("N") + ".txt")
    try {
        Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsTmp -UseBasicParsing
    } catch {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Error "Could not download checksum file from $sumsUrl`nAborting. Re-run with `$env:CARVEAI_SKIP_VERIFY='1' to skip (only for local-dev installs)."
        exit 1
    }

    # SHA256SUMS lines are "<hex>  <name>" (BSD shasum) or "<hex> *<name>"
    # (coreutils binary mode). Split on whitespace, strip a leading '*'.
    $expected = $null
    foreach ($line in Get-Content $sumsTmp) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -eq 2) {
            $name = $parts[1].TrimStart('*').Trim()
            if ($name -eq $asset) { $expected = $parts[0].Trim(); break }
        }
    }
    Remove-Item $sumsTmp -Force -ErrorAction SilentlyContinue
    if (-not $expected) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Error "No checksum for $asset in SHA256SUMS — aborting."
        exit 1
    }

    $actual = (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash
    if ($expected.ToLower() -ne $actual.ToLower()) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Host "CHECKSUM MISMATCH — refusing to install." -ForegroundColor Red
        Write-Host "  expected: $expected"
        Write-Host "  actual:   $actual"
        Write-Host "  asset:    $asset"
        Write-Host "  url:      $url"
        Write-Error "Someone may be tampering with the download. Do not run this binary."
        exit 1
    }
    Write-Host "OK  Checksum verified ($actual)"
}

# --- Install --------------------------------------------------------------

Move-Item -Force -Path $tmp -Destination $target
# Strip the Mark-of-the-Web (Zone.Identifier ADS) the download attached, so
# Windows SmartScreen doesn't block the unsigned binary on first run. The
# install.sh equivalent is the macOS `xattr -d com.apple.quarantine`.
try { Unblock-File -Path $target -ErrorAction SilentlyContinue } catch { }

# --- PATH + next steps ----------------------------------------------------

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
$onPath = ($userPath -split ';' | ForEach-Object { $_.TrimEnd('\') }) -contains $BinDir.TrimEnd('\')
if (-not $onPath) {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $BinDir), "User")
    # Update the current session too, so the steps below work without a restart.
    $env:Path = $env:Path.TrimEnd(';') + ";" + $BinDir
}

Write-Host ""
Write-Host "OK  Installed carveai-bridge to $target"
Write-Host ""
if (-not $onPath) {
    Write-Host "Added $BinDir to your user PATH. Open a NEW terminal window if"
    Write-Host "``carveai-bridge`` isn't found below (this session is already updated)."
    Write-Host ""
}
Write-Host "Next steps:"
Write-Host "  1. Open the CarveAI webapp (Settings -> Local Files) and click 'Pair this machine'"
Write-Host "  2. Run: carveai-bridge pair    (paste the 8-character code when prompted)"
Write-Host "  3. Run: carveai-bridge install-service    (auto-starts on every login)"
Write-Host "  4. Pick which folders to share in the webapp"
Write-Host ""
Write-Host "For a one-time test without auto-start, just run:"
Write-Host "  carveai-bridge run"
