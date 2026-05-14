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
  version "0.1.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-arm64"
      sha256 "fdf5ae843ee37c34e0bc8c0f74d4b0226636eeaf462eb23b3bf039a8a63fc02f"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-darwin-amd64"
      sha256 "f1ff0ccb2079c0336304d102f23d672ea91b70167b7e1f9fac6b5680965fcb8a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-arm64"
      sha256 "4a02f39779759c8f8b638a55c7c9d457fcde0cdf5a8cacaed6dd735b8baa0b9b"
    end
    on_intel do
      url "https://github.com/CarveAI/homebrew-tap/releases/download/v#{version}/carveai-bridge-linux-amd64"
      sha256 "091a1b1a6c431e8e17344b18cb77e265b4cc8d056d92360942f98f47612b1d80"
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
