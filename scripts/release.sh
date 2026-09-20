#!/usr/bin/env bash
#   scripts/release.sh [--no-notarize]
#
# Builds universal, signs, notarizes, and leaves a tarball in dist/.
# Override SIRI_SAY_IDENTITY and SIRI_SAY_NOTARY_PROFILE to sign as someone else.
#
# A bare executable cannot be stapled the way an app or disk image can, so the
# ticket stays on Apple's servers and a downloaded copy needs one network round
# trip the first time it runs.
set -euo pipefail
cd "$(dirname "$0")/.."

identity=${SIRI_SAY_IDENTITY:-"Developer ID Application: Alongside Software, LLC (S3LYAUD99H)"}
profile=${SIRI_SAY_NOTARY_PROFILE:-alongside-notary}
notarize=1

for argument in "$@"; do
  case $argument in
    --no-notarize) notarize=0 ;;
    *) echo "unknown option: $argument" >&2; exit 1 ;;
  esac
done

version=$(sed -n 's/^let version = "\(.*\)"$/\1/p' Sources/SiriSay/main.swift)
if [ -z "$version" ]; then
  echo "could not read the version out of Sources/SiriSay/main.swift" >&2
  exit 1
fi

echo "==> building siri-say $version (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64
built=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/siri-say

rm -rf dist
mkdir -p dist bin
cp "$built" bin/siri-say

echo "==> signing"
codesign --force --options runtime --timestamp --sign "$identity" bin/siri-say
codesign --verify --strict bin/siri-say
lipo -info bin/siri-say

if [ "$notarize" -eq 1 ]; then
  echo "==> notarizing"
  ditto -c -k --sequesterRsrc bin/siri-say dist/notarize.zip
  xcrun notarytool submit dist/notarize.zip --keychain-profile "$profile" --wait
  rm dist/notarize.zip
fi

tarball="dist/siri-say-$version-universal.tar.gz"
tar -czf "$tarball" -C bin siri-say
checksum=$(shasum -a 256 "$tarball" | cut -d' ' -f1)

echo
echo "==> $tarball"
echo "    sha256 $checksum"
echo
echo "for the Homebrew formula:"
echo "  url \"https://github.com/Alongside-Software/siri-say/releases/download/v$version/siri-say-$version-universal.tar.gz\""
echo "  sha256 \"$checksum\""
