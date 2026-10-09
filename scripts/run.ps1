# Runs the game.
. "$PSScriptRoot/_common.ps1"
$godot = Get-Godot
# Import first so a fresh clone has the translations (D-121).
& $godot --headless --path $GameDir --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
& $godot --path $GameDir
exit $LASTEXITCODE
