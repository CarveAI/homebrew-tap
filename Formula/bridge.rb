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
  version "0.7.2"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-arm64"
      sha256 "0deb70a61ac03164aa719b103e7bcaa3ff81424b0dea251790670591a92eadfe"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-amd64"
      sha256 "4725d20a7dd0d9acef4026b34c156247cbbd899492109a55a284bc28f77b8e49"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-arm64"
      sha256 "906847efd7e28289e8d83b6dd681bbb5977e4263c68c6f34bdc958e7e9f7aa3d"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-amd64"
      sha256 "af84338cfbb90b80b47f91d8a892408656a95d6885ab9379b19e840f86cf48dc"
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
