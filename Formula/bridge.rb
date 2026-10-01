# Homebrew formula for carveai-bridge — the CarveAI desktop file-access daemon.
#
# Users install with one of:
#
#   brew install CarveAI/tap/bridge        # short form
#   brew tap CarveAI/tap && brew install bridge
#
# The bridge daemon is a self-contained Go static binary (~5 MB) compiled
# for darwin-arm64, darwin-amd64, linux-arm64, linux-amd64. Source lives
# in the private CarveAI/carveai-core repo under bridge/; binaries are
# mirrored to this tap repo's releases on every `bridge-vX.Y.Z` tag by
# carveai-core's release workflow.
#
# Updating this formula on a new release is automated by that workflow;
# manual edits aren't required for routine version bumps.

class Bridge < Formula
  desc "CarveAI desktop file-access daemon (read + write local files for hosted agents)"
  homepage "https://carveai.com"
  version "0.7.3"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-arm64"
      sha256 "47eaa4b3d82ebd2f56e1f99b7e6bcc90e6c3a4398f70ebb51ed45eab188a6b10"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-amd64"
      sha256 "677c377d10d5cd71e64e07b900d14559ce083127fd0718a062dafd4c681c6cb5"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-arm64"
      sha256 "1d76be356ca9d5e2fa739e30c62fa1699b9e5309de3f99565111b8b2f4f34fd2"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-amd64"
      sha256 "f1f3157d30074b181e49f47b4bce97065f7659b547dfe46c2ab4999ccca00ef6"
    end
  end

  def install
    bin.install Dir["*"].first => "carveai-bridge"
  end

  test do
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/carveai-bridge version"))
  end

  def caveats
    <<~EOS
      Next steps:
        1. Open the CarveAI webapp (Settings → Local Files) and click
           "Pair this machine"
        2. Run: carveai-bridge pair
           (paste the 8-character code when prompted)
        3. Run: carveai-bridge install-service
           (auto-starts on every login)
        4. Pick which folders to share in the webapp

      Logs live under ~/Library/Application\\ Support/carveai-bridge/.
    EOS
  end
end
