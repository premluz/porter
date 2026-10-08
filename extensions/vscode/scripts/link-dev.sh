#!/usr/bin/env bash
# Links this extension into VS Code's extensions folder so it loads without packaging, and unlinks it.
# Usage: link-dev.sh link | unlink     (run "Developer: Reload Window" in VS Code after either)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extensions="${PORTER_VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"
target="$extensions/porter-dev.porter-vscode-0.1.0"
previous="$extensions/porter-dev.porter-vscode-probe-0.0.1"

# Remove only a symlink this project made; never a real folder.
remove_link() {
  if [[ -L "$1" ]]; then rm "$1"; echo "Removed $1"; fi
}

case "${1:-}" in
  link)
    (cd "$root" && npm run --silent build)
    mkdir -p "$extensions"
    remove_link "$previous"
    [[ -e "$target" || -L "$target" ]] && { echo "link-dev: $target already exists; run unlink first" >&2; exit 1; }
    ln -s "$root" "$target"
    echo "Linked $target -> $root"
    ;;
  unlink)
    remove_link "$target"
    remove_link "$previous"
    echo "Done."
    ;;
  *) echo "usage: link-dev.sh link|unlink" >&2; exit 2 ;;
esac
