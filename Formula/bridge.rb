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
  version "0.1.2"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-arm64"
      sha256 "ae3cc71b146f04f4ed03f5c2f8ee37563db162041f603c18e8f01d281d7e3b0f"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-amd64"
      sha256 "3e42bba74aea4bc1a9a408bfafa10b5b2eef407456c3881e5ebca596b8f3a3c1"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-arm64"
      sha256 "0d81afe72366c7d3e11e9d72e83d4fb01f0366f7fa09c20dbb76dc6fc79e9a92"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-amd64"
      sha256 "285e77804fb8a92f5a8d96884639c41065b686a439951b85dabedd7889cbb752"
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
