# Runs the full headless test suite: GUT (sim) tests and Python tools tests.
. "$PSScriptRoot/_common.ps1"
$godot = Get-Godot
$py = Get-ToolsPython

# Import first so class_name scripts are registered on a fresh clone.
& $godot --headless --path $GameDir --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
& $godot --headless --path $GameDir -s res://addons/gut/gut_cmdln.gd
$gut = $LASTEXITCODE
& $py -m unittest discover -s (Join-Path $Root 'tools/tests')
$pyTests = $LASTEXITCODE

if ($gut -or $pyTests) { Write-Host "TESTS FAILED (gut=$gut, python=$pyTests)" -ForegroundColor Red; exit 1 }
Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
