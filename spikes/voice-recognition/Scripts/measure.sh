#!/bin/bash
set -euo pipefail
if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo 'Usage: measure.sh /path/VoiceSpike analyzer|legacy /path/corpus.json [locale]' >&2
    exit 1
fi
echo 'Battery before (file recognition only, not continuous listening):' >&2
pmset -g batt >&2
/usr/bin/time -l python3 - "$1" "$2" "$3" "${4:-en-GB}" <<'PY'
import json
import subprocess
import sys

recognition_timeout_seconds = 60
with open(sys.argv[3], encoding="utf-8") as manifest:
    entries = json.load(manifest)
try:
    result = subprocess.run(
        [sys.argv[1], "compare", sys.argv[2], sys.argv[3], sys.argv[4]],
        timeout=max(1, len(entries)) * recognition_timeout_seconds,
        check=False,
    )
    sys.exit(result.returncode)
except subprocess.TimeoutExpired:
    print("VoiceSpike corpus deadline exceeded; recognition process terminated", file=sys.stderr)
    sys.exit(1)
PY
echo 'Battery after (service CPU and device energy need separate measurement):' >&2
pmset -g batt >&2
