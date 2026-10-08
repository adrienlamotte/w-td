# Runs the game.
. "$PSScriptRoot/_common.ps1"
& (Get-Godot) --path $GameDir
exit $LASTEXITCODE
