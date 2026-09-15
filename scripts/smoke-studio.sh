#!/usr/bin/env bash
set -euo pipefail

rokit install
mkdir -p build
rojo build smoke.project.json --output build/phase0-smoke.rbxl
run-in-roblox --place build/phase0-smoke.rbxl --script tests/phase0.smoke.luau
