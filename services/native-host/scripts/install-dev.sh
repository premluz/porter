#!/usr/bin/env bash
# Development install of the Porter native messaging host for Google Chrome.
# Creates exactly two files, both removed by uninstall-dev.sh:
#   $CHROME_DIR/NativeMessagingHosts/com.porter.bridge.json   (Chrome's host manifest)
#   $PORTER_SUPPORT_DIR/allowed-origins.txt                   (origin the relay will accept)
# Overrides, mainly for testing: PORTER_CHROME_DIR, PORTER_SUPPORT_DIR.
set -euo pipefail

HOST_NAME="com.porter.bridge"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
chrome_dir="${PORTER_CHROME_DIR:-$HOME/Library/Application Support/Google/Chrome}"
support_dir="${PORTER_SUPPORT_DIR:-$HOME/Library/Application Support/Porter}"
host_binary="$root/services/native-host/.build/release/porter-native-host"

case "$host_binary" in
  *\"*|*\\*) echo "install-dev: repository path contains a quote or backslash" >&2; exit 1 ;;
esac

extension_id="$(cd "$root/extensions/chrome" && npm run --silent extension-id)"
[[ "$extension_id" =~ ^[a-p]{32}$ ]] || { echo "install-dev: unexpected extension id '$extension_id'" >&2; exit 1; }

echo "Building native host, registry and control tool..."
swift build -c release --package-path "$root/services/native-host" >/dev/null
echo "Building extension..."
(cd "$root/extensions/chrome" && npm run --silent build)
[[ -x "$host_binary" ]] || { echo "install-dev: $host_binary was not built" >&2; exit 1; }

mkdir -p "$support_dir" "$chrome_dir/NativeMessagingHosts"
chmod 700 "$support_dir"
printf 'chrome-extension://%s/\n' "$extension_id" > "$support_dir/allowed-origins.txt"
cat > "$chrome_dir/NativeMessagingHosts/$HOST_NAME.json" <<JSON
{
  "name": "$HOST_NAME",
  "description": "Porter bridge between the Chrome connector and the Porter registry",
  "path": "$host_binary",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$extension_id/"]
}
JSON

cat <<MESSAGE

Installed.
  Extension ID : $extension_id
  Host manifest: $chrome_dir/NativeMessagingHosts/$HOST_NAME.json
  Origin list  : $support_dir/allowed-origins.txt

Next, in EACH Chrome profile you want to track:
  1. Open chrome://extensions, turn on Developer mode, choose "Load unpacked",
     and select: $root/extensions/chrome
  2. Confirm the extension ID shown is $extension_id
  3. Open the extension's Options, name the profile (for example Personal or Work)
     and click "Allow access to claude.ai".
Then start the registry:  $root/services/native-host/.build/release/porter-registryd
and inspect it with:      $root/services/native-host/.build/release/porterctl list
MESSAGE
