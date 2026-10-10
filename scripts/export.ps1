# Exports a Windows release build to build/windows/WTD.exe. Needs the export templates for the pinned version.
# -Archive M<n> also copies it to build/archive/M<n>/ with the commit it was built from (D-149, milestone prototypes).
param([string]$Archive)
. "$PSScriptRoot/_common.ps1"
$godot = Get-Godot
$templates = Join-Path $env:APPDATA "Godot/export_templates/$GodotVersion"
if (-not (Test-Path (Join-Path $templates 'windows_release_x86_64.exe'))) {
    throw "Export templates missing in $templates. Install them (see CLAUDE.md, Commands)."
}
$out = Join-Path $Root 'build/windows'
New-Item -ItemType Directory -Force $out | Out-Null
& $godot --headless --path $GameDir --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
& $godot --headless --path $GameDir --export-release 'Windows Desktop' (Join-Path $out 'WTD.exe')
if ($LASTEXITCODE -or -not (Test-Path (Join-Path $out 'WTD.exe'))) { throw 'Export failed' }
Write-Host "Built $out\WTD.exe" -ForegroundColor Green
if ($Archive) {
    $dst = Join-Path $Root "build/archive/$Archive"
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item (Join-Path $out 'WTD.exe') $dst -Force
    "$(git -C $Root rev-parse HEAD) $(Get-Date -Format yyyy-MM-dd)" | Out-File -Encoding utf8 (Join-Path $dst 'commit.txt')
    Write-Host "Archived to $dst" -ForegroundColor Green
}
