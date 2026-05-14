# CarveAI Homebrew tap

Public Homebrew tap for **`carveai-bridge`** — the desktop daemon that
gives your CarveAI agent (running in the cloud at <https://app.carveaiagent.com>)
secure, scoped read/write access to files on your own computer.

The agent never touches your disk directly. The bridge runs on your
machine, holds a single outbound WebSocket to CarveAI's gateway, and
enforces a folder allowlist/denylist that you configure in the webapp.
Sensitive paths (`~/.ssh`, `~/.aws`, `.env*`, `*.pem`, etc.) are
**always** refused regardless of your settings.

The bridge source lives in the private `CarveAI/carveai-core` repo;
compiled binaries for all supported platforms are mirrored to this
repo's [Releases](https://github.com/CarveAI/homebrew-tap/releases) on
every version cut.

## Install

### macOS

```sh
brew install CarveAI/tap/bridge
```

### Linux

```sh
curl -fsSL https://raw.githubusercontent.com/CarveAI/homebrew-tap/main/install.sh | sh
```

The Linux installer downloads from the same Releases page Homebrew uses,
verifies the SHA256 against the published `SHA256SUMS`, and drops the
binary in `~/.local/bin/` (no sudo). Pass `--bin-dir=/some/path` to
install elsewhere, or set `CARVEAI_SKIP_VERIFY=1` for a local-dev
install where the checksum file is absent.

### Windows

Not yet supported. Planned for a future release; for now, run the bridge
from a Linux container or a Mac.

## After installing

```sh
# 1. Open the webapp Settings -> Local Files panel and click
#    "Pair this machine". The webapp shows an 8-character code.

# 2. In your terminal, paste the code into the prompt:
carveai-bridge pair

# 3. Configure auto-start on every login (macOS launchd / Linux systemd):
carveai-bridge install-service

# 4. Pick which folders to share, in the webapp's Local Files panel.
#    Until you add at least one folder under allowlist mode, every
#    read/write is refused.
```

## Other commands

| Command | What it does |
|---|---|
| `carveai-bridge status` | Show current pairing + folder list |
| `carveai-bridge audit [N]` | Pretty-print the last N audited operations |
| `carveai-bridge run` | Run the daemon in the foreground (for debugging) |
| `carveai-bridge unpair` | Remove the local pairing token |
| `carveai-bridge uninstall-service` | Remove the launchd/systemd entry |
| `carveai-bridge version` | Print the daemon version |

## Verifying a download by hand

Every release ships a `SHA256SUMS` file alongside the binaries.

```sh
gh release download v0.1.1 --repo CarveAI/homebrew-tap --dir /tmp/cb
cd /tmp/cb && shasum -a 256 -c SHA256SUMS
```

The `install.sh` does this automatically.

## Reporting bugs

Open an issue on this repo. For agent-side or webapp-side issues, file
them on the private `CarveAI/carveai-core` repo (org members) or email
support.

## License

MIT (see [LICENSE](./LICENSE)).
