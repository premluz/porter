#!/usr/bin/env bash
# Builds Porter.dmg: the app bundle and an Applications shortcut, for drag-to-install.
# Usage: build-dmg.sh [output-directory]            (default: apps/macos/.build/app)
# Overrides: SIGN_IDENTITY (passed to build-app.sh and used to sign the image), NOTARY_PROFILE (a notarytool keychain
#            profile; when set and the identity is a Developer ID, the image is submitted for notarization and stapled).
# Notarization needs a paid Apple Developer account and has not been run.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
out="${1:-$root/apps/macos/.build/app}"
identity="${SIGN_IDENTITY:--}"
dmg="$out/Porter.dmg"

"$root/apps/macos/scripts/build-app.sh" "$out" >/dev/null
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -R "$out/Porter.app" "$stage/Porter.app"
ln -s /Applications "$stage/Applications"

rm -f "$dmg"
hdiutil create -quiet -volname "Porter" -srcfolder "$stage" -format UDZO -fs HFS+ "$dmg"
if [[ "$identity" != "-" ]]; then
  codesign --force --sign "$identity" --timestamp "$dmg"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
  fi
fi

hdiutil verify -quiet "$dmg"
mount="$(mktemp -d)"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount" "$dmg"
trap 'hdiutil detach -quiet "$mount" >/dev/null 2>&1 || true; rm -rf "$stage" "$mount"' EXIT
[[ -d "$mount/Porter.app" && -L "$mount/Applications" ]] || { echo "build-dmg: the image is missing Porter.app or the Applications shortcut" >&2; exit 1; }
codesign --verify --deep --strict "$mount/Porter.app"
echo "Built $dmg"
