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
  version "0.5.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-arm64"
      sha256 "33cbff15015cf459b168d38a359bdb59865ea22e39421b0a1cbce42beabd870a"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-amd64"
      sha256 "4213ff09ed76a658bbe86a765ca68781d85589731500bbbb33db62091c40c200"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-arm64"
      sha256 "98bc6be2023665cefe909906022a704013e70332c59807c1103ae4e466f0185c"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-amd64"
      sha256 "f20d1dff547caf8fe3cf041e33b7ec90d46401e10f5016383b615cf951cbfc4a"
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
