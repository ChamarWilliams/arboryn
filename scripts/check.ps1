$ErrorActionPreference = 'Stop'

if ($env:CI -eq 'true') {
    rokit install --no-trust-check
} else {
    rokit install
}
stylua --check src tests
selene src tests

New-Item -ItemType Directory -Force -Path build | Out-Null
rojo sourcemap plugin.project.json --output build/sourcemap.json
$definitions = 'build/globalTypes.PluginSecurity.d.luau'
if (-not (Test-Path -LiteralPath $definitions)) {
    Invoke-WebRequest `
        -Uri 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.PluginSecurity.d.luau' `
        -OutFile $definitions
}
$analysis = & luau-lsp analyze `
    --platform roblox `
    --sourcemap build/sourcemap.json `
    --definitions "@roblox=$definitions" `
    src tests 2>&1
$analysis | Write-Host
if ($LASTEXITCODE -ne 0 -or $analysis -match '(Type|Syntax)Error:') {
    throw 'Luau type analysis failed.'
}
rojo build plugin.project.json --output build/ArborynPhase0.rbxm

Write-Host 'Arboryn Phase 0 checks passed.'
