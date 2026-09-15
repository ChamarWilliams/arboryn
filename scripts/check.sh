#!/usr/bin/env bash
set -euo pipefail

rokit install
stylua --check src tests
selene src tests

mkdir -p build
rojo sourcemap plugin.project.json --output build/sourcemap.json
definitions="build/globalTypes.PluginSecurity.d.luau"
if [[ ! -f "$definitions" ]]; then
  curl --fail --location \
    --output "$definitions" \
    "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.PluginSecurity.d.luau"
fi
analysis="$(luau-lsp analyze \
  --platform roblox \
  --sourcemap build/sourcemap.json \
  --definitions "@roblox=$definitions" \
  src tests 2>&1)"
printf '%s\n' "$analysis"
if [[ "$analysis" == *"TypeError:"* || "$analysis" == *"SyntaxError:"* ]]; then
  echo "Luau type analysis failed." >&2
  exit 1
fi
rojo build plugin.project.json --output build/ArborynPhase0.rbxm

echo "Arboryn Phase 0 checks passed."
