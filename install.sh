#!/usr/bin/env sh
# carveai-bridge installer — Linux + macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/CarveAI/homebrew-tap/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/CarveAI/homebrew-tap/main/install.sh | sh -s -- --version=v0.1.1
#   curl -fsSL https://raw.githubusercontent.com/CarveAI/homebrew-tap/main/install.sh | sh -s -- --bin-dir=/usr/local/bin
#
# Mac users can use Homebrew instead:
#   brew install CarveAI/tap/bridge
#
# What this script does:
#   1. Detect OS + arch
#   2. Download the matching binary from this repo's releases
#   3. Verify SHA256 against the published SHA256SUMS
#   4. Install to BIN_DIR (default: ~/.local/bin, falling back to /usr/local/bin)
#   5. Print next steps (pair + install-service)
#
# The script is intentionally POSIX `sh` (not bash) so it runs on the
# minimal Alpine / busybox-based containers as well as fully-loaded
# desktops.

set -eu

VERSION="${VERSION:-latest}"
# Pointer to the *releases page* (not /download). Path under it differs
# between "latest" (uses /latest/download/<asset>) and a specific tag
# (uses /download/<tag>/<asset>) per GitHub's URL conventions.
RELEASES_BASE="${CARVEAI_RELEASES_BASE:-https://github.com/CarveAI/homebrew-tap/releases}"
# Legacy override: CARVEAI_RELEASE_BASE pointed at /releases/download/
# in pre-v0.1.4 installers; keep accepting it if someone sets it
# explicitly in CI/dev. Strip a trailing /download segment so the rest
# of the script's URL templating works the new way.
if [ -n "${CARVEAI_RELEASE_BASE:-}" ]; then
    RELEASES_BASE="${CARVEAI_RELEASE_BASE%/download}"
fi
BIN_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --version=*) VERSION="${1#*=}" ;;
        --bin-dir=*) BIN_DIR="${1#*=}" ;;
        --version) shift; VERSION="$1" ;;
        --bin-dir) shift; BIN_DIR="$1" ;;
        -h|--help)
            printf 'Usage: install.sh [--version=vX.Y.Z] [--bin-dir=PATH]\n'
            exit 0
            ;;
        *)
            printf 'unknown flag: %s\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

# --- Detect OS + arch -----------------------------------------------------

uname_s=$(uname -s 2>/dev/null || echo unknown)
uname_m=$(uname -m 2>/dev/null || echo unknown)

case "$uname_s" in
    Darwin) os="darwin" ;;
    Linux)  os="linux"  ;;
    *)
        printf 'Unsupported OS: %s\n' "$uname_s" >&2
        exit 1
        ;;
esac

case "$uname_m" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
        printf 'Unsupported architecture: %s\n' "$uname_m" >&2
        exit 1
        ;;
esac

asset="carveai-bridge-${os}-${arch}"

# --- Pick install dir -----------------------------------------------------

if [ -z "$BIN_DIR" ]; then
    # Prefer ~/.local/bin (no sudo), fall back to /usr/local/bin.
    if [ -w "${HOME}/.local/bin" ] || mkdir -p "${HOME}/.local/bin" 2>/dev/null; then
        BIN_DIR="${HOME}/.local/bin"
    elif [ -w /usr/local/bin ]; then
        BIN_DIR=/usr/local/bin
    else
        printf 'Neither ~/.local/bin nor /usr/local/bin is writable.\n' >&2
        printf 'Try: install.sh --bin-dir=/path/you/can/write\n' >&2
        exit 1
    fi
fi
mkdir -p "$BIN_DIR"

# --- Resolve URL ----------------------------------------------------------

if [ "$VERSION" = "latest" ]; then
    # GitHub's "latest release" alias has the version segment BEFORE
    # the /download/ path: .../releases/latest/download/<asset>.
    # NOT .../releases/download/latest/... — that 404s (no release is
    # literally tagged 'latest').
    url="${RELEASES_BASE}/latest/download/${asset}"
else
    # Specific tag: .../releases/download/<tag>/<asset>.
    url="${RELEASES_BASE}/download/${VERSION}/${asset}"
fi

printf 'Installing carveai-bridge\n'
printf '  os:      %s\n' "$os"
printf '  arch:    %s\n' "$arch"
printf '  version: %s\n' "$VERSION"
printf '  url:     %s\n' "$url"
printf '  target:  %s/carveai-bridge\n' "$BIN_DIR"
printf '\n'

# --- Download -------------------------------------------------------------

tmp=$(mktemp -t carveai-bridge.XXXXXX)
# `trap … 0` (EXIT) is more portable than `EXIT` literal in busybox sh.
trap 'rm -f "$tmp"' 0 INT TERM HUP

if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$url" -o "$tmp"; then
        printf 'Download failed (HTTP). URL: %s\n' "$url" >&2
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -q "$url" -O "$tmp"; then
        printf 'Download failed (HTTP). URL: %s\n' "$url" >&2
        exit 1
    fi
