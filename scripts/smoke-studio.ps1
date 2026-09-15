$ErrorActionPreference = 'Stop'

rokit install
New-Item -ItemType Directory -Force -Path build | Out-Null
rojo build smoke.project.json --output build/phase0-smoke.rbxl
run-in-roblox --place build/phase0-smoke.rbxl --script tests/phase0.smoke.luau
