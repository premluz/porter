#!/usr/bin/env bash
# Checks that Chrome installs the extension packed inside Porter.app, using a throwaway headless profile.
# Usage: check-extension-install.sh [path/to/Porter.app]     (default: apps/macos/.build/app/Porter.app)
# It writes the same External Extensions file the app writes, starts Chrome for a few seconds with its own user-data
# folder, and reads the result from that profile's secure preferences. Your real profiles are not touched.
# Overrides: CHROME_BIN.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
app="${1:-$root/apps/macos/.build/app/Porter.app}"
crx="$app/Contents/Resources/porter-extension.crx"
manifest="$app/Contents/Resources/ChromeExtension/manifest.json"
[[ -f "$crx" && -f "$manifest" ]] || { echo "check-extension-install: $app has no packed extension" >&2; exit 1; }

chrome_bin="${CHROME_BIN:-}"
if [[ -z "$chrome_bin" ]]; then
  for candidate in /Applications/Google\ Chrome*.app/Contents/MacOS/Google\ Chrome; do
    [[ -x "$candidate" ]] && { chrome_bin="$candidate"; break; }
  done
fi
[[ -x "$chrome_bin" ]] || { echo "check-extension-install: no Chrome found; set CHROME_BIN" >&2; exit 1; }

profile="$(mktemp -d)"
trap 'pkill -f "user-data-dir=$profile" 2>/dev/null || true; rm -rf "$profile"' EXIT
id="$(python3 -I - "$manifest" <<'PY'
import base64, hashlib, json, sys
key = json.load(open(sys.argv[1]))["key"]
digest = hashlib.sha256(base64.b64decode(key)).digest()[:16]
print("".join(chr(ord("a") + nibble) for byte in digest for nibble in (byte >> 4, byte & 15)))
PY
)"
version="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"
mkdir -p "$profile/External Extensions"
printf '{"external_crx":"%s","external_version":"%s"}\n' "$crx" "$version" > "$profile/External Extensions/$id.json"

"$chrome_bin" --headless=new --no-sandbox --user-data-dir="$profile" about:blank >/dev/null 2>&1 &
for _ in $(seq 1 30); do
  sleep 1
  grep -qs "$id" "$profile/Default/Secure Preferences" && break
done
sleep 2
python3 -I - "$profile/Default/Secure Preferences" "$id" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1])).get("extensions", {}).get("settings", {}).get(sys.argv[2])
if settings is None:
    sys.exit("check-extension-install: Chrome did not install the extension")
reasons = settings.get("disable_reasons")
print(f"installed id={sys.argv[2]} name={settings.get('manifest', {}).get('name')} location={settings.get('location')} disable_reasons={reasons}")
if settings.get("location") != 2:
    sys.exit("check-extension-install: not installed as an external extension")
PY
