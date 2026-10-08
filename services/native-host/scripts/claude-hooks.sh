#!/usr/bin/env bash
# Registers (or removes) Porter's status hook in a Claude Code settings file.
#   claude-hooks.sh            show what would change, change nothing
#   claude-hooks.sh --apply    back the file up, then add Porter's hooks
#   claude-hooks.sh --remove   back the file up, then remove only Porter's hooks
# Overrides: CLAUDE_SETTINGS (default ~/.claude/settings.json), PORTERCTL (default the release build).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
porterctl="${PORTERCTL:-$root/services/native-host/.build/release/porterctl}"
mode="${1:-}"
case "$mode" in ""|--apply|--remove) ;; *) echo "usage: claude-hooks.sh [--apply|--remove]" >&2; exit 2 ;; esac
[[ -x "$porterctl" ]] || { echo "claude-hooks: $porterctl is not built; run: swift build -c release --package-path $root/services/native-host" >&2; exit 1; }

PORTER_MODE="$mode" PORTER_SETTINGS="$settings" PORTER_CTL="$porterctl" python3 -I - <<'PY'
import json, os, shutil, sys, tempfile, time

mode, path, ctl = os.environ["PORTER_MODE"], os.environ["PORTER_SETTINGS"], os.environ["PORTER_CTL"]
MARKER = "porterctl hook"      # how Porter's own entries are recognised, and nothing else is touched

try:
    original = json.load(open(path)) if os.path.exists(path) else {}
except json.JSONDecodeError as error:
    sys.exit(f"claude-hooks: {path} is not valid JSON ({error}); nothing was changed")
if not isinstance(original, dict):
    sys.exit(f"claude-hooks: {path} is not a JSON object; nothing was changed")

config = json.loads(os.popen(f'"{ctl}" hook-config').read())["hooks"]
result = json.loads(json.dumps(original))
hooks = result.setdefault("hooks", {})
if not isinstance(hooks, dict):
    sys.exit(f"claude-hooks: 'hooks' in {path} is not an object; nothing was changed")

def is_porter(group):
    return any(MARKER in str(hook.get("command", "")) for hook in group.get("hooks", []) if isinstance(hook, dict))

for event, groups in config.items():
    kept = [g for g in hooks.get(event, []) if isinstance(g, dict) and not is_porter(g)]
    hooks[event] = kept if mode == "--remove" else kept + groups
    if not hooks[event]:
        del hooks[event]
if not hooks:
    del result["hooks"]

if result == original:
    print("No Porter hooks to remove; nothing changed." if mode == "--remove" else "Porter's hooks are already in place; nothing to change.")
    sys.exit(0)
added = sorted(set(result.get("hooks", {})) - set(original.get("hooks", {})))
print(f"{'Would change' if not mode else 'Changing'} {path}")
print(f"  events with a Porter hook after this: {', '.join(sorted(e for e, g in result.get('hooks', {}).items() if any(is_porter(x) for x in g))) or 'none'}")
print(f"  other settings and other hooks: kept as they are (new events: {', '.join(added) or 'none'})")
if not mode:
    print("Run again with --apply to write it, or --remove to take Porter's hooks out.")
    sys.exit(0)
if os.path.exists(path):
    backup = f"{path}.porter-backup-{time.strftime('%Y%m%d-%H%M%S')}"
    shutil.copy2(path, backup)
    print(f"  backup: {backup}")
directory = os.path.dirname(path) or "."
os.makedirs(directory, exist_ok=True)
handle, temporary = tempfile.mkstemp(dir=directory, prefix=".settings-porter-")
with os.fdopen(handle, "w") as out:
    json.dump(result, out, indent=2)
    out.write("\n")
os.replace(temporary, path)
print("Done. Claude Code reads hook settings when a session starts; restart open sessions to apply.")
PY
