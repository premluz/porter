#!/usr/bin/env bash
# Builds the companion and packs it as a .vsix without a packaging tool (a .vsix is a zip with two manifests).
# Usage: package-vsix.sh <output.vsix> [--verify]
#   --verify  installs it into throwaway folders with the `code` command and checks it is listed, then removes it.
# Overrides: CODE_CLI (default: VS Code's bundled command).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:?usage: package-vsix.sh <output.vsix> [--verify]}"
verify="${2:-}"
case "$output" in /*) ;; *) output="$PWD/$output" ;; esac

(cd "$root" && npm run --silent build)
name="$(node -p "require('$root/package.json').name")"
version="$(node -p "require('$root/package.json').version")"
publisher="$(node -p "require('$root/package.json').publisher")"
display="$(node -p "require('$root/package.json').displayName")"
engine="$(node -p "require('$root/package.json').engines.vscode")"
description="$(node -p "require('$root/package.json').description")"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/extension"
cp "$root/package.json" "$stage/extension/"
cp -R "$root/dist" "$stage/extension/dist"

cat > "$stage/[Content_Types].xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/Content-Types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".vsixmanifest" ContentType="text/xml"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".map" ContentType="application/json"/></Types>
XML
cat > "$stage/extension.vsixmanifest" <<XML
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="$name" Version="$version" Publisher="$publisher"/>
    <DisplayName>$display</DisplayName>
    <Description xml:space="preserve">$description</Description>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="$engine"/></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
XML

rm -f "$output"
(cd "$stage" && zip -q -r "$output" '[Content_Types].xml' extension.vsixmanifest extension)
echo "Wrote $output"

[[ "$verify" == "--verify" ]] || exit 0
code="${CODE_CLI:-/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code}"
[[ -x "$code" ]] || { echo "package-vsix: $code not found; set CODE_CLI" >&2; exit 1; }
scratch="$(mktemp -d)"
trap 'rm -rf "$stage" "$scratch"' EXIT
"$code" --install-extension "$output" --extensions-dir "$scratch/ext" --user-data-dir "$scratch/user" >/dev/null 2>&1
listed="$("$code" --list-extensions --show-versions --extensions-dir "$scratch/ext" --user-data-dir "$scratch/user" 2>/dev/null)"
[[ "$listed" == "$publisher.$name@$version" ]] || { echo "package-vsix: install check failed; listed: $listed" >&2; exit 1; }
echo "Verified: installs and lists as $listed"
