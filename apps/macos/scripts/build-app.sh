#!/usr/bin/env bash
# Builds Porter.app: the menu-bar app, its helpers, the VS Code companion and the Chrome extension, in one bundle.
# Usage: build-app.sh [output-directory]            (default: apps/macos/.build/app)
# Overrides: SIGN_IDENTITY (default "-", an ad-hoc signature that is fine on this Mac but not for distribution;
#            a "Developer ID Application: ..." identity also turns on the hardened runtime for notarization),
#            BUNDLE_ID (default com.porter.Porter; changing it makes macOS ask for every permission again),
#            VERSION (default from the Mac package, 0.1.0),
#            PORTER_SIGNING_DIR (default ~/.porter-signing; holds the Chrome extension's private key, created on the first
#            build; it decides the extension's id, so back it up and never commit it),
#            CHROME_BIN (the Chrome executable used to pack the extension; default: the first Google Chrome*.app found).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
out="${1:-$root/apps/macos/.build/app}"
identity="${SIGN_IDENTITY:--}"
bundle_id="${BUNDLE_ID:-com.porter.Porter}"
version="${VERSION:-0.1.0}"
build_number="$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 1)"
app="$out/Porter.app"

echo "Building the app and its helpers..."
swift build -c release --package-path "$root/apps/macos" >/dev/null
swift build -c release --package-path "$root/services/native-host" >/dev/null
app_bin="$(swift build -c release --package-path "$root/apps/macos" --show-bin-path)"
host_bin="$(swift build -c release --package-path "$root/services/native-host" --show-bin-path)"

echo "Packing the VS Code companion and the Chrome extension..."
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
"$root/extensions/vscode/scripts/package-vsix.sh" "$staging/porter-vscode.vsix" >/dev/null
(cd "$root/extensions/chrome" && npm run --silent build)

signing_dir="${PORTER_SIGNING_DIR:-$HOME/.porter-signing}"
extension_key="$signing_dir/chrome-extension.pem"
if [[ ! -f "$extension_key" ]]; then
  mkdir -p "$signing_dir" && chmod 700 "$signing_dir"
  openssl genrsa -out "$extension_key" 2048 2>/dev/null
  chmod 600 "$extension_key"
  echo "Created the extension signing key $extension_key. Back it up: it decides the extension's id." >&2
fi
public_key="$(openssl rsa -in "$extension_key" -pubout -outform DER 2>/dev/null | base64 | tr -d '\n')"
extension_stage="$staging/extension"
mkdir -p "$extension_stage"
cp "$root/extensions/chrome/options.html" "$root/extensions/chrome/options.css" "$extension_stage/"
cp -R "$root/extensions/chrome/dist" "$extension_stage/dist"
PUBLIC_KEY="$public_key" python3 -I - "$root/extensions/chrome/manifest.json" "$extension_stage/manifest.json" <<'PY'
import json, os, sys
manifest = json.load(open(sys.argv[1]))
manifest["key"] = os.environ["PUBLIC_KEY"]
json.dump(manifest, open(sys.argv[2], "w"), indent=2)
PY
chrome_bin="${CHROME_BIN:-}"
if [[ -z "$chrome_bin" ]]; then
  for candidate in /Applications/Google\ Chrome*.app/Contents/MacOS/Google\ Chrome; do
    [[ -x "$candidate" ]] && { chrome_bin="$candidate"; break; }
  done
fi
crx=""
if [[ -n "$chrome_bin" && -x "$chrome_bin" ]]; then
  "$chrome_bin" --headless=new --no-sandbox --user-data-dir="$staging/packprofile" \
    --pack-extension="$extension_stage" --pack-extension-key="$extension_key" >/dev/null 2>&1 || true
  [[ -f "$staging/extension.crx" ]] && crx="$staging/extension.crx"
fi
[[ -n "$crx" ]] || echo "build-app: no Chrome found to pack the extension; the app will carry the unpacked folder only (set CHROME_BIN)" >&2

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources/ChromeExtension"
cp "$app_bin/Porter" "$app/Contents/MacOS/Porter"
cp "$host_bin/porterctl" "$host_bin/porter-native-host" "$app/Contents/Helpers/"
cp "$staging/porter-vscode.vsix" "$app/Contents/Resources/"
cp "$root/services/native-host/scripts/claude-hooks.sh" "$app/Contents/Resources/"
cp -R "$extension_stage/." "$app/Contents/Resources/ChromeExtension/"
[[ -z "$crx" ]] || cp "$crx" "$app/Contents/Resources/porter-extension.crx"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$bundle_id</string>
    <key>CFBundleName</key><string>Porter</string>
    <key>CFBundleDisplayName</key><string>Porter</string>
    <key>CFBundleExecutable</key><string>Porter</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$build_number</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Porter asks Chrome and Safari which of your Claude and ChatGPT tabs are open, and brings the one you choose forward. It reads no page content.</string>
</dict>
</plist>
PLIST
plutil -lint "$app/Contents/Info.plist" >/dev/null

echo "Signing with identity: $identity"
options=()
[[ "$identity" != "-" ]] && options=(--options runtime --timestamp)
for helper in "$app/Contents/Helpers/"*; do
  codesign --force --sign "$identity" ${options[@]+"${options[@]}"} "$helper"
done
codesign --force --sign "$identity" ${options[@]+"${options[@]}"} --entitlements "$root/apps/macos/Porter.entitlements" "$app"
codesign --verify --deep --strict "$app"
echo "Built $app"
