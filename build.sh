#!/bin/sh
# Builds siri-say and drops the binary in bin/.
set -e
cd "$(dirname "$0")"
swift build -c release
mkdir -p bin
cp .build/release/siri-say bin/siri-say
echo "built bin/siri-say"
