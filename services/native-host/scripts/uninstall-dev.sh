#!/usr/bin/env bash
# Removes only the files install-dev.sh created. Browser profiles, extension storage and
# Chrome's other native messaging hosts are never touched.
set -euo pipefail

HOST_NAME="com.porter.bridge"
chrome_dir="${PORTER_CHROME_DIR:-$HOME/Library/Application Support/Google/Chrome}"
support_dir="${PORTER_SUPPORT_DIR:-$HOME/Library/Application Support/Porter}"

rm -f "$chrome_dir/NativeMessagingHosts/$HOST_NAME.json" "$support_dir/allowed-origins.txt"
# rmdir only succeeds on an empty directory, so a running registry's sockets are left alone.
rmdir "$support_dir" 2>/dev/null || true
echo "Removed the Porter host manifest and origin list. Remove the extension in chrome://extensions."
