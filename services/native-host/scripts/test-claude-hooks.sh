#!/usr/bin/env bash
# Exercises claude-hooks.sh against a temporary settings file; never touches the real one.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export CLAUDE_SETTINGS="$tmp/settings.json"
export PORTERCTL="${PORTERCTL:-$here/../.build/release/porterctl}"
fail() { echo "FAIL: $1" >&2; exit 1; }
check() { python3 -I -c "import json,sys; d=json.load(open('$CLAUDE_SETTINGS')); $1" || fail "$2"; }

cat > "$CLAUDE_SETTINGS" <<'JSON'
{ "model": "opus", "permissions": { "allow": ["Read"] },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "/usr/local/bin/mine-stop" } ] } ],
             "PreCompact": [ { "hooks": [ { "type": "command", "command": "/usr/local/bin/mine-compact" } ] } ] } }
JSON
cp "$CLAUDE_SETTINGS" "$tmp/original.json"

"$here/claude-hooks.sh" >/dev/null
cmp -s "$CLAUDE_SETTINGS" "$tmp/original.json" || fail "dry run changed the file"
"$here/claude-hooks.sh" --apply >/dev/null
ls "$tmp" | grep -q porter-backup || fail "no backup was made"
check "assert d['model']=='opus' and d['permissions']=={'allow':['Read']}" "other settings were not kept"
check "assert any('mine-stop' in h['command'] for g in d['hooks']['Stop'] for h in g['hooks'])" "the user's own Stop hook was lost"
check "assert 'PreCompact' in d['hooks']" "an event Porter does not use was lost"
check "assert all(any('porterctl hook' in h['command'] and h['async'] is True for g in d['hooks'][e] for h in g['hooks']) for e in ['SessionStart','UserPromptSubmit','PreToolUse','PostToolUse','Notification','Stop','SessionEnd'])" "a Porter hook is missing or not async"
cp "$CLAUDE_SETTINGS" "$tmp/applied.json"
"$here/claude-hooks.sh" --apply | grep -q "already in place" || fail "applying twice was not idempotent"
cmp -s "$CLAUDE_SETTINGS" "$tmp/applied.json" || fail "applying twice changed the file"
"$here/claude-hooks.sh" --remove >/dev/null
check "assert d['model']=='opus' and 'PreCompact' in d['hooks'] and len(d['hooks']['Stop'])==1 and 'mine-stop' in d['hooks']['Stop'][0]['hooks'][0]['command'] and 'SessionStart' not in d['hooks']" "removal did not restore the user's settings"
echo '{ not json' > "$CLAUDE_SETTINGS"; cp "$CLAUDE_SETTINGS" "$tmp/broken.json"
if "$here/claude-hooks.sh" --apply 2>/dev/null; then fail "an invalid settings file was accepted"; fi
cmp -s "$CLAUDE_SETTINGS" "$tmp/broken.json" || fail "an invalid settings file was modified"
rm "$CLAUDE_SETTINGS"
"$here/claude-hooks.sh" --apply >/dev/null
check "assert 'Stop' in d['hooks']" "a missing settings file was not created"
echo "claude-hooks.sh: all checks passed"
