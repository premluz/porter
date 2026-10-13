#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(mktemp -d /tmp/porter-voice-verify.XXXXXX)"
export CLANG_MODULE_CACHE_PATH="$output/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"

run_check() {
  local label="$1"
  shift
  if "$@" >"$output/$label.log" 2>&1; then
    echo "$label: passed"
    tail -n 4 "$output/$label.log"
  else
    echo "$label: failed; log $output/$label.log" >&2
    tail -n 15 "$output/$label.log" >&2
    return 1
  fi
}

cd "$root"
run_check contracts npm --prefix "$root/packages/contracts" run validate
run_check core swift test --package-path "$root/packages/ConversationCore" --disable-sandbox
run_check native-host swift test --package-path "$root/services/native-host" --disable-sandbox
run_check mac swift test --package-path "$root/apps/macos" --disable-sandbox
run_check recognition-spike swift test --package-path "$root/spikes/voice-recognition" --disable-sandbox
run_check release swift build --package-path "$root/apps/macos" --disable-sandbox -c release
binary_directory="$(swift build --package-path "$root/apps/macos" --disable-sandbox -c release --show-bin-path)"
run_check self-test "$binary_directory/Porter" --self-test
run_check memory python3 tools/project_memory.py check
echo "Verification logs: $output"
