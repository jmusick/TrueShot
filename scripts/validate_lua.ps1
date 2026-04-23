$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$luarocksBin = Join-Path $env:APPDATA "luarocks\bin"
if (Test-Path $luarocksBin) {
    $env:PATH = "$luarocksBin;$env:PATH"
}

$luaFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter *.lua |
    ForEach-Object { $_.FullName }

Write-Host "Syntax check (luac)..." -ForegroundColor Cyan
foreach ($file in $luaFiles) {
    & luac -p $file
}

if (Get-Command luacheck -ErrorAction SilentlyContinue) {
    Write-Host "Static analysis (luacheck)..." -ForegroundColor Cyan
    & luacheck $luaFiles
} else {
    Write-Warning "luacheck not found in PATH; skipping static analysis"
}

Write-Host "Logic tests..." -ForegroundColor Cyan
& lua tests/test_hunter_profiles.lua
& lua tests/test_cd_ledger.lua
& lua tests/test_condition_registry.lua
& lua tests/test_engine_hero_talent.lua
& lua tests/test_base64_decode.lua

Write-Host "Lua validation complete." -ForegroundColor Green
