#!/bin/bash
set -euo pipefail
spike_root="$(cd "$(dirname "$0")/.." && pwd)"
output_root="${1:-$spike_root/.build/permission-probes}"
swift build --package-path "$spike_root" -c release
binary_root="$(swift build --package-path "$spike_root" -c release --show-bin-path)"
mkdir -p "$output_root"
bundle_parent="$(mktemp -d "$output_root/probe.XXXXXX")"
bundle="$bundle_parent/VoiceSpike.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$binary_root/VoiceSpike" "$bundle/Contents/MacOS/VoiceSpike"
cp "$spike_root/Resources/Info.plist" "$bundle/Contents/Info.plist"
plutil -lint "$bundle/Contents/Info.plist"
codesign --sign - "$bundle"
codesign --verify --strict "$bundle"
printf '%s\n' "$bundle"
