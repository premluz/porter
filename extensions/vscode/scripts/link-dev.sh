#!/usr/bin/env bash
# Links this probe into VS Code's extensions folder so it loads without packaging, and unlinks it.
# Usage: link-dev.sh link | unlink     (restart VS Code, or run "Developer: Reload Window", after either)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${PORTER_VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}/porter-dev.porter-vscode-probe-0.0.1"

case "${1:-}" in
  link)
    (cd "$root" && npm run --silent build)
    mkdir -p "$(dirname "$target")"
    [[ -e "$target" || -L "$target" ]] && { echo "link-dev: $target already exists; run unlink first" >&2; exit 1; }
    ln -s "$root" "$target"
    echo "Linked $target -> $root"
    ;;
  unlink)
    # Remove only a symlink this script made; never a real folder.
    if [[ -L "$target" ]]; then rm "$target"; echo "Removed $target"; else echo "Nothing to remove at $target"; fi
    ;;
  *) echo "usage: link-dev.sh link|unlink" >&2; exit 2 ;;
esac
