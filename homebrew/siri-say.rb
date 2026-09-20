# Homebrew only infers tap URLs for GitHub, so this one is added by URL once:
#
#   brew tap alongside-oss/tap https://gitlab.com/alongside-oss/homebrew-tap.git
#
# scripts/release.sh prints the url and sha256 lines to paste in after a build.
class SiriSay < Formula
  desc "say, in a Siri voice"
  homepage "https://gitlab.com/alongside-oss/siri-say"
  url "https://gitlab.com/alongside-oss/siri-say/-/releases/v1.0.0/downloads/siri-say-1.0.0-universal.tar.gz"
  sha256 "5f50056327c1144214c20b00bc2786bf6900b88e914e2319910006a4a548b7ea"
  version "1.0.0"

  license "MIT"

  depends_on :macos

  def install
    bin.install "siri-say"
  end

  def caveats
    <<~TEXT
      To have `say` itself speak in a Siri voice:

        siri-say install

      That links `say` next to siri-say in #{bin}. Homebrew does not know about
      that link, so run `siri-say uninstall` before `brew uninstall siri-say`.
    TEXT
  end

  test do
    assert_match "siri-say", shell_output("#{bin}/siri-say version")
  end
end
