# Lives at Formula/siri-say.rb in Alongside-Software/homebrew-tap.
# scripts/release.sh prints the url and sha256 lines to paste in after a build.
class SiriSay < Formula
  desc "Drop-in replacement for say that speaks in the Siri voices"
  homepage "https://github.com/Alongside-Software/siri-say"
  url "https://github.com/Alongside-Software/siri-say/releases/download/v1.0.3/siri-say-1.0.3-universal.tar.gz"
  sha256 "feaa6b0bc2a186f9ba95e51bb20407b660f22dda7e8d12edbb49529026ea28dd"
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