else
    printf 'Need curl or wget to download.\n' >&2
    exit 1
fi

# Sanity-check the download: an HTML error page is the most common
# failure shape (404 / 503 disguised as 200). Reject anything that
# starts with `<` since a real Mach-O / ELF starts with non-printable
# magic bytes.
firstchar=$(dd if="$tmp" bs=1 count=1 2>/dev/null | tr -d '\0' || true)
if [ "$firstchar" = "<" ]; then
    printf 'Downloaded an HTML page, not a binary. URL: %s\n' "$url" >&2
    printf 'Check that the release exists at that URL.\n' >&2
    exit 1
fi

# --- Verify SHA256 against SHA256SUMS -------------------------------------
#
# The release artifact is paired with a SHA256SUMS file generated by
# `make checksums` in the bridge repo. We download it, find the line
# matching our asset, compute the local hash, and refuse to install on
# mismatch. This is the integrity check that closes the unsigned-binary
# MITM concern at $0 cost.
#
# Allow opt-out via CARVEAI_SKIP_VERIFY=1 — useful for testing against
# a self-hosted release where the SHA256SUMS file is absent. Don't ship
# this env var in user-facing docs.
if [ "${CARVEAI_SKIP_VERIFY:-0}" != "1" ]; then
    sums_url="${url%/*}/SHA256SUMS"
    sums=$(mktemp -t carveai-bridge-sums.XXXXXX)
    trap 'rm -f "$tmp" "$sums"' 0 INT TERM HUP

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$sums_url" -o "$sums" || sums_failed=1
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$sums_url" -O "$sums" || sums_failed=1
    fi

    if [ "${sums_failed:-0}" = "1" ]; then
        printf 'Could not download checksum file from %s\n' "$sums_url" >&2
        printf 'Aborting. Re-run with CARVEAI_SKIP_VERIFY=1 to skip (only for local-dev installs).\n' >&2
        exit 1
    fi

    # Pull the expected hash for our specific asset (first column of the
    # line whose second column matches our filename).
    expected=$(awk -v name="$asset" '$2==name || $2=="*"name {print $1; exit}' "$sums")
    if [ -z "$expected" ]; then
        printf 'No checksum for %s in SHA256SUMS — aborting.\n' "$asset" >&2
        exit 1
    fi

    # Compute the local hash. macOS ships `shasum`, Linux ships
    # `sha256sum`; both print `<hex>  <filename>` so we cut on whitespace.
    if command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$tmp" | awk '{print $1}')
    elif command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$tmp" | awk '{print $1}')
    else
        printf 'No sha256 tool available — aborting.\n' >&2
        printf 'Install `shasum` (macOS) or `sha256sum` (Linux) and re-run.\n' >&2
        exit 1
    fi

    if [ "$expected" != "$actual" ]; then
        printf 'CHECKSUM MISMATCH — refusing to install.\n' >&2
        printf '  expected: %s\n' "$expected" >&2
        printf '  actual:   %s\n' "$actual" >&2
        printf '  asset:    %s\n' "$asset" >&2
        printf '  url:      %s\n' "$url" >&2
        printf 'Someone may be tampering with the download. Do not run this binary.\n' >&2
        exit 1
    fi
    printf '✓ Checksum verified (%s)\n' "$actual"
    rm -f "$sums"
fi

# --- Install --------------------------------------------------------------

install -m 0755 "$tmp" "${BIN_DIR}/carveai-bridge"
rm -f "$tmp"
trap - 0 INT TERM HUP

# On macOS, strip the quarantine attribute so the binary runs without
# `xattr -d`. Curl-downloaded files don't normally get quarantined,
# but install.sh might be piped from a webview / pkg that does.
if [ "$os" = "darwin" ] && command -v xattr >/dev/null 2>&1; then
    xattr -d com.apple.quarantine "${BIN_DIR}/carveai-bridge" 2>/dev/null || true
fi

# --- Path hint + next steps ----------------------------------------------

case ":${PATH}:" in
    *":${BIN_DIR}:"*) in_path=1 ;;
    *) in_path=0 ;;
esac

printf '✓ Installed carveai-bridge to %s/carveai-bridge\n\n' "$BIN_DIR"

if [ "$in_path" = 0 ]; then
    printf 'Add this to your shell rc so the command is on PATH:\n'
    printf '  export PATH="%s:$PATH"\n\n' "$BIN_DIR"
fi

printf 'Next steps:\n'
printf '  1. Open the CarveAI webapp (Settings → Local Files) and click "Pair this machine"\n'
printf '  2. Run: carveai-bridge pair    (paste the 8-character code when prompted)\n'
printf '  3. Run: carveai-bridge install-service    (auto-starts on every login)\n'
printf '  4. Pick which folders to share in the webapp\n\n'

printf 'For a one-time test without auto-start, just run:\n'
printf '  carveai-bridge run\n'
