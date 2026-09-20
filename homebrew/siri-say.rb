# Lives at Formula/siri-say.rb in Alongside-Software/homebrew-tap.
# scripts/release.sh prints the url and sha256 lines to paste in after a build.
class SiriSay < Formula
  desc "Drop-in replacement for say that speaks in the Siri voices"
  homepage "https://github.com/Alongside-Software/siri-say"
  url "https://github.com/Alongside-Software/siri-say/releases/download/v1.0.2/siri-say-1.0.2-universal.tar.gz"
  sha256 "5b6451c36de538fc220b25048147cc17fbe87b13efa9fff9f888eedc0d18098e"
  license "MIT"

  depends_on :macos

  def install
    bin.install "siri-say"
  end

  def caveats
    <<~TEXT
      To have `say` itself speak in a Siri voice:

        siri-say install

      That links `say` next to siri-say in #{bin}. Homebrew does not track that
      link, so run `siri-say uninstall` before `brew uninstall siri-say`.
    TEXT
  end

  test do
    assert_match "siri-say", shell_output("#{bin}/siri-say version")
  end
end
