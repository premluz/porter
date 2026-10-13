#!/usr/bin/env bash
# Copies the live mascot's spec and parity scenarios from Rios Brand into Porter, or with --check fails when Porter's
# copies differ from Rios Brand's. Rios Brand is the source of truth (PLAN-005); Porter never edits these files.
# Usage: tools/sync_mascot_spec.sh [--check]   (RIOS_BRAND overrides the source folder, default ~/Rios Brand)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rios="${RIOS_BRAND:-$HOME/Rios Brand}"
pairs=(
  "spec/mascot-spec.v1.json:apps/macos/Sources/PorterMascot/Resources/mascot-spec.v1.json"
  "spec/mascot-parity.v1.json:apps/macos/Tests/PorterMascotTests/Fixtures/mascot-parity.v1.json"
)
status=0
for pair in "${pairs[@]}"; do
  source="$rios/${pair%%:*}"
  target="$root/${pair#*:}"
  [[ -f "$source" ]] || { echo "Missing in Rios Brand: $source" >&2; exit 1; }
  if [[ "${1:-}" == "--check" ]]; then
    if cmp -s "$source" "$target"; then echo "same: ${pair#*:}"; else echo "differs: ${pair#*:} (run tools/sync_mascot_spec.sh)" >&2; status=1; fi
  else
    cp "$source" "$target"
    echo "copied: ${pair#*:}"
  fi
done
exit "$status"
